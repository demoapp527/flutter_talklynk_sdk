// lib/src/models/sdk_config.dart

import 'package:talklynk_sdk/talklynk_sdk.dart';

class TalklynkSdkConfig {
  final String apiKey;
  final String baseUrl;
  final String wsUrl;
  final Environment environment;
  final bool enableLogs;

  const TalklynkSdkConfig({
    required this.apiKey,
    this.baseUrl = 'http://localhost:8000/api/sdk',
    this.wsUrl = 'ws://localhost:6001',
    this.environment = Environment.development,
    this.enableLogs = false,
  });
}

enum Environment {
  development,
  staging,
  production,
}

class CreateRoomOptions {
  final String name;
  final RoomType type;
  final int? maxParticipants;

  const CreateRoomOptions({
    required this.name,
    required this.type,
    this.maxParticipants,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        if (maxParticipants != null) 'max_participants': maxParticipants,
      };
}

class SendMessageOptions {
  final String? message;
  final MessageType type;
  final String? filePath;
  final Map<String, dynamic>? metadata;

  const SendMessageOptions({
    this.message,
    required this.type,
    this.filePath,
    this.metadata,
  });
}

class MediaConstraints {
  final bool video;
  final bool audio;
  final bool facingMode; // true for front camera, false for back
  final VideoResolution? videoResolution;

  const MediaConstraints({
    this.video = true,
    this.audio = true,
    this.facingMode = true,
    this.videoResolution,
  });

  Map<String, dynamic> toMap() => {
        'video': video
            ? {
                'facingMode': facingMode ? 'user' : 'environment',
                if (videoResolution != null) ...videoResolution!.toMap(),
              }
            : false,
        'audio': audio,
      };
}

class VideoResolution {
  final int width;
  final int height;

  const VideoResolution({required this.width, required this.height});

  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
      };
}
