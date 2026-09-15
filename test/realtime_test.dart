import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerin_mobile/core/api.dart';
import 'package:yerin_mobile/core/models.dart';
import 'package:yerin_mobile/core/realtime.dart';
import 'package:yerin_mobile/features/auth/session.dart';

class RealtimeSession extends Session {
  @override
  Future<AppUser?> build() async => const AppUser(
      id: 7,
      name: 'Organizer',
      email: 'organizer@example.com',
      role: Role.organizer);
}

class AuthApi extends ApiClient {
  final channels = <String>[];
  @override
  Future<Json> post(String path, dynamic data) async {
    expect(path, '/broadcasting/auth');
    channels.add(data['channel_name'] as String);
    return {'auth': 'public-key:test-signature'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Reverb subscribes with authorization and resynchronizes after reconnect',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final subscribed = <String>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode(
            {'socket_id': '1.${sockets.length}', 'activity_timeout': 120})
      }));
      socket.listen((raw) {
        final j = object(jsonDecode(raw as String));
        if (j['event'] == 'pusher:subscribe') {
          final name = string(object(j['data'])['channel']);
          subscribed.add(name);
          socket.add(jsonEncode({
            'event': 'pusher_internal:subscription_succeeded',
            'channel': name,
            'data': '{}'
          }));
        }
      });
    });
    final api = AuthApi();
    final container = ProviderContainer(overrides: [
      apiProvider.overrideWithValue(api),
      sessionProvider.overrideWith(RealtimeSession.new),
      reverbSettingsProvider.overrideWithValue(
          ReverbSettings(host: '127.0.0.1', port: server.port, key: 'test-key'))
    ]);
    addTearDown(() async {
      container.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    await container.read(sessionProvider.future);
    var ready = Completer<void>();
    container.listen(realtimeProvider, (_, next) {
      if (next == LiveStatus.live && !ready.isCompleted) ready.complete();
    }, fireImmediately: true);
    await ready.future.timeout(const Duration(seconds: 5));
    expect(subscribed,
        containsAll(['events', 'private-user.7', 'private-organizer.7']));
    expect(
        api.channels, containsAll(['private-user.7', 'private-organizer.7']));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final before = container.read(dataRevisionProvider);
    final changed = Completer<void>();
    final subscription = container.listen(dataRevisionProvider, (_, next) {
      if (next > before && !changed.isCompleted) changed.complete();
    });
    sockets.last.add(jsonEncode({
      'event': 'ticket.checked-in',
      'channel': 'private-organizer.7',
      'data': '{"code":"QR-A"}'
    }));
    await changed.future.timeout(const Duration(seconds: 3));
    subscription.close();
    ready = Completer<void>();
    final beforeReconnect = container.read(dataRevisionProvider);
    await sockets.last.close();
    await ready.future.timeout(const Duration(seconds: 6));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(container.read(dataRevisionProvider), greaterThan(beforeReconnect));
    expect(sockets.length, greaterThanOrEqualTo(2));
  });
}
