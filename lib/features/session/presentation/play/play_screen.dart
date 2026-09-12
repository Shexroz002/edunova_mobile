import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/quiz/option_tile.dart';
import '../../../../core/widgets/quiz/question_map.dart';
import '../../../../core/widgets/quiz/question_view.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/session_repository.dart';
import 'play_controller.dart';

/// Test-taking screen for a running session (single or multiplayer).
///
/// Phone: one question per page, question map in a bottom sheet.
/// Tablet: question on the left, map and submit panel on the right.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  late final PlayController _controller;
  late final AppLifecycleListener _lifecycle;
  bool _navigatedToResult = false;
  String? _shownError;

  @override
  void initState() {
    super.initState();
    _controller = PlayController(
      sessionId: widget.sessionId,
      repository: ref.read(sessionRepositoryProvider),
      prefs: ref.read(sharedPreferencesProvider),
      sockets: ref.read(socketFactoryProvider),
    )..addListener(_onControllerChanged);
    _lifecycle = AppLifecycleListener(onResume: _controller.onResume);
    _controller.load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  /// Navigates to the result once it arrives and surfaces submit errors.
  void _onControllerChanged() {
    final result = _controller.result;
    if (result != null && !_navigatedToResult) {
      _navigatedToResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/session/${widget.sessionId}/result', extra: result);
      });
      return;
    }
    final error = _controller.submitError;
    if (error != null && error != _shownError) {
      _shownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      });
    }
  }

  Future<void> _confirmSubmit() async {
    final c = _controller;
    final unanswered = c.total - c.answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Testni yakunlaysizmi?'),
        content: Text(
          'Javob berilgan: ${c.answeredCount} / ${c.total}'
          '${unanswered > 0 ? '\nJavobsiz qolgan: $unanswered ta' : ''}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Davom etish')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yakunlash')),
        ],
      ),
    );
    if (ok == true) await _controller.submit();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Testdan chiqasizmi?'),
        content: const Text(
          "Javoblaringiz saqlanadi, lekin vaqt to'xtamaydi. Vaqt tugaganda test avtomatik yakunlanadi.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Qolish')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  void _openMap() {
    showQuestionMapSheet(
      context: context,
      title: 'Savollar xaritasi',
      legend: _legend(context),
      grid: ListenableBuilder(
        listenable: _controller,
        builder: (sheetContext, _) => _grid(onTap: (i) {
          _controller.goTo(i);
          Navigator.of(sheetContext).pop();
        }),
      ),
    );
  }

  QuestionMapGrid _grid({required ValueChanged<int> onTap}) {
    final c = _controller;
    return QuestionMapGrid(
      count: c.total,
      current: c.index,
      statusOf: (i) => c.answers.containsKey(c.questions[i].id)
          ? MapCellStatus.answered
          : MapCellStatus.unanswered,
      onTap: onTap,
    );
  }

  List<Widget> _legend(BuildContext context) => [
        const MapLegendItem(color: AppColors.brand, label: 'Javob berilgan'),
        MapLegendItem(color: context.colors.border, label: 'Javobsiz'),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final canLeaveFreely = c.loading || c.loadError != null || c.result != null;

        return PopScope(
          canPop: canLeaveFreely,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  if (!c.loading && c.loadError == null && c.current != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: _StatusBar(
                        controller: c,
                        onMap: _openMap,
                        onSubmit: _confirmSubmit,
                      ),
                    ),
                  Expanded(child: _body(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final c = _controller;
    if (c.loading) return const LoadingView();
    if (c.loadError != null) return ErrorView(message: c.loadError!, onRetry: c.load);
    final question = c.current;
    if (question == null) {
      return const EmptyView(icon: Icons.help_outline_rounded, title: "Bu testda savollar yo'q");
    }

    final questionPane = Column(
      children: [
        if (c.finishedByHost)
          const _Banner(text: 'Sessiya host tomonidan tugatildi. Javoblaringiz yuborilmoqda...'),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ContentConstraint(
              maxWidth: 720,
              child: QuestionView(
                key: ValueKey(question.id),
                question: question,
                stateOf: (option) =>
                    c.answerOf(question) == option.label ? OptionState.selected : OptionState.idle,
                onOptionTap: (option) => c.select(option.label),
              ),
            ),
          ),
        ),
        _BottomBar(controller: c, onSubmit: _confirmSubmit),
      ],
    );

    if (context.isPhone) return questionPane;

    return Row(
      children: [
        Expanded(child: questionPane),
        VerticalDivider(width: 1, color: context.colors.border),
        SizedBox(
          width: 300,
          child: _SidePanel(
            controller: c,
            grid: _grid(onTap: c.goTo),
            legend: _legend(context),
            onSubmit: _confirmSubmit,
          ),
        ),
      ],
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final color = remaining.inSeconds < 300
        ? AppColors.error
        : (remaining.inSeconds < 600 ? const Color(0xFFFBBF24) : AppColors.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.tint(color, 0x55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            formatClock(remaining),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.tint(AppColors.warning, 0x26),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child:
          Text(text, style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
    );
  }
}

/// Previous / next navigation, with the finish action on the last question.
///
/// The web pairs `Oldingi` and `Keyingi` at the bottom and keeps submitting in
/// the status bar; on a phone the last question also gets a full-width finish
/// button so the flow ends where the thumb already is.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onSubmit});

  final PlayController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: c.index == 0 ? null : c.previous,
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  label: const Text('Oldingi', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: c.isLast
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: c.submitting ? null : onSubmit,
                        icon: c.submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label:
                            const Text('Yakunlash', maxLines: 1, overflow: TextOverflow.ellipsis),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        onPressed: c.next,
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        label: const Text('Keyingi', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact status bar: question counter, answered badge, progress, countdown,
/// the question map and the submit action — the web's play-screen header.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.onMap, required this.onSubmit});

  final PlayController controller;
  final VoidCallback onMap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final progress = c.total == 0 ? 0.0 : c.answeredCount / c.total;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Savol ${c.index + 1}/${c.total}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tint(AppColors.success),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${c.answeredCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: colors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (c.hasTimer) ...[
            _TimerChip(remaining: c.remaining),
            const SizedBox(width: 6),
          ],
          _BarIconButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Savollar xaritasi',
            onPressed: onMap,
          ),
          const SizedBox(width: 6),
          _BarIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Testni yakunlash',
            filled: true,
            onPressed: c.submitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

/// 40×40 action button used inside [_StatusBar].
class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.brand : colors.bgInner,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: filled ? AppColors.brand : colors.border),
            ),
            child: Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : (enabled ? colors.textSecondary : colors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.controller,
    required this.grid,
    required this.legend,
    required this.onSubmit,
  });

  final PlayController controller;
  final Widget grid;
  final List<Widget> legend;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bgCard,
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Savollar',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text(
                '${controller.answeredCount} / ${controller.total} javob berildi',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 6, children: legend),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(child: grid)),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: controller.submitting ? null : onSubmit,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Testni yakunlash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
