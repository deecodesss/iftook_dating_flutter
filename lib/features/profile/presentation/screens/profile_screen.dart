import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/widgets/charges_bottom_sheet.dart';
import 'package:iftook/core/widgets/interests_bottom_sheet.dart';
import 'package:iftook/features/about_us/presentation/screens/cancellation_and_refund_policy_screen.dart';
import 'package:iftook/features/about_us/presentation/screens/privacy_policy_screen.dart';
import 'package:iftook/features/about_us/presentation/screens/terms_and_conditions_screen.dart';
import 'package:iftook/features/activity/presentation/screens/activity_screen.dart';
import 'package:iftook/features/profile/controllers/profile_controller.dart'; // Import the ProfileController
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/availability_screen.dart';
import 'package:iftook/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:iftook/features/profile/presentation/screens/my_history_screen.dart';
import 'package:iftook/features/profile/presentation/screens/promote_profile_screen.dart';
import 'package:iftook/features/profile/presentation/screens/support_screen.dart';
import 'package:iftook/features/profile/presentation/screens/view_reviews_screen.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:iftook/helpers/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  final ProfileController _profileController = Get.put(ProfileController());

  ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Obx(() {
        if (_profileController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_profileController.errorMessage.isNotEmpty) {
          return Center(
            child: Text(
              _profileController.errorMessage.value,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final user = _profileController.user.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileHeader(user),
            const SizedBox(height: 24),
            _buildSection(
              'Streaming',
              [
                _buildProfileOption(
                  icon: Icons.live_tv,
                  title: 'Go Live',
                  onTap: () {},
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildSection(
              'Account',
              [
                _buildProfileOption(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'My Wallet',
                  onTap: () {
                    Get.to(() => const WalletScreen());
                  },
                  trailing: Text(
                    '₹${user.walletBalance ?? '0'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildProfileOption(
                  icon: Icons.history,
                  title: 'My Activity',
                  onTap: () {
                    Get.to(() => const ActivityScreen(
                          isCurrentUser: true,
                        ));
                  },
                ),
                _buildProfileOption(
                  icon: Icons.interests_outlined,
                  title: 'My Interests',
                  onTap: () {
                    showInterestsBottomSheet(context);
                  },
                ),
                _buildProfileOption(
                  icon: Icons.access_time,
                  title: 'My Availability',
                  onTap: () {
                    Get.to(() => const AvailabilityScreen());
                  },
                ),
                _buildProfileOption(
                  icon: Icons.manage_history_outlined,
                  title: 'My History',
                  onTap: () {
                    Get.to(() => const HistoryScreen());
                  },
                ),
              ],
            ),
            _buildSection(
              'Monetization',
              [
                _buildProfileOption(
                  icon: Icons.campaign_outlined,
                  title: 'Promote My Profile',
                  onTap: () {
                    Get.to(() => const PromoteProfileScreen());
                  },
                  iconColor: AppColors.highlightColor,
                ),
                _buildProfileOption(
                  icon: Icons.payments_outlined,
                  title: 'My Earnings',
                  onTap: () {
                    showPriceBottomSheet(context);
                  },
                  iconColor: AppColors.highlightColor,
                ),
              ],
            ),
            _buildSection(
              'Support & Feedback',
              [
                _buildProfileOption(
                  icon: Icons.support_agent_outlined,
                  title: 'Support',
                  onTap: () {
                    Get.to(() => SupportScreen());
                  },
                  iconColor: AppColors.greenColor,
                ),
                _buildProfileOption(
                  icon: Icons.star_outline,
                  title: 'Rating & Review',
                  onTap: () {
                    Get.to(() => ViewReviewsScreen());
                  },
                  iconColor: AppColors.greenColor,
                ),
                _buildProfileOption(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: _profileController.logout,
                  iconColor: AppColors.greenColor,
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentColor, width: 0.5),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(
                user.photos?.isNotEmpty == true
                    ? user.photos!.first
                    : 'https://via.placeholder.com/150',
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? 'User Name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '@username',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'Edit Profile':
                  Get.to(() => EditProfileScreen());
                  break;
                case 'Cancellation & Refund Policy':
                  Get.to(() => CancellationAndRefundPolicyScreen());
                  break;
                case 'Privacy Policy':
                  Get.to(() => PrivacyPolicyScreen());
                  break;
                case 'Terms & Conditions':
                  Get.to(() => TermsAndConditionsScreen());
                  break;
              }
            },
            icon: const Icon(Icons.more_vert, color: AppColors.primaryColor),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Edit Profile',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 15),
                    SizedBox(width: 4),
                    Text('Edit Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Cancellation & Refund Policy',
                child: Row(
                  children: [
                    Icon(Icons.policy, size: 15),
                    SizedBox(width: 4),
                    Text('Cancellation & Refund Policy'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Privacy Policy',
                child: Row(
                  children: [
                    Icon(Icons.security, size: 15),
                    SizedBox(width: 4),
                    Text('Privacy Policy'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Terms & Conditions',
                child: Row(
                  children: [
                    Icon(Icons.description, size: 15),
                    SizedBox(width: 4),
                    Text('Terms & Conditions'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.primaryColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.white.withOpacity(0.5),
            size: 16,
          ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
