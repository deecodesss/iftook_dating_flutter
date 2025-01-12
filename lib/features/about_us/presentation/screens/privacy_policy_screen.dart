import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/helpers/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Privacy Policy',
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
              _buildSectionTitle('Introduction'),
              _buildParagraph(
                'Welcome to the Privacy Policy for IFTOOK, operated by Galook Health Care ("IFTOOK," "we," "us," or "our"). This Privacy Policy outlines how we collect, use, share, and protect your personal information when you use our dating application ("App").',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Information We Collect'),
              _buildBulletPoints([
                'Personal Information: Name, email address, date of birth, gender, photographs, and any other information you provide to create your profile.',
                'Usage Information: Information about how you use our App, such as your interactions with other users, messages exchanged, and preferences.',
                'Device Information: Device identifiers, IP address, browser type, and language settings.',
                "Location Information: Your approximate location derived from your IP address or mobile device's GPS.",
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('How We Use Your Information'),
              _buildParagraph(
                  "We use the information we collect for the following purposes:"),
              const SizedBox(height: 8),
              _buildBulletPoints(
                [
                  "To provide and improve our services, including matchmaking and user support.",
                  "To communicate with you, including sending notifications and updates about the App.",
                  "To personalize your experience and optimize our App's performance.",
                  "To prevent fraud and enforce our terms of service."
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Sharing your information'),
              _buildParagraph(
                'We may share your information in the following circumstances:',
              ),
              const SizedBox(height: 8),
              _buildBulletPoints(
                [
                  "With other users as part of our matchmaking services.",
                  "With service providers who assist us in operating the App and providing services.",
                  "With law enforcement or legal authorities if required by law or to protect our rights.",
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Data Security'),
              _buildParagraph(
                'We implement appropriate technical and organizational measures to protect your personal information from unauthorized access, disclosure, alteration, or destruction.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Your Choices'),
              _buildParagraph(
                "You can access, update, or delete your profile information through the App's settings. You may also unsubscribe from promotional communications.",
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Children's Privacy"),
              _buildParagraph(
                'Our App is not intended for users under the age of 18. We do not knowingly collect personal information from children under 18.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Changes to This Privacy Policy"),
              _buildParagraph(
                'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Contact Us'),
              _buildParagraph(
                'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us at [insert contact information].',
              ),
              const SizedBox(height: 8),
              _buildContactInfo(),
              const SizedBox(height: 8),
              _buildParagraph(
                'By using our App, you consent to the collection and use of your information as described in this Privacy Policy.',
              ),
              const SizedBox(height: 24),
              _buildLastUpdated(),
              const SizedBox(height: 40),
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

  Widget _buildBulletPoints(List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points.map((point) {
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
                  point,
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
      }).toList(),
    );
  }

  Widget _buildContactInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactItem(
            Icons.email,
            'Email: support@iftook.com',
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            Icons.phone,
            'Phone: +91 7014892480',
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 20),
        const SizedBox(width: 12),
        SizedBox(
          width: MediaQuery.of(Get.context!).size.width * 0.7,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, color: Colors.grey, size: 16),
          SizedBox(width: 8),
          Text(
            'Effective date: January 11, 2025',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
