import 'package:flutter/material.dart';

class CancellationAndRefundPolicyScreen extends StatefulWidget {
  const CancellationAndRefundPolicyScreen({super.key});

  @override
  State<CancellationAndRefundPolicyScreen> createState() =>
      _CancellationAndRefundPolicyScreenState();
}

class _CancellationAndRefundPolicyScreenState
    extends State<CancellationAndRefundPolicyScreen> {
  // Future<void> _launchEmail() async {
  //   final Uri emailLaunchUri = Uri(
  //     scheme: 'mailto',
  //     path: 'support@iftook.com',
  //   );
  //   if (await canLaunchUrl(emailLaunchUri)) {
  //     await launchUrl(emailLaunchUri);
  //   }
  // }

  // Future<void> _launchPhone() async {
  //   final Uri phoneLaunchUri = Uri(
  //     scheme: 'tel',
  //     path: '+917014892480',
  //   );
  //   if (await canLaunchUrl(phoneLaunchUri)) {
  //     await launchUrl(phoneLaunchUri);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cancellation & Refund',
          style: TextStyle(
            // color: Color(0xFFE91E63),
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        // iconTheme: const IconThemeData(color: Color(0xFFE91E63)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroSection(),
            const SizedBox(height: 24),
            _buildPolicySection(
              icon: Icons.calendar_today,
              title: '1. Subscription Cancellation',
              content: '''
You may cancel your subscription to IFTOOK at any time through:

• In-App Cancellation: Navigate to your profile settings → "Subscription" section
• Email Cancellation: Contact support@iftook.com with your account details

Your subscription will continue until the end of the current period with no refunds for unused time.''',
            ),
            _buildPolicySection(
              icon: Icons.money,
              title: '2. Refund Policy',
              content: '''
Refunds are available under these conditions:

• Accidental Subscription: Contact us within 14 days of charge
• Service Dissatisfaction: Must request within 30 days of subscription
• Non-Refundable: Virtual gifts, upgrades, and one-time purchases

Refunds process through original payment method within 7 business days.''',
            ),
            _buildPolicySection(
              icon: Icons.gavel,
              title: '3. Termination by IFTOOK',
              content:
                  'IFTOOK reserves the right to suspend or terminate accounts violating our Terms of Service. No refunds will be provided in such cases.',
            ),
            _buildContactSection(),
            _buildCompanyInfoSection(),
            const SizedBox(height: 20),
            _buildFooterSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
        ),
      ),
      child: const Text(
        'At IFTOOK, we strive to provide a positive experience for all of our users. Please review our cancellation and refund policy below.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.contact_support,
                color: Color(0xFFE91E63),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                '4. Contact Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactButton(
            icon: Icons.email,
            text: 'support@iftook.com',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildContactButton(
            icon: Icons.phone,
            text: '+91 7014892480',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildContactButton(
            icon: Icons.language,
            text: 'www.iftook.com',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE91E63), size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Galook Health Care\n'
            'Plot No C45, C46 Unit No.308, Third Floor Apartment,\n'
            'Road No. 1D, VKI Area, JAIPUR,\n'
            'Rajasthan, 302039',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.verified_user,
              color: Color(0xFFE91E63),
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              "By using IFTOOK's services, you agree to this policy.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2C2C2C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFE91E63),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
