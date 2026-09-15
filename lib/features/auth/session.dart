import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api.dart';
import '../../core/models.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

class TokenStore {
  TokenStore({
    required this.readToken,
    required this.writeToken,
    required this.deleteToken,
  });
  final Future<String?> Function() readToken;
  final Future<void> Function(String) writeToken;
  final Future<void> Function() deleteToken;
  Future<void> _tail = Future.value();
  Future<void> serialize(Future<void> Function() operation) {
    final task = _tail.then((_) => operation());
    _tail = task.catchError((Object _) {});
    return task;
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return TokenStore(
    readToken: () => storage.read(key: 'access_token'),
    writeToken: (token) => storage.write(key: 'access_token', value: token),
    deleteToken: () => storage.delete(key: 'access_token'),
  );
});

class Session extends AsyncNotifier<AppUser?> {
  int _generation = 0;
  @override
  Future<AppUser?> build() async {
    final generation = ++_generation;
    final api = ref.read(apiProvider);
    api.onUnauthorized = expire;
    final token = await ref.read(tokenStoreProvider).readToken();
    if (!ref.mounted || generation != _generation) return null;
    if (token == null) return null;
    api.token = token;
    try {
      final response = await api.get('/me');
      if (!ref.mounted || generation != _generation) return null;
      return AppUser.fromJson(object(response['user']));
    } on ApiFailure catch (e) {
      if (e.status == 401) return null;
      rethrow; // A transient network error must not erase a valid stored token.
    }
  }

  Future<void> authenticate(String endpoint, Json payload) async {
    final generation = ++_generation;
    final store = ref.read(tokenStoreProvider);
    final response =
        await ref.read(apiProvider).post('/auth/$endpoint', payload);
    if (!ref.mounted || generation != _generation) return;
    final token = string(response['token']);
    if (token.isEmpty) throw const ApiFailure('Oturum yanıtı geçersiz.');
    await store.serialize(() async {
      if (ref.mounted && generation == _generation) {
        await store.writeToken(token);
      }
    });
    if (!ref.mounted || generation != _generation) return;
    ref.read(apiProvider).token = token;
    state = AsyncData(AppUser.fromJson(object(response['user'])));
    ref.read(dataRevisionProvider.notifier).refresh();
  }

  Future<void> logout() async {
    final generation = _generation;
    try {
      await ref.read(apiProvider).post('/auth/logout', {});
    } finally {
      if (ref.mounted && generation == _generation) {
        await clear();
      }
    }
  }

  void expire() {
    if (ref.mounted) clear();
  }

  Future<void> clear() async {
    final store = ref.read(tokenStoreProvider);
    _generation++;
    ref.read(apiProvider).token = null;
    state = const AsyncData(null);
    ref.read(dataRevisionProvider.notifier).refresh();
    await store.serialize(store.deleteToken);
  }
}

final sessionProvider = AsyncNotifierProvider<Session, AppUser?>(Session.new);
