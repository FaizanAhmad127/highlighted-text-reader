import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyTokenPage extends StatefulWidget {
  const BuyTokenPage({super.key});

  @override
  State<BuyTokenPage> createState() => _BuyTokenPageState();
}

class _BuyTokenPageState extends State<BuyTokenPage> {
  final TextEditingController apiKeyController = TextEditingController();

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set API Key'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            spacing: 20,
            children: [
              const Text(
                'You have reached 20-token limit. Please use your own OpenAI API key',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () {
                  _launchURL(
                      'https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key');
                },
                child: const Text(
                  'Get your own API key: https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key',
                ),
              ),
              TextButton(
                onPressed: () {
                  _launchURL(
                      'https://help.openai.com/en/articles/8264644-how-can-i-set-up-prepaid-billing');
                },
                child: const Text(
                  'Add balance to your project (1 USD ≈ 50-100 images): https://help.openai.com/en/articles/8264644-how-can-i-set-up-prepaid-billing',
                ),
              ),
              const Text(
                "Note: We don't store your API key. It will remain only in your device cache.",
              ),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  hintText: 'Enter your OpenAI API key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (apiKeyController.text.isNotEmpty) {
                    Navigator.of(context).pop([apiKeyController.text]);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter API key')),
                    );
                  }
                },
                child: const Text('Set API Key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
