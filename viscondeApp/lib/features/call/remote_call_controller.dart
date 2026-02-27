import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../realtime/realtime_socket_client.dart';
import '../story_room/models/story_models.dart';

class RemoteCallController extends ChangeNotifier {
  RemoteCallController({
    required this.isHost,
    required this.rtcConfig,
    required this.sendSignal,
  });

  final bool isHost;
  final Map<String, dynamic> rtcConfig;
  final void Function(String event, Map<String, dynamic> payload) sendSignal;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _audioStream;
  MediaStream? _videoStream;

  bool _initialized = false;
  bool _hostOfferSent = false;
  bool _videoEnabled = false;
  String _connectionState = "NEW";
  String? _errorMessage;

  String get connectionState => _connectionState;
  bool get videoEnabled => _videoEnabled;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await localRenderer.initialize();
    await remoteRenderer.initialize();
    await _createPeerConnection();
    await _ensureAudioStream();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _createPeerConnection() async {
    final configuration = {
      "iceServers": _parseIceServers(rtcConfig["iceServers"]),
      "sdpSemantics": "unified-plan",
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }

      sendSignal("rtc.ice", {
        "candidate": {
          "candidate": candidate.candidate,
          "sdpMid": candidate.sdpMid,
          "sdpMLineIndex": candidate.sdpMLineIndex,
        },
      });
    };

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        notifyListeners();
      }
    };

    _peerConnection?.onConnectionState = (state) {
      _connectionState = state.name.toUpperCase();
      notifyListeners();
    };
  }

  List<Map<String, dynamic>> _parseIceServers(dynamic raw) {
    if (raw is! List<dynamic>) {
      return const [
        {
          "urls": ["stun:stun.l.google.com:19302"],
        },
      ];
    }

    final parsed = raw
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => <String, dynamic>{
            "urls": item["urls"],
            if (item["username"] != null) "username": item["username"],
            if (item["credential"] != null) "credential": item["credential"],
          },
        )
        .where((item) => item["urls"] != null)
        .toList();

    if (parsed.isEmpty) {
      return const [
        {
          "urls": ["stun:stun.l.google.com:19302"],
        },
      ];
    }

    return parsed;
  }

  Future<void> _ensureAudioStream() async {
    if (_audioStream != null) {
      return;
    }

    final stream = await navigator.mediaDevices.getUserMedia({
      "audio": true,
      "video": false,
    });
    _audioStream = stream;

    final peer = _peerConnection;
    if (peer != null) {
      for (final track in stream.getTracks()) {
        await peer.addTrack(track, stream);
      }
    }
  }

  Future<void> _ensureVideoTrack() async {
    if (_videoEnabled) {
      for (final track
          in _videoStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
        track.enabled = true;
      }
      return;
    }

    _videoStream ??= await navigator.mediaDevices.getUserMedia({
      "audio": false,
      "video": {"facingMode": "user"},
    });

    final peer = _peerConnection;
    if (peer != null && _videoStream != null) {
      for (final track in _videoStream!.getVideoTracks()) {
        await peer.addTrack(track, _videoStream!);
      }
    }

    localRenderer.srcObject = _videoStream;
    _videoEnabled = true;
    notifyListeners();
  }

  Future<void> setMode(RemoteCallMode mode) async {
    try {
      await _ensureAudioStream();

      switch (mode) {
        case RemoteCallMode.none:
          for (final track
              in _audioStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
            track.enabled = false;
          }
          for (final track
              in _videoStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
            track.enabled = false;
          }
          localRenderer.srcObject = null;
          _videoEnabled = false;
          break;
        case RemoteCallMode.audio:
          for (final track
              in _audioStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
            track.enabled = true;
          }
          for (final track
              in _videoStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
            track.enabled = false;
          }
          localRenderer.srcObject = null;
          _videoEnabled = false;
          break;
        case RemoteCallMode.video:
          for (final track
              in _audioStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
            track.enabled = true;
          }
          await _ensureVideoTrack();
          await _createAndSendOffer(force: true);
          break;
      }
    } catch (_) {
      _errorMessage = "Falha ao preparar chamada de audio/video.";
      notifyListeners();
    }
  }

  Future<void> ensureHostOfferIfNeeded({required int participantCount}) async {
    if (!isHost || participantCount < 2) {
      return;
    }

    await _createAndSendOffer(force: false);
  }

  Future<void> _createAndSendOffer({required bool force}) async {
    if (!isHost) {
      return;
    }

    if (_hostOfferSent && !force) {
      return;
    }

    final peer = _peerConnection;
    if (peer == null) {
      return;
    }

    try {
      final offer = await peer.createOffer({
        "offerToReceiveAudio": true,
        "offerToReceiveVideo": true,
      });
      await peer.setLocalDescription(offer);
      sendSignal("rtc.offer", {
        "sdp": {"type": offer.type, "sdp": offer.sdp},
      });
      _hostOfferSent = true;
    } catch (_) {
      _errorMessage = "Falha ao iniciar oferta WebRTC.";
      notifyListeners();
    }
  }

  Future<void> handleRealtimeEvent(RealtimeSocketEvent event) async {
    switch (event.event) {
      case "rtc.offer":
        await _handleOffer(event.payload["sdp"]);
        break;
      case "rtc.answer":
        await _handleAnswer(event.payload["sdp"]);
        break;
      case "rtc.ice":
        await _handleIce(event.payload["candidate"]);
        break;
      case "rtc.hangup":
      case "remote.closed":
        await hangup(sendSignalEvent: false);
        break;
      default:
        break;
    }
  }

  Future<void> _handleOffer(dynamic rawSdp) async {
    final peer = _peerConnection;
    if (peer == null) {
      return;
    }

    final sdp = rawSdp is Map<String, dynamic>
        ? rawSdp
        : const <String, dynamic>{};
    final type = sdp["type"]?.toString();
    final description = sdp["sdp"]?.toString();
    if (type == null ||
        description == null ||
        type.isEmpty ||
        description.isEmpty) {
      return;
    }

    try {
      await peer.setRemoteDescription(RTCSessionDescription(description, type));
      final answer = await peer.createAnswer({
        "offerToReceiveAudio": true,
        "offerToReceiveVideo": true,
      });
      await peer.setLocalDescription(answer);
      sendSignal("rtc.answer", {
        "sdp": {"type": answer.type, "sdp": answer.sdp},
      });
    } catch (_) {
      _errorMessage = "Falha ao responder chamada remota.";
      notifyListeners();
    }
  }

  Future<void> _handleAnswer(dynamic rawSdp) async {
    final peer = _peerConnection;
    if (peer == null) {
      return;
    }

    final sdp = rawSdp is Map<String, dynamic>
        ? rawSdp
        : const <String, dynamic>{};
    final type = sdp["type"]?.toString();
    final description = sdp["sdp"]?.toString();
    if (type == null ||
        description == null ||
        type.isEmpty ||
        description.isEmpty) {
      return;
    }

    try {
      await peer.setRemoteDescription(RTCSessionDescription(description, type));
    } catch (_) {
      _errorMessage = "Falha ao concluir sinalizacao da chamada.";
      notifyListeners();
    }
  }

  Future<void> _handleIce(dynamic rawCandidate) async {
    final peer = _peerConnection;
    if (peer == null) {
      return;
    }

    final candidateMap = rawCandidate is Map<String, dynamic>
        ? rawCandidate
        : const <String, dynamic>{};
    final candidateValue = candidateMap["candidate"]?.toString();
    if (candidateValue == null || candidateValue.isEmpty) {
      return;
    }

    final sdpMid = candidateMap["sdpMid"]?.toString();
    final sdpMLineIndexRaw = candidateMap["sdpMLineIndex"];
    int? sdpMLineIndex;
    if (sdpMLineIndexRaw is int) {
      sdpMLineIndex = sdpMLineIndexRaw;
    } else if (sdpMLineIndexRaw is num) {
      sdpMLineIndex = sdpMLineIndexRaw.toInt();
    } else if (sdpMLineIndexRaw is String) {
      sdpMLineIndex = int.tryParse(sdpMLineIndexRaw);
    }

    try {
      await peer.addCandidate(
        RTCIceCandidate(candidateValue, sdpMid, sdpMLineIndex),
      );
    } catch (_) {
      // Ignora ICE candidates invalidos/fora de ordem.
    }
  }

  Future<void> hangup({bool sendSignalEvent = true}) async {
    if (sendSignalEvent) {
      sendSignal("rtc.hangup", {});
    }

    _hostOfferSent = false;

    final peer = _peerConnection;
    _peerConnection = null;
    await peer?.close();

    remoteRenderer.srcObject = null;
    _connectionState = "CLOSED";
    notifyListeners();

    await _createPeerConnection();

    if (_audioStream != null && _peerConnection != null) {
      for (final track in _audioStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _audioStream!);
      }
    }

    if (_videoStream != null && _peerConnection != null) {
      for (final track in _videoStream!.getVideoTracks()) {
        await _peerConnection!.addTrack(track, _videoStream!);
      }
    }
  }

  Future<void> disposeController() async {
    _hostOfferSent = false;
    _initialized = false;

    final peer = _peerConnection;
    _peerConnection = null;
    await peer?.close();

    for (final track
        in _audioStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    for (final track
        in _videoStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    _audioStream = null;
    _videoStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
