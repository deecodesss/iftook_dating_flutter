import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/widgets/live_info_widget.dart';
import 'package:iftook/features/wallet/controllers/wallet_controller.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/helpers/constant.dart';
import 'package:iftook/features/live/widgets/agora_live_chat_widget.dart';

class ViewerScreen extends StatefulWidget {
  final String liveStreamId;
  final Map<String, dynamic> streamData;

  const ViewerScreen({
    Key? key,
    required this.liveStreamId,
    required this.streamData,
  }) : super(key: key);

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final LiveController _liveController = Get.find<LiveController>();
  late final WalletController _walletController;

  final RtcEngine _engine = createAgoraRtcEngine();
  bool _isInitialized = false;
  bool _isLoading = true;
  String _errorMessage = '';
  int _viewerCount = 0;
  double _tipAmount = 50.0;
  final List<double> _tipOptions = [50.0, 100.0, 200.0, 500.0, 1000.0];
  int _remoteUid = 0; // Add this variable to track the broadcaster's UID

  @override
  void initState() {
    super.initState();
    // Initialize WalletController if not already initialized
    if (!Get.isRegistered<WalletController>()) {
      Get.put(WalletController());
    }
    _walletController = Get.find<WalletController>();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    setState(() => _isLoading = true);

    try {
      // Initialize Agora engine
      await _engine.initialize(RtcEngineContext(
        appId: Constants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Setup event handlers
      _engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print("Viewer joined channel ${connection.channelId}");
          setState(() => _isInitialized = true);
        },
        onUserJoined: (connection, uid, elapsed) {
          print("User joined: $uid");
          // When broadcaster joins (traditionally has UID 0 but we might receive a different UID)
          setState(() {
            _viewerCount++;
            _remoteUid = uid; // Store the broadcaster's UID
            _isInitialized = true;
          });
        },
        onUserOffline: (connection, uid, reason) {
          print("User left: $uid");
          if (uid == _remoteUid) {
            // Broadcaster left
            _showBroadcasterLeftDialog();
          } else {
            setState(
                () => _viewerCount = _viewerCount > 0 ? _viewerCount - 1 : 0);
          }
        },
        onError: (err, msg) {
          print("Error: $err - $msg");
          setState(() => _errorMessage = 'Error: $msg');
        },
      ));

      // Set viewer role
      await _engine.setClientRole(
        role: ClientRoleType.clientRoleAudience,
      );

      // Join channel with token
      await _engine.joinChannel(
        token: widget.streamData['token'],
        channelId: widget.streamData['channelName'],
        uid: widget.streamData['uid'],
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize: $e');
      print("Error initializing Agora: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showBroadcasterLeftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Stream Ended',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The broadcaster has ended the live stream.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _leaveLiveStream();
    super.dispose();
  }

  Future<void> _leaveLiveStream() async {
    try {
      await _liveController.leaveLiveStream(widget.liveStreamId);
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      print("Error leaving stream: $e");
    }
  }

  void _showTipDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send a Tip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Show your appreciation by sending a tip!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: _tipOptions
                    .map((amount) => ChoiceChip(
                          label: Text('₹${amount.toInt()}'),
                          selected: _tipAmount == amount,
                          onSelected: (selected) {
                            setState(() => _tipAmount = amount);
                          },
                          backgroundColor: Colors.grey[800],
                          selectedColor: AppColors.primaryColor,
                          labelStyle: TextStyle(
                            color: _tipAmount == amount
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final broadcaster = widget.streamData['broadcaster'];
                    if (broadcaster != null && broadcaster['id'] != null) {
                      await _walletController.sendTip(
                        broadcaster['id'],
                        _tipAmount,
                      );
                    }
                  },
                  child: const Text(
                    'Send Tip',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveLiveStream();
        return true;
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Get.back(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      // Video view - updated to handle remote UID properly
                      _isInitialized && _remoteUid != 0
                          ? AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: _engine,
                                canvas: VideoCanvas(
                                    uid: _remoteUid), // Use the remote UID
                                connection: RtcConnection(
                                  channelId: widget.streamData['channelName'],
                                ),
                                useFlutterTexture: true,
                                useAndroidSurfaceView: true,
                              ),
                            )
                          : Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Waiting for broadcaster...',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                      // Overlay controls
                      SafeArea(
                        child: Column(
                          children: [
                            // Top bar with broadcaster info
                            LiveInfoWidget(
                              title: widget.streamData['broadcaster']['name'] ??
                                  'Live Stream',
                              viewerCount: _viewerCount,
                              isLive: true,
                            ),

                            const Spacer(),

                            // Chat area
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: AgoraLiveChatWidget(
                                liveStreamId: widget.liveStreamId,
                                channelName: widget.streamData['channelName'],
                                engine: _engine, // Pass the engine reference
                              ),
                            ),

                            // Bottom controls
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildControlButton(
                                    icon: Icons.favorite,
                                    label: 'Tip',
                                    onPressed: _showTipDialog,
                                    color: Colors.pink,
                                  ),
                                  _buildControlButton(
                                    icon: Icons.close,
                                    label: 'Leave',
                                    onPressed: () async {
                                      await _leaveLiveStream();
                                      Get.back();
                                    },
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = AppColors.primaryColor,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
