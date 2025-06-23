import 'package:flutter/material.dart';

import '../models/models.dart';

class ChatWidget extends StatefulWidget {
  final TalkLynkRoom room;
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;

  const ChatWidget({
    Key? key,
    required this.room,
    required this.messages,
    required this.onSendMessage,
  }) : super(key: key);

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(left: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Chat',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '${widget.messages.length} messages',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isOwn = message.senderId == widget.room.currentUser.id;
                return _buildMessageBubble(message, isOwn);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Someone is typing...',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ),

          // Message input
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[700]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: _onMessageChanged,
                    onSubmitted: _sendMessage,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: () => _sendMessage(_messageController.text),
                  icon: Icon(Icons.send, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isOwn) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: isOwn ? Colors.blue : Colors.grey[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOwn)
              Text(
                message.senderName,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              message.message,
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _onMessageChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.room.sendTypingIndicator(true);
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      widget.room.sendTypingIndicator(false);
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isNotEmpty) {
      widget.onSendMessage(text.trim());
      _messageController.clear();
      _isTyping = false;
      widget.room.sendTypingIndicator(false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
