import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../features/auth/session.dart';
import 'api.dart';
import 'config.dart';
import 'models.dart';

enum LiveStatus { offline, connecting, live }

class ReverbSettings {
  const ReverbSettings(
      {this.host = AppConfig.reverbHost,
      this.port = AppConfig.reverbPort,
      this.key = AppConfig.reverbKey,
      this.tls = AppConfig.reverbTls});
  final String host, key;
  final int port;
  final bool tls;
}

final reverbSettingsProvider =
    Provider<ReverbSettings>((ref) => const ReverbSettings());

class ReverbConnection extends Notifier<LiveStatus>
    with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry,
      _heartbeat,
      _pongDeadline,
      _refreshDebounce,
      _subscriptionDeadline;
  int _epoch = 0, _attempt = 0;
  bool _disposed = false, _background = false;
  Set<String> _pending = {};
  AppUser? _user;
  @override
  LiveStatus build() {
    WidgetsBinding.instance.addObserver(this);
    ref.listen(sessionProvider, (previous, next) {
      _user = next.asData?.value;
      _restart();
    });
    _user = ref.read(sessionProvider).asData?.value;
    ref.onDispose(() {
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
      _close();
    });
    Future.microtask(_restart);
    return LiveStatus.offline;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _background = false;
      ref.read(dataRevisionProvider.notifier).refresh();
      _restart();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _background = true;
      _close();
      if (!_disposed) this.state = LiveStatus.offline;
    }
  }

  void _close() {
    _epoch++;
    _retry?.cancel();
    _heartbeat?.cancel();
    _pongDeadline?.cancel();
    _refreshDebounce?.cancel();
    _subscriptionDeadline?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _pending = {};
  }

  void _restart() {
    _close();
    if (_disposed || _background) return;
    if (ref.read(reverbSettingsProvider).key.isEmpty) {
      state = LiveStatus.offline;
      return;
    }
    _connect();
  }

  Future<void> _connect() async {
    final epoch = _epoch;
    state = LiveStatus.connecting;
    try {
      final settings = ref.read(reverbSettingsProvider);
      final uri = Uri(
        scheme: settings.tls ? 'wss' : 'ws',
        host: settings.host,
        port: settings.port,
        path: '/app/${settings.key}',
        queryParameters: {
          'protocol': '7',
          'client': 'yerin-flutter',
          'version': '1.0',
          'flash': 'false',
        },
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 15));
      if (epoch != _epoch || _disposed) {
        channel.sink.close();
        return;
      }
      _subscriptionDeadline = Timer(
        const Duration(seconds: 20),
        () => _failed(epoch),
      );
      _subscription = channel.stream.listen(
        (raw) => _message(raw, epoch),
        onError: (Object e) => _failed(epoch),
        onDone: () => _failed(epoch),
      );
    } catch (_) {
      _failed(epoch);
    }
  }

  void _send(Json message) => _channel?.sink.add(jsonEncode(message));
  Future<void> _message(dynamic raw, int epoch) async {
    if (_disposed || epoch != _epoch) return;
    try {
      final message = object(jsonDecode(raw as String));
      final data = message['data'] is String
          ? object(jsonDecode(message['data'] as String))
          : object(message['data']);
      switch (message['event']) {
        case 'pusher:connection_established':
          final socketId = string(data['socket_id']);
          final user = _user;
          final channels = [
            'events',
            if (user != null) 'private-user.${user.id}',
            if (user?.role == Role.organizer) 'private-organizer.${user!.id}',
            if (user?.role == Role.admin) 'private-admin',
          ];
          _pending = channels.toSet();
          for (final name in channels) {
            Json authorization = {};
            if (name.startsWith('private-')) {
              authorization = await ref.read(apiProvider).post(
                '/broadcasting/auth',
                {'socket_id': socketId, 'channel_name': name},
              );
            }
            if (epoch != _epoch || _disposed) return;
            _send({
              'event': 'pusher:subscribe',
              'data': {'channel': name, ...authorization},
            });
          }
          final seconds = integer(data['activity_timeout']);
          _heartbeat?.cancel();
          _heartbeat = Timer.periodic(
            Duration(seconds: seconds > 10 ? min(seconds ~/ 2, 30) : 20),
            (_) {
              _send({'event': 'pusher:ping', 'data': {}});
              _pongDeadline?.cancel();
              _pongDeadline = Timer(
                const Duration(seconds: 10),
                () => _failed(epoch),
              );
            },
          );
        case 'pusher_internal:subscription_succeeded':
          _pending.remove(string(message['channel']));
          if (_pending.isEmpty) {
            _subscriptionDeadline?.cancel();
            state = LiveStatus.live;
            _attempt = 0;
            _invalidate();
          }
        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
        case 'pusher:pong':
          _pongDeadline?.cancel();
        case 'pusher:error':
          _failed(epoch);
        case 'event.updated':
        case 'order.created':
        case 'ticket.checked-in':
          _invalidate();
      }
    } catch (_) {
      _failed(epoch);
    }
  }

  void _invalidate() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!_disposed) ref.read(dataRevisionProvider.notifier).refresh();
    });
  }

  void _failed(int epoch) {
    if (_disposed || epoch != _epoch) return;
    _close();
    state = LiveStatus.offline;
    if (_background) return;
    final seconds = min(30, pow(2, min(_attempt++, 5)).toInt());
    _retry = Timer(Duration(seconds: seconds), _connect);
  }
}

final realtimeProvider = NotifierProvider<ReverbConnection, LiveStatus>(
  ReverbConnection.new,
);
