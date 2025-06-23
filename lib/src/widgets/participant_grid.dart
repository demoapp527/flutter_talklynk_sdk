import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/models.dart';

class ParticipantGrid extends StatelessWidget {
  final TalkLynkRoom room;
  final List<TalkLynkUser> participants;

  const ParticipantGrid({
    Key? key,
    required this.room,
    required this.participants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Center(
        child: Text(
          'No participants in room',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _calculateGridColumns(participants.length),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: participants.length + 1, // +1 for local video
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildLocalVideo();
        }

        final participant = participants[index - 1];
        return _buildParticipantVideo(participant);
      },
    );
  }

  int _calculateGridColumns(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  Widget _buildLocalVideo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Stack(
        children: [
          // Local video renderer
          if (room.localRenderer != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RTCVideoView(
                room.localRenderer!,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Center(
              child: Icon(Icons.person, size: 64, color: Colors.white),
            ),

          // Local user info overlay
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${room.currentUser.displayName} (You)',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (room.currentUser.isAdmin) ...[
                    SizedBox(width: 4),
                    Icon(Icons.admin_panel_settings,
                        size: 12, color: Colors.amber),
                  ],
                ],
              ),
            ),
          ),

          // Mute indicators
          if (room.isAudioMuted)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.mic_off, color: Colors.red, size: 20),
            ),
          if (room.isVideoMuted)
            Positioned(
              top: 8,
              left: 8,
              child: Icon(Icons.videocam_off, color: Colors.red, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantVideo(TalkLynkUser participant) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Participant video (placeholder for now)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.blue,
                  child: Text(
                    participant.displayName.isNotEmpty
                        ? participant.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  participant.displayName,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Participant info overlay
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    participant.displayName,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (participant.isAdmin) ...[
                    SizedBox(width: 4),
                    Icon(Icons.admin_panel_settings,
                        size: 12, color: Colors.amber),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
