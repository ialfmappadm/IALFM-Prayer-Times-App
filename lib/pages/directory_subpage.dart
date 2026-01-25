
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';

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
    const white = Colors.white;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
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
