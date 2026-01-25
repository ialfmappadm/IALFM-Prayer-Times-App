
// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // keeps the app-wide gradient
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.ellipsis, size: 64),
              SizedBox(height: 12),
              Text('More', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('Content coming soon.', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}