import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../../../core/widgets/quiz/option_tile.dart';
import '../../../core/widgets/quiz/question_map.dart';
import '../../../core/widgets/quiz/question_view.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../data/session_repository.dart';
import '../domain/session_models.dart';

/// Review items of a session (question, correct option, student's choice).
final reviewItemsProvider = FutureProvider.autoDispose.family<List<ReviewItem>, int>(
  (ref, sessionId) => ref.watch(sessionRepositoryProvider).fetchReview(sessionId),
);

enum _ReviewFilter { all, wrong, unanswered }

/// Question-by-question error review after a test.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ref.watch(reviewItemsProvider(sessionId)).when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: ApiException.from(e).message,
                onRetry: () => ref.invalidate(reviewItemsProvider(sessionId)),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyView(
                      icon: Icons.fact_check_outlined, title: "Tahlil uchun ma'lumot yo'q")
                  : _ReviewBody(items: items),
            ),
      ),
    );
  }
}

class _ReviewBody extends StatefulWidget {
  const _ReviewBody({required this.items});

  final List<ReviewItem> items;

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  _ReviewFilter _filter = _ReviewFilter.all;
  int _position = 0;

  /// Indexes (into the full list) visible with the current filter.
  List<int> get _visible => [
        for (var i = 0; i < widget.items.length; i++)
          if (switch (_filter) {
            _ReviewFilter.all => true,
            _ReviewFilter.wrong => widget.items[i].isWrong,
            _ReviewFilter.unanswered => !widget.items[i].isAnswered,
          })
            i,
      ];

  MapCellStatus _statusOf(ReviewItem item) {
    if (!item.isAnswered) return MapCellStatus.unanswered;
    return item.isCorrect ? MapCellStatus.correct : MapCellStatus.wrong;
  }

  OptionState _optionState(ReviewItem item, String label, bool? isCorrect) {
    if (isCorrect == true) return OptionState.correct;
    if (item.selected == label) return OptionState.wrong;
    return OptionState.idle;
  }

  void _setFilter(_ReviewFilter filter) => setState(() {
        _filter = filter;
        _position = 0;
      });

  void _openMap(List<int> visible) {
    showQuestionMapSheet(
      context: context,
      title: 'Savollar',
      legend: [
        const MapLegendItem(color: AppColors.success, label: "To'g'ri"),
        const MapLegendItem(color: AppColors.error, label: 'Xato'),
        MapLegendItem(color: context.colors.border, label: 'Javobsiz'),
      ],
      grid: Builder(
        builder: (sheetContext) => QuestionMapGrid(
          count: widget.items.length,
          current: visible.isEmpty ? -1 : visible[_position],
          statusOf: (i) => _statusOf(widget.items[i]),
          onTap: (i) {
            setState(() {
              _filter = _ReviewFilter.all;
              _position = i;
            });
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = widget.items;
    final visible = _visible;
    final wrongCount = items.where((i) => i.isWrong).length;
    final unansweredCount = items.where((i) => !i.isAnswered).length;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 10),
          child: _ReviewStatusBar(
            position: visible.isEmpty ? 0 : _position + 1,
            visibleCount: visible.length,
            wrongCount: wrongCount,
            unansweredCount: unansweredCount,
            filter: _filter,
            onFilter: _setFilter,
            onMap: () => _openMap(visible),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyView(
                  icon: Icons.celebration_outlined,
                  title: _filter == _ReviewFilter.wrong
                      ? "Xato javoblar yo'q"
                      : "Javobsiz savollar yo'q",
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(context.pagePadding),
                  child: ContentConstraint(
                    maxWidth: 720,
                    child: _question(visible[_position]),
                  ),
                ),
        ),
        Container(
          decoration:
              BoxDecoration(color: c.bgCard, border: Border(top: BorderSide(color: c.border))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: _position == 0 ? null : () => setState(() => _position--),
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      label: const Text('Oldingi', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: _position >= visible.length - 1
                          ? null
                          : () => setState(() => _position++),
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      label: const Text('Keyingi', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _question(int index) {
    final item = widget.items[index];
    final correctLabel = item.question.correctOption?.label;
    final (text, color, icon) = !item.isAnswered
        ? (
            'Bu savolga javob bermagansiz',
            const Color(0xFF94A3B8),
            Icons.remove_circle_outline_rounded
          )
        : item.isCorrect
            ? (
                "Siz bu savolga to'g'ri javob bergansiz!",
                AppColors.success,
                Icons.check_circle_rounded
              )
            : (
                "Siz bu savolga noto'g'ri javob bergansiz!",
                AppColors.error,
                Icons.cancel_rounded,
              );
    // Same detail line as the web: what was picked and what was right.
    final detail = [
      if (item.selected != null) 'Sizning javobingiz: ${item.selected}',
      if (correctLabel != null && !item.isCorrect) "To'g'ri javob: $correctLabel",
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionView(
          key: ValueKey(item.question.id),
          question: item.question,
          header: Align(
            alignment: Alignment.centerLeft,
            child: Pill(label: '#${index + 1}', color: AppColors.brand),
          ),
          stateOf: (option) => _optionState(item, option.label, option.isCorrect),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.tint(color, 0x1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.tint(color, 0x55)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Header of the review screen: back button, title, position and the filters.
///
/// The web puts these in one bar; on a phone the filters wrap to a second row
/// so each stays a comfortable tap target.
class _ReviewStatusBar extends StatelessWidget {
  const _ReviewStatusBar({
    required this.position,
    required this.visibleCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.filter,
    required this.onFilter,
    required this.onMap,
  });

  final int position;
  final int visibleCount;
  final int wrongCount;
  final int unansweredCount;
  final _ReviewFilter filter;
  final ValueChanged<_ReviewFilter> onFilter;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SquareIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Orqaga',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xatolar tahlili',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$position / $visibleCount savol',
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              SquareIconButton(
                icon: Icons.grid_view_rounded,
                tooltip: 'Savollar xaritasi',
                onPressed: onMap,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FilterButton(
                label: 'Barchasi',
                selected: filter == _ReviewFilter.all,
                onTap: () => onFilter(_ReviewFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Xato ($wrongCount)',
                color: AppColors.error,
                selected: filter == _ReviewFilter.wrong,
                onTap: () => onFilter(_ReviewFilter.wrong),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Javobsiz ($unansweredCount)',
                selected: filter == _ReviewFilter.unanswered,
                onTap: () => onFilter(_ReviewFilter.unanswered),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = color ?? AppColors.brand;

    return Expanded(
      child: Material(
        color: selected ? AppColors.tint(accent, 0x24) : c.bgInner,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? accent : c.border),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? accent : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
