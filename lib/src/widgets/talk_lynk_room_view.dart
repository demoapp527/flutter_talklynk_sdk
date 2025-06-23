import 'package:flutter/material.dart';
import 'package:talklynk_sdk/src/widgets/widgets.dart';

import '../models/models.dart';

class TalkLynkRoomView extends StatefulWidget {
  final TalkLynkRoom room;
  final bool showChat;
  final bool showParticipants;
  final bool showAdminControls;

  const TalkLynkRoomView({
    Key? key,
    required this.room,
    this.showChat = true,
    this.showParticipants = true,
    this.showAdminControls = true,
  }) : super(key: key);

  @override
  State<TalkLynkRoomView> createState() => _TalkLynkRoomViewState();
}

class _TalkLynkRoomViewState extends State<TalkLynkRoomView> {
  bool _chatVisible = true;
  bool _participantsVisible = false;
  List<TalkLynkUser> _participants = [];
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to participants updates
    widget.room.participants.listen((participants) {
      setState(() {
        _participants = participants;
      });
    });

    // Listen to new messages
    widget.room.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Top bar with room info
          _buildTopBar(),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Video/participants area
                Expanded(
                  flex: _chatVisible ? 2 : 1,
                  child: _buildMainContent(),
                ),

                // Chat sidebar
                if (_chatVisible && widget.showChat)
                  Container(
                    width: 300,
                    child: ChatWidget(
                      room: widget.room,
                      messages: _messages,
                      onSendMessage: _sendMessage,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom controls
          MediaControlBar(
            room: widget.room,
            onToggleChat: () => setState(() => _chatVisible = !_chatVisible),
            onToggleParticipants: () =>
                setState(() => _participantsVisible = !_participantsVisible),
            onLeaveRoom: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam, color: Colors.white),
          SizedBox(width: 8),
          Text(
            widget.room.name,
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Spacer(),
          if (widget.room.isAdmin)
            Icon(Icons.admin_panel_settings, color: Colors.amber, size: 20),
          SizedBox(width: 8),
          Text(
            '${_participants.length}/${widget.room.maxParticipants}',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (widget.room.type == RoomType.chat) {
      return ParticipantList(
        participants: _participants,
        currentUser: widget.room.currentUser,
        onKickParticipant: widget.room.isAdmin ? _kickParticipant : null,
      );
    }

    return Stack(
      children: [
        // Video grid
        ParticipantGrid(
          room: widget.room,
          participants: _participants,
        ),

        // Admin controls overlay
        if (widget.room.isAdmin && widget.showAdminControls)
          Positioned(
            top: 16,
            right: 16,
            child: AdminControlPanel(
              room: widget.room,
              participants: _participants,
              onKickParticipant: _kickParticipant,
              onMuteAll: _muteAllParticipants,
              onTransferAdmin: _transferAdmin,
            ),
          ),

        // Participants list overlay
        if (_participantsVisible)
          Positioned(
            left: 16,
            top: 16,
            bottom: 16,
            child: Container(
              width: 250,
              child: ParticipantList(
                participants: _participants,
                currentUser: widget.room.currentUser,
                onKickParticipant:
                    widget.room.isAdmin ? _kickParticipant : null,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _sendMessage(String message) async {
    try {
      await widget.room.sendMessage(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _kickParticipant(String participantId) async {
    try {
      await widget.room.kickParticipant(participantId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Participant kicked successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to kick participant: $e')),
      );
    }
  }

  Future<void> _muteAllParticipants() async {
    try {
      await widget.room.muteAllParticipants();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All participants muted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mute all: $e')),
      );
    }
  }

  Future<void> _transferAdmin(String newAdminId) async {
    try {
      await widget.room.transferAdmin(newAdminId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin role transferred')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to transfer admin: $e')),
      );
    }
  }
}
