import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/grade.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/header_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../session/data/session_repository.dart';
import '../../session/domain/session_models.dart';
import 'leaderboard_sheet.dart';
import 'result_detail_sheet.dart';

/// All history rows of the current student (newest first).
final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>(
  (ref) => ref.watch(sessionRepositoryProvider).fetchAllHistory(),
);

enum _Sort { recent, best, worst }

/// Test history: summary, sorting and per-session actions (result, review, leaderboard).
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  _Sort _sort = _Sort.recent;

  /// The web hides the field behind a button in the header and filters the list
  /// as you type; the history is already loaded here, so the filter is local.
  bool _searchOpen = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  /// Matches the web: the quiz title or the subject.
  List<HistoryItem> _matching(List<HistoryItem> items) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((i) =>
            (i.title ?? '').toLowerCase().contains(query) ||
            (i.subject ?? '').toLowerCase().contains(query))
        .toList();
  }

  List<HistoryItem> _sorted(List<HistoryItem> items) {
    final list = [...items];
    switch (_sort) {
      case _Sort.recent:
        break;
      case _Sort.best:
        list.sort((a, b) => b.percent.compareTo(a.percent));
      case _Sort.worst:
        list.sort((a, b) => a.percent.compareTo(b.percent));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      body: SafeArea(
        child: history.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(historyProvider),
          ),
          data: (all) {
            final items = all;
            final visible = _matching(items);
            return RefreshIndicator(
              onRefresh: () => ref.refresh(historyProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(context.pagePadding),
                children: [
                  ContentConstraint(
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(
                          title: 'Natijalar',
                          subtitle: 'Barcha test natijalari',
                          trailing: _SearchToggle(open: _searchOpen, onTap: _toggleSearch),
                        ),
                        if (_searchOpen) ...[
                          const SizedBox(height: 14),
                          SearchField(
                            hint: "Test nomi yoki fan bo'yicha qidiring...",
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (value) => setState(() => _query = value),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _Summary(items: items),
                        const SizedBox(height: 16),
                        _FilterRow(
                          count: visible.length,
                          sort: _sort,
                          onSelected: (value) => setState(() => _sort = value),
                        ),
                        const SizedBox(height: 16),
                        if (visible.isEmpty)
                          EmptyView(
                            icon: _query.isEmpty ? Icons.history_rounded : Icons.search_off_rounded,
                            title: _query.isEmpty ? "Hali natijalar yo'q" : 'Natija topilmadi',
                            subtitle: _query.isEmpty
                                ? 'Birinchi testingizni ishlang'
                                : '"$_query" bo\'yicha hech narsa yo\'q',
                          ),
                        for (final item in _sorted(visible)) ...[
                          _HistoryCard(item: item),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Header action that reveals the search field, as on the web.
class _SearchToggle extends StatelessWidget {
  const _SearchToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HeaderButton(
      tooltip: open ? 'Qidiruvni yopish' : 'Qidirish',
      onTap: onTap,
      icon: open ? Icons.close_rounded : Icons.search_rounded,
      background: open ? c.accentMuted : c.bgCard,
      border: open ? c.accentBorder : c.border,
      iconColor: open ? c.accent : c.textSecondary,
    );
  }
}

/// "Saralash:" with the chips and the result counter.
///
/// A phone has room for the label and the counter on one line and the chips on
/// the next; a tablet fits all three on a single line, as the web does.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.count, required this.sort, required this.onSelected});

  final int count;
  final _Sort sort;
  final ValueChanged<_Sort> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.filter_alt_outlined, size: 15, color: c.textMuted),
        const SizedBox(width: 6),
        Text('Saralash:', style: TextStyle(fontSize: 13, color: c.textMuted)),
      ],
    );

    final chips = FilterChips<_Sort>(
      options: const [
        FilterOption(_Sort.recent, 'Barchasi', icon: Icons.schedule_rounded),
        FilterOption(_Sort.best, 'Eng yaxshi', icon: Icons.trending_up_rounded),
        FilterOption(_Sort.worst, 'Eng yomon', icon: Icons.trending_down_rounded),
      ],
      selected: sort,
      onSelected: onSelected,
      segmented: !context.isTablet,
    );

    final counter = Pill(
      label: '$count natija',
      color: AppColors.brandLight,
      icon: Icons.auto_awesome_rounded,
    );

    if (context.isTablet) {
      return Row(
        children: [
          label,
          const SizedBox(width: 12),
          Flexible(child: chips),
          const SizedBox(width: 12),
          counter,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [label, const Spacer(), counter]),
        const SizedBox(height: 10),
        chips,
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items});

  final List<HistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final finished = items.where((i) => i.isFinished).toList();
    final average = finished.isEmpty
        ? 0.0
        : finished.map((i) => i.percent).reduce((a, b) => a + b) / finished.length;
    final best =
        finished.isEmpty ? 0.0 : finished.map((i) => i.percent).reduce((a, b) => a > b ? a : b);
    final questions = finished.fold<int>(0, (sum, i) => sum + (i.totalQuestions ?? 0));
    // The web's "Jami vaqt" counts unfinished sessions too and is wrong because
    // of it (web bug #5); only finished sessions have a real duration.
    final minutes = finished.fold<int>(0, (sum, i) => sum + (i.durationMinutes ?? 0));

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ScoreRing(percent: average, size: 84, caption: "o'rtacha ball"),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.assignment_outlined,
                        value: '${items.length} ta',
                        label: 'Sessiyalar',
                        color: AppColors.brandLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.emoji_events_outlined,
                        value: formatPercent(best),
                        label: 'Eng yuqori',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.schedule_rounded,
                        value: formatMinutesCompact(minutes),
                        label: 'Jami vaqt',
                        color: AppColors.sky,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.help_outline_rounded,
                        value: '$questions',
                        label: 'Savollar',
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat tile of the summary grid.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        // The web tints every summary tile with its own accent; four grey
        // boxes lose the colour coding entirely.
        color: AppColors.tint(color, dark ? 0x1C : 0x12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tint(color, dark ? 0x3D : 0x33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final date = item.finishedAt ?? item.createdAt;
    final minutes = item.durationMinutes;

    return AppCard(
      onTap: item.isFinished ? () => context.push('/session/${item.sessionId}/result') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubjectIconTile(item.subject),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title ?? 'Test',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (item.subject != null) item.subject!,
                        if (date != null) formatDateTime(date),
                        if (minutes != null) '$minutes daqiqa',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!item.isFinished) const Pill(label: 'Tugallanmagan', color: AppColors.warning),
            ],
          ),
          if (item.isFinished) ...[
            const SizedBox(height: 12),
            // The web leads with the score and the grade side by side, then a
            // bar, rather than a single badge floating at the right edge.
            Row(
              children: [
                _ScorePill(percent: item.percent),
                const SizedBox(width: 8),
                GradeBadge(item.percent),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: item.percent / 100,
                minHeight: 6,
                backgroundColor: c.bgInner,
                valueColor: AlwaysStoppedAnimation(Grade.of(item.percent).color),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Count(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  text: '${item.correctAnswers}',
                ),
                _Count(
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  text: '${item.wrongAnswers ?? 0}',
                ),
                _Count(
                  icon: Icons.help_outline_rounded,
                  color: c.textMuted,
                  text: '${item.totalQuestions}',
                ),
                if (item.isMultiplayer)
                  _Count(
                    icon: Icons.emoji_events_outlined,
                    color: const Color(0xFFFBBF24),
                    text: '#${item.rank} / ${item.participantCount}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CardAction(
                    icon: Icons.visibility_outlined,
                    label: "Ko'rish",
                    accent: AppColors.sky,
                    lightText: const Color(0xFF0284C7),
                    onTap: () => showResultDetailSheet(context, item: item),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardAction(
                    icon: Icons.groups_outlined,
                    label: 'Reyting',
                    accent: AppColors.brand,
                    lightText: AppColors.brand,
                    onTap: () => showLeaderboardSheet(
                      context,
                      sessionId: item.sessionId,
                      title: item.title,
                      date: item.finishedAt ?? item.createdAt,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tinted card action, coloured per the web: sky for "Ko'rish", indigo for
/// "Reyting". A plain outlined button made the two read as the same action.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.lightText,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;

  /// The web darkens the label in light mode so it stays readable on a tint.
  final Color lightText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final foreground = dark ? accent : lightText;

    return Material(
      color: AppColors.tint(accent, dark ? 0x1A : 0x14),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.tint(accent, dark ? 0x47 : 0x38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Score percentage in a tinted pill, as the web shows it.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final color = Grade.of(percent).color;
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tint(color, dark ? 0x24 : 0x18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.tint(color, dark ? 0x4D : 0x3D)),
      ),
      child: Text(
        formatPercent(percent),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
