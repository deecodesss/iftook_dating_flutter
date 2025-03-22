import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/widgets/live_stream_card.dart';
import 'package:iftook/helpers/app_colors.dart';

class LiveStreamsScreen extends StatefulWidget {
  const LiveStreamsScreen({Key? key}) : super(key: key);

  @override
  State<LiveStreamsScreen> createState() => _LiveStreamsScreenState();
}

class _LiveStreamsScreenState extends State<LiveStreamsScreen> {
  final LiveController _liveController = Get.find<LiveController>();
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshStreams();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _refreshStreams() async {
    setState(() => _isRefreshing = true);
    await _liveController.fetchActiveLiveStreams();
    setState(() => _isRefreshing = false);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Load more streams when scrolled to bottom
      // This would require pagination support in the controller
    }
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
            onPressed: _refreshStreams,
          ),
        ],
      ),
      body: Obx(() {
        if (_liveController.isLoading.value && !_isRefreshing) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_liveController.errorMessage.isNotEmpty) {
          return Center(
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
                  _liveController.errorMessage.value,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _refreshStreams,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (_liveController.activeStreams.isEmpty) {
          return Center(
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
                  onPressed: _refreshStreams,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshStreams,
          color: AppColors.primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _liveController.activeStreams.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final liveStream = _liveController.activeStreams[index];
              return LiveStreamCard(liveStream: liveStream);
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor,
        onPressed: () {
          // Go to profile screen to use the "Go Live" button
          Get.toNamed('/profile');
        },
        child: const Icon(Icons.live_tv),
      ),
    );
  }
}
