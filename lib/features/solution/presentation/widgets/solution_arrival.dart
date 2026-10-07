import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'waiting_stages.dart';

/// Shows [waiting] while [isWaiting]; when a seen wait ends in success it
/// flashes "Yechim tayyor!" for a moment before [ready].
///
/// A child needs the "done!" moment — but only after waiting for it: a
/// solution that was already there opens straight away.
class ArrivalSwitcher extends StatefulWidget {
  const ArrivalSwitcher({
    super.key,
    required this.isWaiting,
    required this.waiting,
    required this.ready,
    this.celebrate = true,
    this.steps,
  });

  final bool isWaiting;
  final Widget waiting;
  final Widget ready;

  /// False when the wait ended in a failure: nothing to celebrate.
  final bool celebrate;

  /// Steps in the solution, for "4 qadam".
  final int? steps;

  /// How long the "done!" moment stays.
  static const moment = Duration(milliseconds: 900);

  @override
  State<ArrivalSwitcher> createState() => _ArrivalSwitcherState();
}

class _ArrivalSwitcherState extends State<ArrivalSwitcher> {
  // Not a `late` initializer: that would run on first read — inside
  // didUpdateWidget, against the new widget — and miss the wait entirely.
  bool _sawWaiting = false;
  bool _arriving = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sawWaiting = widget.isWaiting;
  }

  @override
  void didUpdateWidget(ArrivalSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.isWaiting) _sawWaiting = true;
    if (old.isWaiting && !widget.isWaiting && _sawWaiting && widget.celebrate) {
      _arriving = true;
      _timer?.cancel();
      _timer = Timer(ArrivalSwitcher.moment, () {
        if (mounted) setState(() => _arriving = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.isWaiting
        ? widget.waiting
        : _arriving
            ? _Arrived(steps: widget.steps)
            : widget.ready;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(widget.isWaiting ? 'waiting' : (_arriving ? 'arrived' : 'ready')),
        child: child,
      ),
    );
  }
}

class _Arrived extends StatelessWidget {
  const _Arrived({this.steps});

  final int? steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = context.readable(AppColors.success);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.tint(AppColors.success, 0x40), AppColors.tint(AppColors.success, 0x14)],
                  ),
                  border: Border.all(color: AppColors.tint(AppColors.success, 0x8C), width: 1.5),
                  boxShadow: [BoxShadow(color: AppColors.tint(AppColors.success, 0x40), blurRadius: 40)],
                ),
                child: Icon(Icons.check_rounded, size: 52, color: green),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Yechim tayyor!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            if (steps != null) ...[
              const SizedBox(height: 4),
              Text('$steps qadam · birma-bir ko‘rasiz', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
            ],
            const SizedBox(height: 18),
            WaitingStages(current: stageCount, allDone: true),
          ],
        ),
      ),
    );
  }
}
