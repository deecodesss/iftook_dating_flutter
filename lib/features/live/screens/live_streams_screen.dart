import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/widgets/live_stream_card.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'dart:convert';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/features/live/screens/viewer_screen.dart';

class LiveStreamsScreen extends StatefulWidget {
  const LiveStreamsScreen({Key? key}) : super(key: key);

  @override
  State<LiveStreamsScreen> createState() => _LiveStreamsScreenState();
}

class _LiveStreamsScreenState extends State<LiveStreamsScreen> {
  final LiveController _liveController = Get.find<LiveController>();
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isLoading = false;
  String _error = '';
  List<Map<String, dynamic>> _liveStreams = [];

  @override
  void initState() {
    super.initState();
    _loadLiveStreams(refresh: true);
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _loadLiveStreams({bool refresh = false}) async {
    try {
      if (refresh) {
        _page = 1;
        _hasMore = true;
        _liveStreams.clear();
      }

      if (!_hasMore || _isLoading) return;

      setState(() => _isLoading = true);

      final response = await ApiService.getActiveLiveStreams(
        page: _page,
        limit: _limit,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Get active live streams response: ${response.body}');

        if (data['success'] == true && data['data'] != null) {
          final liveStreamsData = data['data']['liveStreams'] as List;
          final pagination = data['data']['pagination'];

          // Handle pagination data
          final totalPages = pagination['pages'] as int;
          _hasMore = _page < totalPages;

          // Process live streams
          final newStreams = liveStreamsData
              .map((streamData) {
                try {
                  // Safely extract broadcaster data
                  final broadcaster = streamData['broadcaster'] ?? {};
                  final earnings = broadcaster['earnings'] ??
                      {
                        'chat': 150,
                        'voice': 300,
                        'video': 450,
                        'live': 5,
                        'subscription': 700,
                      };

                  // Create a properly structured live stream object
                  return {
                    'id': streamData['_id']?.toString(),
                    'title':
                        streamData['title']?.toString() ?? 'Untitled Stream',
                    'description': streamData['description']?.toString() ?? '',
                    'status': streamData['status']?.toString() ?? 'inactive',
                    'channelName': streamData['channelName']?.toString() ?? '',
                    'agoraToken': streamData['agoraToken']?.toString() ?? '',
                    'startTime': streamData['startTime']?.toString(),
                    'broadcaster': {
                      'id': broadcaster['_id']?.toString(),
                      'name': broadcaster['name']?.toString() ?? 'Anonymous',
                      'photos':
                          (broadcaster['photos'] as List?)?.cast<String>() ??
                              [],
                      'earnings': {
                        'chat': earnings['chat'] ?? 150,
                        'voice': earnings['voice'] ?? 300,
                        'video': earnings['video'] ?? 450,
                        'live': earnings['live'] ?? 5,
                        'subscription': earnings['subscription'] ?? 700,
                      },
                      'isLive': broadcaster['isLive'] ?? false,
                    },
                    'viewers':
                        (streamData['viewers'] as List?)?.cast<String>() ?? [],
                  };
                } catch (e) {
                  print('Error processing live stream data: $e');
                  return null;
                }
              })
              .whereType<Map<String, dynamic>>()
              .toList();

          setState(() {
            _liveStreams.addAll(newStreams);
            _page++;
            _isLoading = false;
          });
        } else {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load live streams');
      }
    } catch (e) {
      print('Error loading live streams: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadLiveStreams();
    }
  }

  Widget _buildStreamCard(Map<String, dynamic> stream) {
    final broadcaster = stream['broadcaster'] as Map<String, dynamic>;
    final photos = broadcaster['photos'] as List<String>;
    final earnings = broadcaster['earnings'] as Map<String, dynamic>;
    final broadcasterId = broadcaster['id'] ?? '';
    final liveStreamId = stream['id'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _handleJoinStream(stream),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    photos.isNotEmpty ? NetworkImage(photos.first) : null,
                child: photos.isEmpty
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      broadcaster['name'] ?? 'Anonymous',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Live Rate: ₹${earnings['live'] ?? 5}/min',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  if (stream['title'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stream['title'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            // Add description if available
            if (stream['description']?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  stream['description'],
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleJoinStream(Map<String, dynamic> stream) async {
    final broadcasterId = stream['broadcaster']?['id'];
    final liveStreamId = stream['id'];

    if (broadcasterId == null || liveStreamId == null) {
      Get.snackbar(
        'Error',
        'Invalid stream data',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final hasSubscription = _liveController.hasSubscription(broadcasterId);
      final streamData = await _liveController.joinLiveStream(liveStreamId);

      Get.back(); // Close loading dialog

      if (streamData == null) {
        Get.snackbar(
          'Error',
          _liveController.errorMessage.value,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      // If subscription is required and user doesn't have one
      if (streamData['subscriptionRequired'] == true && !hasSubscription) {
        final subscriptionPrice =
            (stream['broadcaster']?['earnings']?['subscription'] ?? 700.0)
                as num;
        final subscribe = await _showSubscriptionDialog(
          stream['broadcaster']?['name'] ?? 'this creator',
          subscriptionPrice.toDouble(),
        );

        if (subscribe) {
          final success =
              await _liveController.subscribeToCreator(broadcasterId);
          if (success) {
            _handleJoinStream(stream);
          }
        }
        return;
      }

      // Navigate directly to ViewerScreen instead of using named route
      Get.to(() => ViewerScreen(
            liveStreamId: liveStreamId,
            streamData: streamData,
          ));
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Failed to join stream: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<bool> _showSubscriptionDialog(String creatorName, double price) async {
    return await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Subscription Required',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You need to subscribe to $creatorName to watch their live streams.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  'Subscription price: ₹${price.toStringAsFixed(0)}/month',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[400])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
                onPressed: () => Get.back(result: true),
                child: const Text('Subscribe'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Streams',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLiveStreams(refresh: true),
          ),
        ],
      ),
      body: _isLoading && _liveStreams.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
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
                        _error,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _loadLiveStreams(refresh: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _liveStreams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.live_tv_outlined,
                            color: Colors.grey[600],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Live Streams',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'There are no live streams right now.\nTry again later or start your own!',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _loadLiveStreams(refresh: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadLiveStreams(refresh: true),
                      color: AppColors.primaryColor,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _liveStreams.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final liveStream = _liveStreams[index];
                          return _buildStreamCard(liveStream);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor,
        onPressed: () {
          Get.toNamed('/profile');
        },
        child: const Icon(Icons.live_tv),
      ),
    );
  }
}
