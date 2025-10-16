// lib/pages/evuser/faq_page.dart
import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Getting Started'),
          _buildFaqItem(
            'How do I set up my vehicle profile?',
            'After registering, you will be prompted to select your EV\'s brand and model. You can also set a custom battery level for low-battery alerts. This helps us provide more accurate recommendations.',
          ),
          _buildFaqItem(
            'Why do you need my location?',
            'We use your live location to find the nearest charging stations, calculate distances, and provide real-time navigation. Your location data is not shared with third parties.',
          ),

          _buildSectionHeader(context, 'Charging & Stations'),
          _buildFaqItem(
            'How does the AI Recommendation work?',
            'Our AI analyzes your current battery level, your vehicle type, and the real-time status of nearby stations (distance, available slots, charger speed) to recommend the top 3 most suitable options for you.',
          ),
          _buildFaqItem(
            'What do the different colors on the map mean?',
            'Green station icons indicate that there are available charging slots. Orange or Red icons may indicate that the station is full or temporarily inactive.',
          ),
          _buildFaqItem(
            'How do I start a charging session?',
            'Once you arrive at the station using our navigation, the app will guide you. Typically, you will need to scan a QR code on the charger or select the charger ID within the app to begin.',
          ),

          _buildSectionHeader(context, 'Account'),
          _buildFaqItem(
            'How can I change my password?',
            'You can change your password by going to your Profile page and selecting the "Change Password" option. You can also use the "Forgot Password" link on the login screen if you are logged out.',
          ),
          _buildFaqItem(
            'How do I report an issue with a station or the app?',
            'From your Profile page, tap on "Report an Issue". You can then select the relevant station (if applicable), choose a category, and describe the problem in detail.',
          ),
          
          const SizedBox(height: 24),
          _buildContactUsCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.all(16.0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildContactUsCard(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Still need help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'If you can\'t find the answer to your question, feel free to contact our support team.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email feature coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email Us'),
                ),
                TextButton.icon(
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling feature coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call Us'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
