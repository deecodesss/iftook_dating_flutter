import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/models/live_stream.dart';
import 'package:iftook/features/live/screens/viewer_screen.dart';
import 'package:iftook/features/wallet/controllers/wallet_controller.dart';
import 'package:iftook/helpers/app_colors.dart';

class LiveStreamCard extends StatelessWidget {
  final LiveStream liveStream;

  const LiveStreamCard({
    Key? key,
    required this.liveStream,
  }) : super(key: key);

  void _handleJoinStream(BuildContext context) async {
    final liveController = Get.find<LiveController>();

    // Check if user already has a subscription first
    final hasActiveSubscription =
        liveController.hasSubscription(liveStream.broadcasterId);

    final streamData = await liveController.joinLiveStream(liveStream.id);

    if (streamData == null) {
      Get.snackbar(
        'Error',
        liveController.errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    // If already subscribed, go directly to viewer screen
    if (hasActiveSubscription) {
      Get.to(() => ViewerScreen(
            liveStreamId: liveStream.id,
            streamData: streamData,
          ));
      return;
    }

    // Check if subscription is required
    if (streamData.containsKey('subscriptionRequired') &&
        streamData['subscriptionRequired'] == true) {
      final walletController = Get.find<WalletController>();
      final hasEnoughBalance = walletController.hasEnoughBalance(
        streamData['subscriptionPrice'].toDouble(),
      );

      final subscribe = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
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
                    'You need to subscribe to ${liveStream.broadcaster?.name ?? 'this creator'} to join this live stream.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Subscription price: ₹${streamData['subscriptionPrice']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!hasEnoughBalance)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Insufficient wallet balance. Please add funds.',
                              style: TextStyle(
                                  color: Colors.red[300], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: hasEnoughBalance
                      ? () => Navigator.pop(context, true)
                      : () {
                          Navigator.pop(context, false);
                          Get.toNamed('/wallet');
                        },
                  child: Text(hasEnoughBalance ? 'Subscribe' : 'Add Funds'),
                ),
              ],
            ),
          ) ??
          false;

      if (subscribe) {
        final success = await liveController.subscribeToCreator(
          streamData['broadcasterId'],
        );

        if (success) {
          // Try joining again after subscribing
          _handleJoinStream(context);
        }
      }

      return;
    }

    // Navigate to viewer screen if no subscription required
    Get.to(() => ViewerScreen(
          liveStreamId: liveStream.id,
          streamData: streamData,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleJoinStream(context),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with info overlay
            Stack(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: liveStream.broadcaster?.photos?.isNotEmpty == true
                        ? Image.network(
                            liveStream.broadcaster!.photos!.first,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.live_tv,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                ),
                // Live badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.fiber_manual_record,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Viewer count
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          liveStream.viewerCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Stream info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    liveStream.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (liveStream.broadcaster?.photos?.isNotEmpty == true)
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(
                            liveStream.broadcaster!.photos!.first,
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey,
                          child:
                              Icon(Icons.person, size: 16, color: Colors.white),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          liveStream.broadcaster?.name ?? 'User',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow,
                                color: AppColors.primaryColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Join',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
