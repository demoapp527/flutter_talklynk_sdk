// lib/src/widgets/video_call_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallWidget extends StatefulWidget {
  final MediaStream? localStream;
  final Map<int, MediaStream> remoteStreams;
  final VoidCallback? onEndCall;
  final VoidCallback? onToggleAudio;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onSwitchCamera;
  final bool isAudioEnabled;
  final bool isVideoEnabled;

  const VideoCallWidget({
    Key? key,
    this.localStream,
    this.remoteStreams = const {},
    this.onEndCall,
    this.onToggleAudio,
    this.onToggleVideo,
    this.onSwitchCamera,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
  }) : super(key: key);

  @override
  State<VideoCallWidget> createState() => _VideoCallWidgetState();
}

class _VideoCallWidgetState extends State<VideoCallWidget> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();

    // Initialize local stream
    if (widget.localStream != null) {
      _localRenderer.srcObject = widget.localStream;
    }
  }

  @override
  void didUpdateWidget(VideoCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update local stream
    if (widget.localStream != oldWidget.localStream) {
      _localRenderer.srcObject = widget.localStream;
    }

    // Update remote streams
    _updateRemoteStreams();
  }

  void _updateRemoteStreams() async {
    // Remove renderers for streams that are no longer present
    final currentUserIds = Set<int>.from(_remoteRenderers.keys);
    final newUserIds = Set<int>.from(widget.remoteStreams.keys);

    for (final userId in currentUserIds) {
      if (!newUserIds.contains(userId)) {
        final renderer = _remoteRenderers.remove(userId);
        renderer?.dispose();
      }
    }

    // Add renderers for new streams
    for (final userId in newUserIds) {
      if (!_remoteRenderers.containsKey(userId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = widget.remoteStreams[userId];
        _remoteRenderers[userId] = renderer;
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Remote videos grid
          _buildRemoteVideosGrid(),

          // Local video (Picture-in-Picture)
          Positioned(
            top: 50,
            right: 20,
            child: _buildLocalVideo(),
          ),

          // Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideosGrid() {
    if (_remoteRenderers.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    final remoteRendererList = _remoteRenderers.values.toList();

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridCrossAxisCount(remoteRendererList.length),
        childAspectRatio: 16 / 9,
      ),
      itemCount: remoteRendererList.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: RTCVideoView(
              remoteRendererList[index],
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalVideo() {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: widget.localStream != null
            ? RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : Container(
                color: Colors.grey.shade800,
                child: const Icon(
                  Icons.videocam_off,
                  color: Colors.white,
                  size: 40,
                ),
              ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Toggle Audio
          _buildControlButton(
            icon: widget.isAudioEnabled ? Icons.mic : Icons.mic_off,
            onPressed: widget.onToggleAudio,
            backgroundColor:
                widget.isAudioEnabled ? Colors.grey.shade700 : Colors.red,
          ),

          // Toggle Video
          _buildControlButton(
            icon: widget.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            onPressed: widget.onToggleVideo,
            backgroundColor:
                widget.isVideoEnabled ? Colors.grey.shade700 : Colors.red,
          ),

          // Switch Camera
          _buildControlButton(
            icon: Icons.switch_camera,
            onPressed: widget.onSwitchCamera,
            backgroundColor: Colors.grey.shade700,
          ),

          // End Call
          _buildControlButton(
            icon: Icons.call_end,
            onPressed: widget.onEndCall,
            backgroundColor: Colors.red,
            size: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  int _getGridCrossAxisCount(int participantCount) {
    if (participantCount <= 1) return 1;
    if (participantCount <= 4) return 2;
    if (participantCount <= 9) return 3;
    return 4;
  }
}
