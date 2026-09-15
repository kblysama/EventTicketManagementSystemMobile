import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerin_mobile/core/api.dart';
import 'package:yerin_mobile/core/models.dart';
import 'package:yerin_mobile/features/auth/session.dart';

class FakeApi extends ApiClient {
  Completer<Json>? logoutResponse;
  @override
  Future<Json> post(String path, dynamic data) async {
    if (path == '/auth/logout') return logoutResponse!.future;
    return {
      'token': data['token'],
      'user': {
        'id': data['id'],
        'name': 'Test',
        'email': 'test@example.com',
        'role': 'attendee',
      },
    };
  }
}

void main() {
  test(
    'logout deletes a token even when authentication storage write is pending',
    () async {
      String? stored;
      final writeStarted = Completer<void>(), finishWrite = Completer<void>();
      final store = TokenStore(
        readToken: () async => stored,
        writeToken: (token) async {
          writeStarted.complete();
          await finishWrite.future;
          stored = token;
        },
        deleteToken: () async {
          stored = null;
        },
      );
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(FakeApi()),
          tokenStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future);
      final session = container.read(sessionProvider.notifier);
      final login = session.authenticate('login', {'token': 'old', 'id': 1});
      await writeStarted.future;
      final clear = session.clear();
      finishWrite.complete();
      await Future.wait([login, clear]);
      expect(stored, null);
      expect(container.read(apiProvider).token, null);
      expect(container.read(sessionProvider).asData?.value, null);
    },
  );
  test(
    'old logout response cannot clear a newly authenticated account',
    () async {
      String? stored;
      final api = FakeApi()..logoutResponse = Completer<Json>();
      final store = TokenStore(
        readToken: () async => stored,
        writeToken: (v) async {
          stored = v;
        },
        deleteToken: () async {
          stored = null;
        },
      );
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future);
      final session = container.read(sessionProvider.notifier);
      await session.authenticate('login', {'token': 'old', 'id': 1});
      final logout = session.logout();
      await session.authenticate('login', {'token': 'new', 'id': 2});
      api.logoutResponse!.complete({});
      await logout;
      expect(stored, 'new');
      expect(container.read(sessionProvider).asData?.value?.id, 2);
    },
  );
}
