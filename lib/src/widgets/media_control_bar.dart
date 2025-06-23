import 'package:flutter/material.dart';

import '../models/models.dart';

class MediaControlBar extends StatefulWidget {
  final TalkLynkRoom room;
  final VoidCallback onToggleChat;
  final VoidCallback onToggleParticipants;
  final VoidCallback onLeaveRoom;

  const MediaControlBar({
    Key? key,
    required this.room,
    required this.onToggleChat,
    required this.onToggleParticipants,
    required this.onLeaveRoom,
  }) : super(key: key);

  @override
  State<MediaControlBar> createState() => _MediaControlBarState();
}

class _MediaControlBarState extends State<MediaControlBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Audio control
          if (widget.room.type != RoomType.chat)
            _buildControlButton(
              icon: widget.room.isAudioMuted ? Icons.mic_off : Icons.mic,
              color: widget.room.isAudioMuted ? Colors.red : Colors.white,
              onPressed: widget.room.toggleAudio,
              tooltip: widget.room.isAudioMuted ? 'Unmute' : 'Mute',
            ),

          SizedBox(width: 16),

          // Video control
          if (widget.room.type == RoomType.video)
            _buildControlButton(
              icon: widget.room.isVideoMuted
                  ? Icons.videocam_off
                  : Icons.videocam,
              color: widget.room.isVideoMuted ? Colors.red : Colors.white,
              onPressed: widget.room.toggleVideo,
              tooltip: widget.room.isVideoMuted ? 'Start video' : 'Stop video',
            ),

          SizedBox(width: 16),

          // Screen share (placeholder)
          if (widget.room.type == RoomType.video)
            _buildControlButton(
              icon: Icons.screen_share,
              color: Colors.white,
              onPressed: () {
                // TODO: Implement screen sharing
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Screen sharing coming soon!')),
                );
              },
              tooltip: 'Share screen',
            ),

          Spacer(),

          // Chat toggle
          _buildControlButton(
            icon: Icons.chat,
            color: Colors.white,
            onPressed: widget.onToggleChat,
            tooltip: 'Toggle chat',
          ),

          SizedBox(width: 16),

          // Participants toggle
          _buildControlButton(
            icon: Icons.people,
            color: Colors.white,
            onPressed: widget.onToggleParticipants,
            tooltip: 'Toggle participants',
          ),

          SizedBox(width: 32),

          // Leave room
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: widget.onLeaveRoom,
            tooltip: 'Leave room',
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
    Color? backgroundColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey[700],
          borderRadius: BorderRadius.circular(24),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
        ),
      ),
    );
  }
}
