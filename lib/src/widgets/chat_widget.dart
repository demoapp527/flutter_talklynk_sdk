import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class ChatWidget extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;
  final Function(String)? onSendFile;
  final Function(bool)? onTypingChanged;
  final User? currentUser;
  final String? roomId;
  final bool isLoading;

  const ChatWidget({
    Key? key,
    required this.messages,
    required this.onSendMessage,
    this.onSendFile,
    this.onTypingChanged,
    this.currentUser,
    this.roomId,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    if (isCurrentlyTyping != _isTyping) {
      _isTyping = isCurrentlyTyping;
      widget.onTypingChanged?.call(_isTyping);
    }
  }

  @override
  void didUpdateWidget(ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll to bottom when new messages arrive
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message);
      _messageController.clear();
      // Clear typing indicator
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingChanged?.call(false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null && widget.onSendFile != null) {
        widget.onSendFile!(image.path);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false, // Don't load file data into memory
      );

      if (result != null &&
          result.files.isNotEmpty &&
          widget.onSendFile != null) {
        final file = result.files.first;
        if (file.path != null) {
          widget.onSendFile!(file.path!);
        }
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : widget.messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(widget.messages[index]);
                      },
                    ),
        ),

        // Message input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isOwnMessage = message.user.id == widget.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwnMessage) ...[
            _buildAvatar(message.user),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isOwnMessage ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Text(
                      message.user.name!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  _buildMessageContent(message, isOwnMessage),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isOwnMessage ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            _buildAvatar(message.user, isOwn: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(User user, {bool isOwn = false}) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isOwn ? Colors.blue : Colors.grey.shade300,
      backgroundImage:
          user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
      child: user.avatarUrl == null
          ? Text(
              user.name![0].toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isOwn ? Colors.white : Colors.black,
              ),
            )
          : null,
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isOwnMessage) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 16,
            color: isOwnMessage ? Colors.white : Colors.black87,
          ),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.metadata?['file_path'] != null) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getFileUrl(message.metadata!['file_path']),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.broken_image, size: 48),
                          const Text('Failed to load image'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (message.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isOwnMessage ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ] else
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 16,
                  color: isOwnMessage ? Colors.white : Colors.black87,
                ),
              ),
          ],
        );

      case MessageType.file:
        return GestureDetector(
          onTap: () => _downloadFile(message),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOwnMessage
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFileIcon(message.metadata?['file_type']),
                  color: isOwnMessage ? Colors.white : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.metadata?['original_name'] ?? 'File',
                        style: TextStyle(
                          fontSize: 14,
                          color: isOwnMessage ? Colors.white : Colors.black87,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      if (message.metadata?['file_size'] != null)
                        Text(
                          _formatFileSize(message.metadata!['file_size']),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOwnMessage
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 16,
            color: isOwnMessage ? Colors.white : Colors.black87,
          ),
        );
    }
  }

  String _getFileUrl(String filePath) {
    // Construct the full URL for the file
    if (filePath.startsWith('http')) {
      return filePath;
    }
    // Assuming your Laravel app serves files from storage/public
    return 'https://api.talklynk.com/storage/$filePath';
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.attach_file;

    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document'))
      return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet'))
      return Icons.table_chart;
    if (mimeType.contains('zip') || mimeType.contains('rar'))
      return Icons.archive;

    return Icons.attach_file;
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';

    final bytes = size is String ? int.tryParse(size) ?? 0 : size as int;

    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _downloadFile(ChatMessage message) {
    // Implement file download logic
    final filePath = message.metadata?['file_path'];
    if (filePath != null) {
      // You can implement file download here
      _showError('File download not implemented yet');
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed:
                widget.currentUser != null ? _showAttachmentOptions : null,
            icon: const Icon(Icons.attach_file),
            color: Colors.grey.shade600,
          ),

          // Message input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                enabled: widget.currentUser != null,
                decoration: InputDecoration(
                  hintText: widget.currentUser != null
                      ? 'Type a message...'
                      : 'Set current user to send messages',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: widget.currentUser != null ? _sendMessage : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.currentUser != null ? Colors.blue : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.green),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
