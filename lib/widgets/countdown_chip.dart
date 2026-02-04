// lib/widgets/countdown_chip.dart
//
// A compact, allocation-lean countdown that only rebuilds itself.
// - Uses a Ticker (frame-aligned), updates text at most once per second
// - RepaintBoundary isolates paint work from siblings
// - Tabular figures reduce relayout jitter when digits change
// - Optional onDone callback when it reaches 0

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class CountdownChip extends StatefulWidget {
  final DateTime end;              // target instant (local device time)
  final VoidCallback? onDone;      // called exactly once when it hits 0
  final TextStyle? style;
  final EdgeInsetsGeometry padding;
  final bool showHours;            // if false, hides hours when == 0
  final Duration tick;             // step granularity (default: 1s)

  const CountdownChip({
    super.key,
    required this.end,
    this.onDone,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.showHours = true,
    this.tick = const Duration(seconds: 1),
  });

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  int _lastDisplayedSeconds = -1;
  String _text = '';
  bool _doneNotified = false;
  Duration _acc = Duration.zero; // accumulates frame time to hit 1s steps

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _updateText(initial: true);
  }

  @override
  void didUpdateWidget(covariant CountdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.end != widget.end) {
      _doneNotified = false;
      _updateText(initial: true);
    }
  }

  void _onTick(Duration elapsed) {
    // Frame-aligned step: only compute once per [tick]
    final delta = elapsed - _acc;
    if (delta >= widget.tick) {
      _acc = elapsed;
      _updateText();
    }
  }

  void _updateText({bool initial = false}) {
    final now = DateTime.now();
    final remaining = widget.end.difference(now);
    final secs = max(0, remaining.inSeconds);

    if (secs == 0 && !_doneNotified) {
      _doneNotified = true;
      widget.onDone?.call();
    }

    if (initial || secs != _lastDisplayedSeconds) {
      _lastDisplayedSeconds = secs;

      final h = secs ~/ 3600;
      final m = (secs % 3600) ~/ 60;
      final s = secs % 60;
      final showH = widget.showHours || h > 0;

      final text = showH
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      if (mounted) {
        setState(() => _text = text);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()], // stable width digits
      fontWeight: FontWeight.w600,
    );

    return RepaintBoundary(
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_text, style: style),
      ),
    );
  }
}