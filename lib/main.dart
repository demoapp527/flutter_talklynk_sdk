import 'package:flutter/material.dart';
import 'package:talklynk_sdk/src/widgets/widgets.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkLynk Demo',
      theme: ThemeData.dark(),
      home: TalkLynkDemo(),
    );
  }
}

class TalkLynkDemo extends StatefulWidget {
  @override
  State<TalkLynkDemo> createState() => _TalkLynkDemoState();
}

class _TalkLynkDemoState extends State<TalkLynkDemo> {
  late TalkLynkSDK _sdk;
  TalkLynkRoom? _currentRoom;
  bool _isInitialized = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  Future<void> _initializeSDK() async {
    _sdk = TalkLynkSDK(
      apiKey: 'sk_wsoORYhld0tj800njSdIk31RYm2tKBt0',
      baseUrl: 'https://sdk.talklynk.com/backend/api',
      wsUrl: 'wss://ws.sdk.talklynk.com',
      enableLogs: true,
    );

    // Listen to SDK events
    _sdk.events.listen((event) {
      print('SDK Event: ${event.type} - ${event.data}');

      if (event.type == 'connection.connected') {
        setState(() => _isInitialized = true);
      } else if (event.type == 'connection.error') {
        _showError('Connection error: ${event.data['error']}');
      }
    });

    try {
      await _sdk.initialize();
    } catch (e) {
      _showError('Failed to initialize SDK: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentRoom != null) {
      return TalkLynkRoomView(room: _currentRoom!);
    }

    return Scaffold(
      appBar: AppBar(title: Text('TalkLynk Demo')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TalkLynk Flutter SDK Demo',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            if (!_isInitialized)
              CircularProgressIndicator()
            else ...[
              _buildJoinRoomCard('Video Call', RoomType.video, Icons.videocam),
              SizedBox(height: 16),
              _buildJoinRoomCard('Audio Call', RoomType.audio, Icons.call),
              SizedBox(height: 16),
              _buildJoinRoomCard('Chat Room', RoomType.chat, Icons.chat),
            ],
            SizedBox(height: 32),
            Text(
              'SDK Status: ${_isInitialized ? "Connected" : "Connecting..."}',
              style: TextStyle(
                color: _isInitialized ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinRoomCard(String title, RoomType type, IconData icon) {
    return Card(
      child: InkWell(
        onTap: () => _joinRoom(type),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Join a ${title.toLowerCase()} session'),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinRoom(RoomType type) async {
    if (_isConnecting) return;

    const roomId = 'room_AQRhkRpkqirP4Yvj';
    final username = 'user_${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _isConnecting = true);

    try {
      final room = await _sdk.joinRoom(
        roomId: roomId,
        username: username,
        displayName: 'Demo User',
        type: type,
      );

      setState(() {
        _currentRoom = room;
        _isConnecting = false;
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      _showError('Failed to join room: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _currentRoom?.dispose();
    _sdk.dispose();
    super.dispose();
  }
}
