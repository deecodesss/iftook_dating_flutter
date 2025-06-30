import 'package:flutter/material.dart';
import 'package:iftook/helpers/app_colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParagraph(
                  "Welcome to IFTOOK, a dating platform operated by Galook Health Care (“we,” “us,” or “our”). By accessing or using the IFTOOK platform (the “Service”), you agree to comply with and be bound by these Terms and Conditions. Please read them carefully. If you do not agree to these Terms, you may not use the Service."),
              const SizedBox(height: 24),
              _buildSectionTitle('1. Acceptance of Terms'),
              _buildParagraph(
                'By using the IFTOOK app or website, you agree to be bound by these Terms and Conditions, our Privacy Policy, and any other policies or guidelines incorporated by reference. We may update these terms from time to time, and your continued use of the Service after such changes will constitute your acceptance of the revised terms.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('2. Eligibility'),
              _buildParagraph(
                'You must be at least 18 years old to use IFTOOK. By using this Service, you affirm that you are at least 18 years of age and have the legal capacity to enter into a binding contract. You also agree to provide accurate, current, and complete information during registration and to update such information if necessary.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('3. Account Registration'),
              _buildParagraph(
                'To use the Service, you must create an account by providing a valid email address, username, and other necessary personal information. You agree to maintain the confidentiality of your account and are solely responsible for all activities that occur under your account.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('4. User Conduct'),
              _buildParagraph("When using IFTOOK, you agree not to:"),
              const SizedBox(height: 8),
              _buildSubsection([
                'Violate any applicable local, state, national, or international law or regulation.',
                'Harass, abuse, or harm other users or engage in any activity that may harm or disrupt the Service or others.',
                'Impersonate another person or entity, or falsify your identity.',
                'Use the Service for any unlawful, fraudulent, or malicious activity.',
                'Share content that is offensive, harmful, discriminatory, or violates the rights of others.',
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('5. Privacy and Data Collection'),
              _buildParagraph(
                'By using IFTOOK, you agree to the collection, use, and disclosure of your personal data in accordance with our Privacy Policy. We may collect information such as your profile data, activity on the platform, and other data necessary for improving the Service and your experience.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('6. User-Generated Content'),
              _buildParagraph(
                'You are responsible for the content you post, share, or transmit through the Service, including profile pictures, bios, and messages. By posting content on IFTOOK, you grant us a non-exclusive, worldwide, royalty-free license to use, modify, and display such content in connection with the service.',
              ),
              _buildParagraph(
                  "You agree not to upload or transmit content that:"),
              const SizedBox(height: 8),
              _buildSubsection([
                'Is misleading, offensive, or discriminatory.',
                'Violates the intellectual property rights of others.',
                'Is explicit or inappropriate.',
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('7. Safety and Security'),
              _buildParagraph(
                'We are committed to fostering a safe and respectful environment for all users. However, you are solely responsible for your interactions with other users. We encourage you to take reasonable precautions when meeting new people, both online and offline.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('8. Subscriptions and Fees'),
              _buildParagraph(
                'IFTOOK may offer paid services, including but not limited to premium memberships or subscription plans. You agree to pay all applicable fees associated with your use of the Service. Payment terms, including pricing, will be clearly provided at the point of purchase. Subscription fees are non-refundable, except where required by law.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('9. Termination and Account Suspension'),
              _buildParagraph(
                'We reserve the right to suspend or terminate your account at our discretion if we believe you have violated these Terms and Conditions. You may also terminate your account at any time by following the account deletion procedure in the app. Upon termination, all rights and access to the Service will cease.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('10. Intellectual Property'),
              _buildParagraph(
                'All intellectual property rights in the Service, including trademarks, logos, and content, are owned by Galook Health Care or its licensors. You may not use, modify, or distribute any content from the Service without prior written permission from us.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('11. Disclaimers and Limitation of Liability'),
              _buildParagraph(
                'The Service is provided "as is" and "as available." We make no warranties or representations regarding the accuracy, reliability, or availability of the Service. We do not guarantee that the Service will be uninterrupted or free of errors.',
              ),
              const SizedBox(height: 8),
              _buildParagraph(
                'To the fullest extent permitted by law, Galook Health Care is not liable for any indirect, incidental, special, or consequential damages arising from your use of the Service.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('12. Indemnification'),
              _buildParagraph(
                'You agree to indemnify, defend, and hold harmless Galook Health Care, its officers, employees, and agents from any and all claims, losses, damages, liabilities, or expenses arising out of your use of the Service or any breach of these Terms and Conditions.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('13. Governing Law'),
              _buildParagraph(
                'These Terms and Conditions shall be governed by and construed in accordance with the laws of the jurisdiction in which Galook Health Care is located, without regard to its conflict of law principles.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('14. Dispute Resolution'),
              _buildParagraph(
                'In the event of any dispute, controversy, or claim arising out of or in connection with these Terms and Conditions, you agree to resolve the dispute through binding arbitration, rather than in court, in accordance with the rules of the jurisdiction where Galook Health Care is located.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('15. Changes to Terms'),
              _buildParagraph(
                'Galook Health Care reserves the right to update or modify these Terms and Conditions at any time. Any changes will be posted on this page, and you are encouraged to review them regularly. Continued use of the Service after such changes constitutes your acceptance of the new terms.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('16. Contact Information'),
              _buildContactBox(),
              const SizedBox(height: 24),
              _buildLastUpdated(),
              const SizedBox(height: 40),
              _buildParagraph(
                  "By using the IFTOOK app, you acknowledge that you have read, understood, and agree to abide by these Terms and Conditions.")
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 16,
        height: 1.5,
      ),
    );
  }

  Widget _buildSubsection(List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points.map((point) => _buildBulletPoint(point)).toList(),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Contact Us:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Email: support@iftook.com\nPhone: +91 7014892480',
          style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildLastUpdated() {
    return const Text(
      'Last Updated: January 11, 2025',
      style: TextStyle(
        color: Colors.grey,
        fontSize: 16,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
