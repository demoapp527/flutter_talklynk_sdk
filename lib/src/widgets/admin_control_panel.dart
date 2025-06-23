import 'package:flutter/material.dart';

import '../models/models.dart';

class AdminControlPanel extends StatelessWidget {
  final TalkLynkRoom room;
  final List<TalkLynkUser> participants;
  final Function(String) onKickParticipant;
  final VoidCallback onMuteAll;
  final Function(String) onTransferAdmin;

  const AdminControlPanel({
    Key? key,
    required this.room,
    required this.participants,
    required this.onKickParticipant,
    required this.onMuteAll,
    required this.onTransferAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Admin Controls',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Mute all button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onMuteAll,
              icon: Icon(Icons.mic_off, size: 16),
              label: Text('Mute All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          SizedBox(height: 8),

          // Transfer admin button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTransferAdminDialog(context),
              icon: Icon(Icons.swap_horiz, size: 16),
              label: Text('Transfer Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          SizedBox(height: 8),

          // Kick participants button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showKickParticipantDialog(context),
              icon: Icon(Icons.person_remove, size: 16),
              label: Text('Kick Participant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferAdminDialog(BuildContext context) {
    final eligibleParticipants =
        participants.where((p) => p.id != room.currentUser.id).toList();

    if (eligibleParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other participants to transfer admin to')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transfer Admin Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a participant to make the new admin:'),
            SizedBox(height: 16),
            ...eligibleParticipants.map((participant) => ListTile(
                  leading: CircleAvatar(
                    child: Text(participant.displayName[0].toUpperCase()),
                  ),
                  title: Text(participant.displayName),
                  subtitle: Text(participant.username),
                  onTap: () {
                    Navigator.of(context).pop();
                    onTransferAdmin(participant.id);
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showKickParticipantDialog(BuildContext context) {
    final kickableParticipants =
        participants.where((p) => p.id != room.currentUser.id).toList();

    if (kickableParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No participants to kick')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kick Participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a participant to kick from the room:'),
            SizedBox(height: 16),
            ...kickableParticipants.map((participant) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Text(participant.displayName[0].toUpperCase()),
                  ),
                  title: Text(participant.displayName),
                  subtitle: Text(participant.username),
                  onTap: () {
                    Navigator.of(context).pop();
                    onKickParticipant(participant.id);
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
