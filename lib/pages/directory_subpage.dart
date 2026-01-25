
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Uses AppGradients from main.dart (ThemeExtension)
import '../main.dart' show AppGradients;

class DirectorySubPage extends StatelessWidget {
  final String title;
  final Widget body;
  const DirectorySubPage({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradients = Theme.of(context).extension<AppGradients>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(color: cs.onPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: cs.onPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(child: body),
          ),
        ),
      ),
    );
  }
}