
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.addressBook, size: 64), // regular
              SizedBox(height: 12),
              Text('Directory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('Content coming soon.', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}