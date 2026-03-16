import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  final List<Map<String, String>> faqs = const [
    {
      'question': 'How do I reset my password?',
      'answer': 'Go to Settings > Account > Reset Password and follow the instructions.'
    },
    {
      'question': 'How can I contact support?',
      'answer': 'You can email us at support@example.com or use the chat feature in-app.'
    },
    {
      'question': 'Where can I find the user guide?',
      'answer': 'The user guide is available in the Help Center section and on our website.'
    },
    {
      'question': 'How to update my profile?',
      'answer': 'Go to Profile > Edit Profile to update your information.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.98),
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),

        elevation: 1,
        title: Text(
          'Help Center',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xff09205f)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline, size: 40, color: Color(0xff09205f)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Need help? Find answers to frequently asked questions below or contact support.',
                      style: GoogleFonts.lato(
                        color: const Color(0xff09205f),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      iconColor: Colors.blue,
                      collapsedIconColor: Colors.orangeAccent,
                      title: Text(
                        faq['question']!,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff09205f),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            faq['answer']!,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
