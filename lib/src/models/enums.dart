enum RoomType { audio, video, chat }

enum UserRole { admin, moderator, participant }

enum ChatMessageType { text, image, file, audio, video, location, contact }

enum ConnectionStatus {
  connecting,
  connected,
  disconnected,
  reconnecting,
  failed
}
