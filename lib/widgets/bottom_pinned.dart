import 'package:flutter/material.dart';

/// Pins [header] + [body] to the **bottom** of the page.
/// If [expandBody] is true, the body is wrapped in Expanded (direct child of Column),
/// and [bodyPadding] is applied **inside** that Expanded.
class BottomPinned extends StatelessWidget {
  const BottomPinned({
    super.key,
    required this.header,
    required this.body,
    this.expandBody = false,
    this.bodyPadding = EdgeInsets.zero,
  });

  final Widget header;
  final Widget body;
  final bool expandBody;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        header,
        if (expandBody)
          Expanded(child: Padding(padding: bodyPadding, child: body))
        else
          Padding(padding: bodyPadding, child: body),
      ],
    );
  }
}