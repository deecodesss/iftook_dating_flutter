import 'package:flutter/material.dart';
import 'package:iftook/helpers/app_colors.dart';

class HistoryItem {
  final String name;
  final String imageUrl;
  final String type; // 'voice', 'video', 'chat'
  final String duration;
  final String timestamp;
  final double amount;

  HistoryItem({
    required this.name,
    required this.imageUrl,
    required this.type,
    required this.duration,
    required this.timestamp,
    required this.amount,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<HistoryItem> historyItems = [
    HistoryItem(
      name: 'Sarah Parker',
      imageUrl: 'https://images.unsplash.com/photo-1535324492437-d8dea70a38a7',
      type: 'video',
      duration: '45:20',
      timestamp: '2 hours ago',
      amount: 450,
    ),
    HistoryItem(
      name: 'John Doe',
      imageUrl: 'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43',
      type: 'voice',
      duration: '15:30',
      timestamp: 'Yesterday',
      amount: 300,
    ),
    HistoryItem(
      name: 'Emma Wilson',
      imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
      type: 'chat',
      duration: '30:00',
      timestamp: '2 days ago',
      amount: 250,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Icon _getTypeIcon(String type) {
    switch (type) {
      case 'voice':
        return const Icon(Icons.phone_outlined, color: Colors.green, size: 20);
      case 'video':
        return const Icon(Icons.videocam_outlined,
            color: AppColors.primaryColor, size: 20);
      case 'chat':
        return const Icon(Icons.chat_outlined, color: Colors.orange, size: 20);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey, size: 20);
    }
  }

  Widget _buildHistoryCard(HistoryItem item) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(item.imageUrl),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _getTypeIcon(item.type),
                      const SizedBox(width: 8),
                      Text(
                        item.duration,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.timestamp,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '₹${item.amount}',
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Calls'),
            Tab(text: 'Video'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: historyItems.length,
            itemBuilder: (context, index) =>
                _buildHistoryCard(historyItems[index]),
          ),
          // Calls Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                historyItems.where((item) => item.type == 'voice').length,
            itemBuilder: (context, index) => _buildHistoryCard(
              historyItems
                  .where((item) => item.type == 'voice')
                  .toList()[index],
            ),
          ),
          // Video Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                historyItems.where((item) => item.type == 'video').length,
            itemBuilder: (context, index) => _buildHistoryCard(
              historyItems
                  .where((item) => item.type == 'video')
                  .toList()[index],
            ),
          ),
          // Chat Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: historyItems.where((item) => item.type == 'chat').length,
            itemBuilder: (context, index) => _buildHistoryCard(
              historyItems.where((item) => item.type == 'chat').toList()[index],
            ),
          ),
        ],
      ),
    );
  }
}
