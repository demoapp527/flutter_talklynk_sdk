class TalkLynkEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  TalkLynkEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // SDK Events
  static TalkLynkEvent sdkInitialized(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'sdk.initialized', data: data);

  static TalkLynkEvent connected(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'connection.connected', data: data);

  static TalkLynkEvent disconnected(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'connection.disconnected', data: data);

  static TalkLynkEvent error(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'connection.error', data: data);

  // Room Events
  static TalkLynkEvent roomJoined(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'room.joined', data: data);

  static TalkLynkEvent roomLeft(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'room.left', data: data);

  static TalkLynkEvent userJoined(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'user.joined', data: data);

  static TalkLynkEvent userLeft(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'user.left', data: data);

  // Chat Events
  static TalkLynkEvent chatMessage(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'chat.message', data: data);

  // WebRTC Events
  static TalkLynkEvent webrtcOffer(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'webrtc.offer', data: data);

  static TalkLynkEvent webrtcAnswer(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'webrtc.answer', data: data);

  static TalkLynkEvent webrtcIceCandidate(Map<String, dynamic> data) =>
      TalkLynkEvent(type: 'webrtc.ice_candidate', data: data);

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class RoomEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  RoomEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // User Events
  static RoomEvent userJoined(Map<String, dynamic> data) =>
      RoomEvent(type: 'user.joined', data: data);

  static RoomEvent userLeft(Map<String, dynamic> data) =>
      RoomEvent(type: 'user.left', data: data);

  // Media Events
  static RoomEvent audioToggled(Map<String, dynamic> data) =>
      RoomEvent(type: 'audio.toggled', data: data);

  static RoomEvent videoToggled(Map<String, dynamic> data) =>
      RoomEvent(type: 'video.toggled', data: data);

  // WebRTC Events
  static RoomEvent webrtcOffer(Map<String, dynamic> data) =>
      RoomEvent(type: 'webrtc.offer', data: data);

  static RoomEvent webrtcAnswer(Map<String, dynamic> data) =>
      RoomEvent(type: 'webrtc.answer', data: data);

  static RoomEvent webrtcIceCandidate(Map<String, dynamic> data) =>
      RoomEvent(type: 'webrtc.ice_candidate', data: data);

  // Admin Events
  static RoomEvent participantKicked(Map<String, dynamic> data) =>
      RoomEvent(type: 'participant.kicked', data: data);

  static RoomEvent allMuted(Map<String, dynamic> data) =>
      RoomEvent(type: 'all.muted', data: data);

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
