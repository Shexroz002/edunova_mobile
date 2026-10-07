import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/solution_models.dart';
import 'widgets/answer_card.dart';
import 'widgets/done_row.dart';
import 'widgets/solution_intro.dart';
import 'widgets/step_card.dart';
import 'widgets/tex_prose.dart';

/// A solution taught one step at a time, the way a lesson at the board goes.
///
/// Three phases: the intro (what is asked and the plan), the steps one by one,
/// then the answer. Finished steps fold into one green line each, so the screen
/// always holds a single step.
class SolutionView extends StatefulWidget {
  const SolutionView({
    super.key,
    required this.solution,
    this.problem,
    this.option,
    this.footer,
    this.finishLabel,
    this.onFinish,
  });

  final Solution solution;

  /// The problem text shown in the intro.
  final String? problem;

  /// The test option the answer is, for a bank question.
  final String? option;

  /// Shown under the answer: feedback and anything the screen adds.
  final Widget? footer;
  final String? finishLabel;
  final VoidCallback? onFinish;

  @override
  State<SolutionView> createState() => _SolutionViewState();
}

class _SolutionViewState extends State<SolutionView> {
  final _scroll = ScrollController();

  /// -1 is the intro, `steps.length` is the answer, anything between a step.
  int _phase = -1;
  bool _simpler = false;

  List<SolutionStep> get _steps => widget.solution.steps;
  bool get _atAnswer => _phase >= _steps.length;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int phase) {
    setState(() {
      _phase = phase;
      _simpler = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_phase >= 0) _Progress(phase: _phase, steps: _steps),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            children: [
              if (_phase < 0)
                SolutionIntro(solution: widget.solution, problem: widget.problem)
              else ...[
                for (var i = 0; i < _phase && i < _steps.length; i++) ...[
                  DoneRow(number: i + 1, step: _steps[i]),
                  const SizedBox(height: 7),
                ],
                const SizedBox(height: 4),
                if (_atAnswer) ...[
                  AnswerCard(solution: widget.solution, option: widget.option),
                  if (widget.footer != null) ...[const SizedBox(height: 12), widget.footer!],
                ] else
                  StepCard(number: _phase + 1, step: _steps[_phase], simplerOpen: _simpler),
              ],
            ],
          ),
        ),
        _Actions(
          children: _actions(),
        ),
      ],
    );
  }

  List<Widget> _actions() {
    if (_phase < 0) {
      return [
        Expanded(child: GradientButton(label: 'Boshladik', icon: Icons.arrow_forward_rounded, height: 52, onPressed: () => _go(0))),
      ];
    }
    if (_atAnswer) {
      if (widget.onFinish == null) return const [];
      return [
        Expanded(
          child: GradientButton(label: widget.finishLabel ?? 'Yopish', height: 52, onPressed: widget.onFinish!),
        ),
      ];
    }
    final step = _steps[_phase];
    final last = _phase == _steps.length - 1;
    final next = _simpler ? 'Tushundim, keyingisi' : (last ? 'Javob' : 'Keyingisi');
    return [
      if (!_simpler && step.simpler.isNotEmpty) ...[
        OutlinedButton(
          onPressed: () => setState(() => _simpler = true),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: BorderSide(color: context.colors.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            foregroundColor: context.colors.textPrimary,
          ),
          child: const Text('🤔 Tushunmadim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 9),
      ],
      Expanded(
        child: GradientButton(label: next, icon: Icons.arrow_forward_rounded, height: 52, onPressed: () => _go(_phase + 1)),
      ),
    ];
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.phase, required this.steps});

  final int phase;
  final List<SolutionStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = phase >= steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  text: done ? 'Tayyor!' : '${phase + 1}-qadam',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary),
                  children: [
                    if (!done)
                      TextSpan(
                        text: ' / ${steps.length}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: c.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  done ? '${steps.length} qadam' : texPreview(steps[phase].title),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: i <= phase ? null : c.border,
                      gradient: i <= phase
                          ? const LinearGradient(colors: [AppColors.brand, AppColors.violet])
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgBase,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: children),
        ),
      ),
    );
  }
}
