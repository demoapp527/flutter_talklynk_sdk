import 'package:flutter/material.dart';

import '../models/models.dart';

class ParticipantList extends StatelessWidget {
  final List<TalkLynkUser> participants;
  final TalkLynkUser currentUser;
  final Function(String)? onKickParticipant;

  const ParticipantList({
    Key? key,
    required this.participants,
    required this.currentUser,
    this.onKickParticipant,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Participants (${participants.length})',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Participants list
          Expanded(
            child: ListView.builder(
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                final isCurrentUser = participant.id == currentUser.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        participant.isAdmin ? Colors.amber : Colors.blue,
                    child: Text(
                      participant.displayName.isNotEmpty
                          ? participant.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '${participant.displayName}${isCurrentUser ? ' (You)' : ''}',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        participant.username,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      if (participant.isAdmin) ...[
                        SizedBox(width: 8),
                        Icon(Icons.admin_panel_settings,
                            size: 14, color: Colors.amber),
                        Text(' Admin',
                            style:
                                TextStyle(color: Colors.amber, fontSize: 12)),
                      ],
                      if (!participant.isOnline) ...[
                        SizedBox(width: 8),
                        Icon(Icons.offline_bolt, size: 14, color: Colors.red),
                        Text(' Offline',
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ],
                  ),
                  trailing: !isCurrentUser && onKickParticipant != null
                      ? IconButton(
                          onPressed: () => _confirmKick(context, participant),
                          icon: Icon(Icons.person_remove, color: Colors.red),
                          tooltip: 'Kick participant',
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmKick(BuildContext context, TalkLynkUser participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kick Participant'),
        content: Text(
            'Are you sure you want to kick ${participant.displayName} from the room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onKickParticipant!(participant.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Kick'),
          ),
        ],
      ),
    );
  }
}
