// lib/src/services/webrtc_service.dart

import 'dart:async';

import 'package:talklynk_sdk/talklynk_sdk.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';

class WebRTCService {
  final Logger _logger;

  final Map<int, RTCPeerConnection> _peerConnections = {};
  final Map<int, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;

  final StreamController<WebRTCEvent> _eventController =
      StreamController.broadcast();

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  WebRTCService({required bool enableLogs})
      : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        );

  Stream<WebRTCEvent> get events => _eventController.stream;
  MediaStream? get localStream => _localStream;
  Map<int, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);

  Future<MediaStream> getUserMedia(MediaConstraints constraints) async {
    _logger.d('Getting user media with constraints: ${constraints.toMap()}');

    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(constraints.toMap());
      _logger.d(
          'Got local stream with ${_localStream!.getTracks().length} tracks');

      _eventController.add(WebRTCEvent.localStreamAdded(_localStream!));
      return _localStream!;
    } catch (e) {
      _logger.e('Failed to get user media: $e');
      throw WebRTCException('Failed to access camera/microphone: $e');
    }
  }

  Future<MediaStream> getDisplayMedia() async {
    _logger.d('Getting display media');

    try {
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': true,
      });

      _logger.d('Got display stream');
      return stream;
    } catch (e) {
      _logger.e('Failed to get display media: $e');
      throw WebRTCException('Failed to access screen sharing: $e');
    }
  }

  Future<RTCPeerConnection> createPeerConnections(int userId) async {
    _logger.d('Creating peer connection for user: $userId');

    final pc = await createPeerConnection(_iceServers);
    _peerConnections[userId] = pc;

    // Add local stream tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // Handle remote stream
    pc.onTrack = (RTCTrackEvent event) {
      _logger.d('Received remote track from user: $userId');
      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams.first;
        _remoteStreams[userId] = remoteStream;
        _eventController
            .add(WebRTCEvent.remoteStreamAdded(userId, remoteStream));
      }
    };

    // Handle ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _logger.d('ICE candidate for user $userId: ${candidate.candidate}');
      _eventController
          .add(WebRTCEvent.iceCandidateGenerated(userId, candidate));
    };

    // Handle connection state changes
    pc.onConnectionState = (RTCPeerConnectionState state) {
      _logger.d('Peer connection state for user $userId: $state');
      _eventController.add(WebRTCEvent.connectionStateChanged(userId, state));

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _removePeerConnection(userId);
      }
    };

    return pc;
  }

  Future<RTCSessionDescription> createOffer(int userId) async {
    final pc = _peerConnections[userId];
    if (pc == null) {
      throw WebRTCException('No peer connection found for user: $userId');
    }

    _logger.d('Creating offer for user: $userId');

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    return offer;
  }

  Future<RTCSessionDescription> createAnswer(
      int userId, RTCSessionDescription offer) async {
    final pc = _peerConnections[userId] ?? await createPeerConnections(userId);

    _logger.d('Creating answer for user: $userId');

    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    return answer;
  }

  Future<void> handleOffer(int userId, RTCSessionDescription offer) async {
    _logger.d('Handling offer from user: $userId');

    final answer = await createAnswer(userId, offer);
    _eventController.add(WebRTCEvent.answerCreated(userId, answer));
  }

  Future<void> handleAnswer(int userId, RTCSessionDescription answer) async {
    final pc = _peerConnections[userId];
    if (pc == null) {
      _logger.e('No peer connection found for user: $userId');
      return;
    }

    _logger.d('Handling answer from user: $userId');
    await pc.setRemoteDescription(answer);
  }

  Future<void> handleIceCandidate(int userId, RTCIceCandidate candidate) async {
    final pc = _peerConnections[userId];
    if (pc == null) {
      _logger.e('No peer connection found for user: $userId');
      return;
    }

    _logger.d('Handling ICE candidate from user: $userId');
    await pc.addCandidate(candidate);
  }

  void _removePeerConnection(int userId) {
    _logger.d('Removing peer connection for user: $userId');

    final pc = _peerConnections.remove(userId);
    pc?.close();

    final remoteStream = _remoteStreams.remove(userId);
    if (remoteStream != null) {
      _eventController.add(WebRTCEvent.remoteStreamRemoved(userId));
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> toggleAudio(bool enabled) async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = enabled;
      }
    }
  }

  Future<void> toggleVideo(bool enabled) async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = enabled;
      }
    }
  }

  void cleanup() {
    _logger.d('Cleaning up WebRTC service');

    // Close all peer connections
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();

    // Clear remote streams
    _remoteStreams.clear();

    // Stop local stream
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream = null;
    }

    _eventController.add(WebRTCEvent.cleanup());
  }

  void dispose() {
    cleanup();
    _eventController.close();
  }
}

// WebRTC Events
abstract class WebRTCEvent {
  const WebRTCEvent();

  factory WebRTCEvent.localStreamAdded(MediaStream stream) = LocalStreamAdded;
  factory WebRTCEvent.remoteStreamAdded(int userId, MediaStream stream) =
      RemoteStreamAdded;
  factory WebRTCEvent.remoteStreamRemoved(int userId) = RemoteStreamRemoved;
  factory WebRTCEvent.iceCandidateGenerated(
      int userId, RTCIceCandidate candidate) = IceCandidateGenerated;
  factory WebRTCEvent.answerCreated(int userId, RTCSessionDescription answer) =
      AnswerCreated;
  factory WebRTCEvent.connectionStateChanged(
      int userId, RTCPeerConnectionState state) = ConnectionStateChanged;
  factory WebRTCEvent.cleanup() = CleanupEvent;
}

class LocalStreamAdded extends WebRTCEvent {
  final MediaStream stream;
  const LocalStreamAdded(this.stream);
}

class RemoteStreamAdded extends WebRTCEvent {
  final int userId;
  final MediaStream stream;
  const RemoteStreamAdded(this.userId, this.stream);
}

class RemoteStreamRemoved extends WebRTCEvent {
  final int userId;
  const RemoteStreamRemoved(this.userId);
}

class IceCandidateGenerated extends WebRTCEvent {
  final int userId;
  final RTCIceCandidate candidate;
  const IceCandidateGenerated(this.userId, this.candidate);
}

class AnswerCreated extends WebRTCEvent {
  final int userId;
  final RTCSessionDescription answer;
  const AnswerCreated(this.userId, this.answer);
}

class ConnectionStateChanged extends WebRTCEvent {
  final int userId;
  final RTCPeerConnectionState state;
  const ConnectionStateChanged(this.userId, this.state);
}

class CleanupEvent extends WebRTCEvent {
  const CleanupEvent();
}
