// example/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

void main() {
  runApp(ExampleTalkLynkApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WebRTCProvider(
        const TalklynkSdkConfig(
          apiKey: 'sk_wsoORYhld0tj800njSdIk31RYm2tKBt0',
          baseUrl: 'https://sdk.talklynk.com/backend/api/sdk',
          wsUrl: 'wss://ws.sdk.talklynk.com:443',
          enableLogs: true,
        ),
      ),
      child: MaterialApp(
        title: 'WebRTC SDK Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _userNameController =
      TextEditingController(text: 'Flutter User');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToWebRTC();
    });
  }

  Future<void> _connectToWebRTC() async {
    final provider = Provider.of<WebRTCProvider>(context, listen: false);

    // Set current user
    provider.setCurrentUser(User(
      id: DateTime.now().millisecondsSinceEpoch, // Generate unique ID
      name: _userNameController.text,
    ));

    // Connect to platform
    await provider.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC SDK Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<WebRTCProvider>(
        builder: (context, provider, child) {
          if (!provider.isConnected) {
            return _buildConnectionScreen(provider);
          }

          if (provider.currentRoom != null) {
            return _buildRoomScreen(provider);
          }

          return _buildLobbyScreen(provider);
        },
      ),
    );
  }

  Widget _buildConnectionScreen(WebRTCProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (provider.connectionError != null) ...[
            Icon(
              Icons.error,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                provider.connectionError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.connect(),
              child: const Text('Retry'),
            ),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Connecting to WebRTC Platform...'),
          ],
        ],
      ),
    );
  }

  Widget _buildLobbyScreen(WebRTCProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join or Create Room',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userNameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      provider.setCurrentUser(User(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: value,
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'Room ID',
                      border: OutlineInputBorder(),
                      hintText: 'Enter room ID or leave empty to create new',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _createRoom(provider),
                          child: const Text('Create Room'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _joinRoom(provider),
                          child: const Text('Join Room'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Recent rooms could be shown here
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: provider.isConnected ? Colors.green : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color:
                              provider.isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomScreen(WebRTCProvider provider) {
    return Column(
      children: [
        // Room header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.currentRoom!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Participants: ${provider.participants.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (!provider.isInCall)
                ElevatedButton.icon(
                  onPressed: () => provider.startCall(),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Start Call'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => provider.endCall(),
                  icon: const Icon(Icons.call_end),
                  label: const Text('End Call'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => provider.leaveRoom(),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Leave'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              ),
            ],
          ),
        ),

        // Main content
        Expanded(
          child: provider.isInCall
              ? VideoCallWidget(
                  localStream: provider.localStream,
                  remoteStreams: provider.remoteStreams,
                  onEndCall: () => provider.endCall(),
                  onToggleAudio: () => provider.toggleAudio(),
                  onToggleVideo: () => provider.toggleVideo(),
                  onSwitchCamera: () => provider.switchCamera(),
                  isAudioEnabled: provider.isAudioEnabled,
                  isVideoEnabled: provider.isVideoEnabled,
                )
              : ChatWidget(
                  messages: provider.messages,
                  onSendMessage: (message) => provider.sendMessage(message),
                  onSendFile: (filePath) => provider.sendFile(filePath),
                  currentUser: provider.client.currentUser,
                  roomId: provider.currentRoom?.roomId,
                ),
        ),
      ],
    );
  }

  Future<void> _createRoom(WebRTCProvider provider) async {
    try {
      final roomName = _roomIdController.text.trim().isEmpty
          ? 'Room ${DateTime.now().millisecondsSinceEpoch}'
          : _roomIdController.text.trim();

      final room = await provider.createRoom(
        CreateRoomOptions(
          name: roomName,
          type: RoomType.video,
          maxParticipants: 10,
        ),
      );

      await provider.joinRoom(room.roomId);
    } catch (e) {
      _showError('Failed to create room: $e');
    }
  }

  Future<void> _joinRoom(WebRTCProvider provider) async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      _showError('Please enter a room ID');
      return;
    }

    try {
      await provider.joinRoom(roomId);
    } catch (e) {
      _showError('Failed to join room: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _userNameController.dispose();
    super.dispose();
  }
}

class ExampleTalkLynkApp extends StatefulWidget {
  @override
  _ExampleTalkLynkAppState createState() => _ExampleTalkLynkAppState();
}

class _ExampleTalkLynkAppState extends State<ExampleTalkLynkApp> {
  late WebRTCProvider _provider;
  final String _apiKey = ''; // Replace with actual API key

  @override
  void initState() {
    super.initState();

    // Initialize with your API key
    final config = TalklynkSdkConfig.development(
      apiKey: _apiKey,
      baseUrl: 'https://sdk.talklynk.com/backend/api/sdk',
      wsUrl: 'wss://ws.sdk.talklynk.com:443',
      enableLogs: true,
    );

    _provider = WebRTCProvider(config);

    // Set current user (this should come from your authentication system)
    _provider.setCurrentUser(User(
      id: 1, // User ID from your system
      name: 'John Doe',
      email: 'john@example.com',
    ));

    // Connect to the service
    _provider.connect();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: MaterialApp(
        title: 'TalkLynk Demo',
        home: Consumer<WebRTCProvider>(
          builder: (context, provider, child) {
            if (!provider.isConnected) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Connecting...'),
                      if (provider.connectionError != null) ...[
                        SizedBox(height: 16),
                        Text(
                          'Error: ${provider.connectionError}',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            if (provider.currentRoom == null) {
              return RoomListScreen();
            }

            return RoomScreen();
          },
        ),
      ),
    );
  }
}

class RoomListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rooms')),
      body: Consumer<WebRTCProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _createRoom(context, provider),
                  child: Text('Create Room'),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Room>>(
                  future: provider.getRooms(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final rooms = snapshot.data ?? [];

                    return ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return ListTile(
                          title: Text(room.name),
                          subtitle: Text('Type: ${room.type.name}'),
                          onTap: () => provider.joinRoom(room.roomId),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _createRoom(BuildContext context, WebRTCProvider provider) async {
    final options = CreateRoomOptions(
      name: 'Test Room ${DateTime.now().millisecondsSinceEpoch}',
      type: RoomType.video,
      maxParticipants: 10,
    );

    try {
      final room = await provider.createRoom(options);
      provider.joinRoom(room.roomId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create room: $e')),
      );
    }
  }
}

class RoomScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WebRTCProvider>(
      builder: (context, provider, child) {
        final room = provider.currentRoom!;

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            actions: [
              IconButton(
                icon: Icon(Icons.exit_to_app),
                onPressed: provider.leaveRoom,
              ),
            ],
          ),
          body: Column(
            children: [
              // Video call area
              if (provider.isInCall) ...[
                Expanded(
                  flex: 2,
                  child: VideoCallWidget(
                    localStream: provider.localStream,
                    remoteStreams: provider.remoteStreams,
                    isAudioEnabled: provider.isAudioEnabled,
                    isVideoEnabled: provider.isVideoEnabled,
                    onEndCall: provider.endCall,
                    onToggleAudio: provider.toggleAudio,
                    onToggleVideo: provider.toggleVideo,
                    onSwitchCamera: provider.switchCamera,
                  ),
                ),
              ] else ...[
                Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Participants: ${provider.participants.length}'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: provider.startCall,
                          child: Text('Start Call'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Chat area
              Expanded(
                flex: 3,
                child: ChatWidget(
                  messages: provider.messages,
                  currentUser: provider.currentUser,
                  roomId: room.roomId,
                  onSendMessage: provider.sendMessage,
                  onSendFile: provider.sendFile,
                  onTypingChanged: provider.sendTypingIndicator,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
