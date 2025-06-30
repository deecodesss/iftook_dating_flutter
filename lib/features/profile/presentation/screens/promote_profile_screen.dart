import 'package:flutter/material.dart';
import 'package:iftook/helpers/app_colors.dart';

class PromoteProfileScreen extends StatelessWidget {
  const PromoteProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Promote Profile'),
          backgroundColor: AppColors.primaryColor,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Boost Your Visibility',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose a promotion package that suits your needs',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _PromotionPackageCard(
                      title: 'Basic Boost',
                      price: '₹1,500',
                      features: const [
                        'Profile shown to 500 people',
                        'Featured for 24 hours',
                        'Basic analytics',
                      ],
                      reachCount: '500',
                      duration: '24 hours',
                      color: Colors.blue,
                      onTap: () {
                        // Handle basic boost selection
                      },
                    ),
                    const SizedBox(height: 16),
                    _PromotionPackageCard(
                      title: 'Premium Boost',
                      price: '₹3,000',
                      features: const [
                        'Profile shown to 1,200 people',
                        'Featured for 72 hours',
                        'Detailed analytics',
                        'Priority in search results',
                      ],
                      reachCount: '1.2K',
                      duration: '72 hours',
                      color: Colors.purple,
                      isPopular: true,
                      onTap: () {
                        // Handle premium boost selection
                      },
                    ),
                    const SizedBox(height: 16),
                    _PromotionPackageCard(
                      title: 'Ultra Boost',
                      price: '₹5,000',
                      features: const [
                        'Profile shown to 2,500 people',
                        'Featured for 7 days',
                        'Advanced analytics',
                        'Priority in search results',
                        'Profile highlight effect',
                      ],
                      reachCount: '2.5K',
                      duration: '7 days',
                      color: Colors.teal,
                      onTap: () {
                        // Handle ultra boost selection
                      },
                    ),
                    const SizedBox(height: 20),
                    const _InfoCard(
                      title: 'Why Promote?',
                      items: [
                        'Increase your profile visibility',
                        'Get more profile views and interactions',
                        'Improve your chances of finding matches',
                        'Stand out from other profiles',
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionPackageCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final String reachCount;
  final String duration;
  final Color color;
  final bool isPopular;
  final VoidCallback onTap;

  const _PromotionPackageCard({
    required this.title,
    required this.price,
    required this.features,
    required this.reachCount,
    required this.duration,
    required this.color,
    this.isPopular = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPopular ? AppColors.primaryColor : Colors.transparent,
          width: isPopular ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPopular)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'MOST POPULAR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MetricBox(
                    icon: Icons.people,
                    value: reachCount,
                    label: 'Reach',
                    color: color,
                  ),
                  const SizedBox(width: 16),
                  _MetricBox(
                    icon: Icons.timer,
                    value: duration,
                    label: 'Duration',
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          feature,
                          style: TextStyle(
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Select Package',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _InfoCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
