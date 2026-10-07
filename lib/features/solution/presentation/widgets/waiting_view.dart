import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'problem_card.dart';
import 'waiting_board.dart';
import 'waiting_stages.dart';
import 'waiting_tips.dart';

/// Shown while the server writes a solution — ten to forty seconds, sometimes more.
///
/// It shows what is being solved, says where things are in words, and makes
/// the wait useful with a short rule. After [longWaitAfter] it says so plainly
/// and offers a way out: the solution waits in the history.
class WaitingView extends StatefulWidget {
  const WaitingView({super.key, this.problem, this.subject, required this.leaveHint});

  /// The problem as sent; previewed at the top.
  final String? problem;

  /// Picks the board's formulas and the tips.
  final String? subject;

  /// Where the solution will be found if the student leaves.
  final String leaveHint;

  /// When the wait stops being "usual".
  static const longWaitAfter = Duration(seconds: 45);

  /// How long each tip stays.
  static const tipEvery = Duration(seconds: 7);

  /// When each stage starts. The last one is never closed by time.
  static const stageStarts = [Duration.zero, Duration(seconds: 6), Duration(seconds: 14), Duration(seconds: 24)];

  @override
  State<WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<WaitingView> {
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  /// A different first tip each time, so returning students see new ones.
  final int _tipStart = math.Random().nextInt(100);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _stage => WaitingView.stageStarts.lastIndexWhere((start) => _elapsed >= start);

  bool get _long => _elapsed >= WaitingView.longWaitAfter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final physics = (widget.subject ?? '').toLowerCase().contains('fiz');
    final tips = tipsFor(widget.subject);
    final problem = widget.problem?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (problem.isNotEmpty) ...[
          ProblemCard(text: problem),
          const SizedBox(height: 12),
        ],
        WaitingBoard(physics: physics),
        const SizedBox(height: 16),
        Text(
          stageHeadlines[_stage],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        const SizedBox(height: 4),
        Text(
          _long ? 'Odatdagidan biroz uzoqroq ketyapti' : 'Odatda 20–40 soniya',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: _long ? context.readable(AppColors.warning) : c.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        WaitingStages(current: _stage),
        // The first stage has the board to itself; the rules start with the second.
        if (_stage > 0) ...[
          const SizedBox(height: 12),
          TipCard(tips: tips, index: _tipStart + _elapsed.inSeconds ~/ WaitingView.tipEvery.inSeconds),
        ],
        const SizedBox(height: 18),
        if (_long) ...[
          OutlinedButton.icon(
            onPressed: () => context.go(Routes.home),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: c.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: c.textPrimary,
            ),
            icon: const Icon(Icons.home_outlined, size: 19),
            label: const Text('Bosh sahifaga qaytish', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.leaveHint}\nKutib o‘tirishingiz shart emas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.45, color: c.textMuted),
          ),
        ] else
          Text(
            'Ekrandan chiqib ketsangiz ham yechim tayyorlanaveradi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
      ],
    );
  }
}
