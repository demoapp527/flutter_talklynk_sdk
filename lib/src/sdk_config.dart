import 'package:talklynk_sdk/talklynk_sdk.dart';

class TalklynkSdkConfig {
  final String apiKey;
  final String baseUrl;
  final String wsUrl;
  final Environment environment;
  final bool enableLogs;
  final Map<String, String>? customHeaders;

  const TalklynkSdkConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.talklynk.com/api/sdk',
    this.wsUrl = 'wss://ws.talklynk.com',
    this.environment = Environment.production,
    this.enableLogs = false,
    this.customHeaders,
  });

  // Development configuration
  factory TalklynkSdkConfig.development({
    required String apiKey,
    String baseUrl = 'http://localhost:8000/api/sdk',
    String wsUrl = 'ws://localhost:6001',
    bool enableLogs = true,
    Map<String, String>? customHeaders,
  }) {
    return TalklynkSdkConfig(
      apiKey: apiKey,
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      environment: Environment.development,
      enableLogs: enableLogs,
      customHeaders: customHeaders,
    );
  }

  // Staging configuration
  factory TalklynkSdkConfig.staging({
    required String apiKey,
    String baseUrl = 'https://staging-api.talklynk.com/api/sdk',
    String wsUrl = 'wss://staging-ws.talklynk.com',
    bool enableLogs = true,
    Map<String, String>? customHeaders,
  }) {
    return TalklynkSdkConfig(
      apiKey: apiKey,
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      environment: Environment.staging,
      enableLogs: enableLogs,
      customHeaders: customHeaders,
    );
  }

  TalklynkSdkConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? wsUrl,
    Environment? environment,
    bool? enableLogs,
    Map<String, String>? customHeaders,
  }) {
    return TalklynkSdkConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      wsUrl: wsUrl ?? this.wsUrl,
      environment: environment ?? this.environment,
      enableLogs: enableLogs ?? this.enableLogs,
      customHeaders: customHeaders ?? this.customHeaders,
    );
  }
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
  final Map<String, dynamic>? settings;

  const CreateRoomOptions({
    required this.name,
    required this.type,
    this.maxParticipants,
    this.settings,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        if (maxParticipants != null) 'max_participants': maxParticipants,
        if (settings != null) 'settings': settings,
      };
}

class JoinRoomOptions {
  final int userId;
  final String? role;
  final Map<String, dynamic>? permissions;

  const JoinRoomOptions({
    required this.userId,
    this.role,
    this.permissions,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (role != null) 'role': role,
        if (permissions != null) 'permissions': permissions,
      };
}

class SendMessageOptions {
  final int userId;
  final String? message;
  final MessageType type;
  final String? filePath;
  final Map<String, dynamic>? metadata;

  const SendMessageOptions({
    required this.userId,
    this.message,
    required this.type,
    this.filePath,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (message != null) 'message': message,
        'type': type.name,
        if (metadata != null) 'metadata': metadata,
      };
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

  static const VideoResolution qvga = VideoResolution(width: 320, height: 240);
  static const VideoResolution vga = VideoResolution(width: 640, height: 480);
  static const VideoResolution hd = VideoResolution(width: 1280, height: 720);
  static const VideoResolution fullHd =
      VideoResolution(width: 1920, height: 1080);
}
