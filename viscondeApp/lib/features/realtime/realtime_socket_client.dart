import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

class RealtimeSocketEvent {
  const RealtimeSocketEvent({required this.event, required this.payload});

  final String event;
  final Map<String, dynamic> payload;
}

class RealtimeSocketClient {
  RealtimeSocketClient();

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;

  final _eventsController = StreamController<RealtimeSocketEvent>.broadcast();
  final _errorsController = StreamController<String>.broadcast();

  Stream<RealtimeSocketEvent> get events => _eventsController.stream;
  Stream<String> get errors => _errorsController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required String wsUrl,
    required String participantToken,
    String? clientId,
  }) async {
    await disconnect();

    _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));

    _subscription = _channel!.stream.listen(
      (raw) {
        if (raw is! String) {
          return;
        }

        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            return;
          }

          final event = decoded['event'];
          final payload = decoded['payload'];

          if (event is! String) {
            return;
          }

          _eventsController.add(
            RealtimeSocketEvent(
              event: event,
              payload: payload is Map<String, dynamic>
                  ? payload
                  : <String, dynamic>{},
            ),
          );
        } catch (_) {
          _errorsController.add('Mensagem realtime inválida.');
        }
      },
      onError: (error) {
        _errorsController.add('Erro no realtime socket.');
      },
      onDone: () {
        _errorsController.add('Conexão realtime encerrada.');
      },
      cancelOnError: false,
    );

    send('auth.join', {
      'participantToken': participantToken,
      if (clientId != null && clientId.trim().isNotEmpty)
        'clientId': clientId.trim(),
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      send('presence.ping', {'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  void send(String event, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    channel.sink.add(jsonEncode({'event': event, 'payload': payload}));
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
    await _errorsController.close();
  }
}
