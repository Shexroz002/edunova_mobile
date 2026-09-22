import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../session/data/session_repository.dart';
import '../../session/domain/session_models.dart';
import 'leaderboard_sheet.dart';
import '../../tests/presentation/start_test_sheet.dart';
import 'result_detail_sheet.dart';
import 'widgets/result_row.dart';

/// All history rows of the current student (newest first).
final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>(
  (ref) => ref.watch(sessionRepositoryProvider).fetchAllHistory(),
);

/// How the list is ordered. All three are orders — "Barchasi" used to sit among
/// them as if it were one.
enum ResultSort {
  recent('Yangi', Icons.schedule_rounded),
  best('Eng yaxshi', Icons.trending_up_rounded),
  worst('Eng past', Icons.trending_down_rounded);

  const ResultSort(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A date heading and the results under it.
class ResultGroup {
  const ResultGroup(this.label, this.items);

  final String label;
  final List<HistoryItem> items;

  /// Splits rows into `Bugun` / `Kecha` / `Bu hafta` / month, keeping order.
  ///
  /// Only worth doing while the list is in date order; sorting by score mixes
  /// the dates up, so those orders come back as one unlabelled group.
  static List<ResultGroup> of(List<HistoryItem> items, {DateTime? now}) {
    final groups = <String, List<HistoryItem>>{};
    for (final item in items) {
      final date = item.finishedAt ?? item.createdAt;
      final label = date == null ? 'Sana yo‘q' : historyGroup(date, now: now);
      groups.putIfAbsent(label, () => []).add(item);
    }
    return [for (final entry in groups.entries) ResultGroup(entry.key, entry.value)];
  }
}

/// Test history: one summary line, the order, and the results by date.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, this.openSessionId});

  /// Session whose leaderboard opens as soon as the history is on screen.
  final int? openSessionId;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  ResultSort _sort = ResultSort.recent;

  /// Guards the one-shot auto-open, so the sheet does not reappear on rebuild.
  bool _opened = false;

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
      case ResultSort.recent:
        break;
      case ResultSort.best:
        list.sort((a, b) => b.percent.compareTo(a.percent));
      case ResultSort.worst:
        list.sort((a, b) => a.percent.compareTo(b.percent));
    }
    return list;
  }

  /// Offered by the empty state: there is nothing to list until a test is run.
  Future<void> _startTest(BuildContext context) async {
    final sessionId = await showStartTestSheet(context);
    if (sessionId != null && context.mounted) context.push('/session/$sessionId/play');
  }

  void _openLeaderboard(HistoryItem item) => showLeaderboardSheet(
        context,
        sessionId: item.sessionId,
        title: item.title,
        date: item.finishedAt ?? item.createdAt,
      );

  /// Opens the requested leaderboard after the first frame that has data, so
  /// the sheet can carry the row's own title and date.
  void _autoOpen(List<HistoryItem> items) {
    final sessionId = widget.openSessionId;
    if (_opened || sessionId == null) return;
    _opened = true;

    final match = items.where((i) => i.sessionId == sessionId).firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showLeaderboardSheet(
        context,
        sessionId: sessionId,
        title: match?.title,
        date: match?.finishedAt ?? match?.createdAt,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('Natijalar'),
        showFriends: false,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            tooltip: 'Qidirish',
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: history.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(historyProvider),
          ),
          data: (all) {
            _autoOpen(all);
            final visible = _sorted(_matching(all));
            // Date headings only mean something while the list is in date
            // order; by score the dates interleave.
            final groups = _sort == ResultSort.recent
                ? ResultGroup.of(visible)
                : [ResultGroup('', visible)];

            return RefreshIndicator(
              onRefresh: () => ref.refresh(historyProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  12,
                  context.pagePadding,
                  28,
                ),
                children: [
                  ContentConstraint(
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_searchOpen) ...[
                          SearchField(
                            hint: "Test nomi yoki fan bo'yicha qidiring...",
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (value) => setState(() => _query = value),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (all.isNotEmpty) ...[
                          _SummaryStrip(items: all),
                          const SizedBox(height: 10),
                          _SortRow(
                            sort: _sort,
                            count: visible.length,
                            onSelected: (value) => setState(() => _sort = value),
                          ),
                        ],
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: EmptyView(
                              icon: _query.isEmpty
                                  ? Icons.history_rounded
                                  : Icons.search_off_rounded,
                              title: _query.isEmpty
                                  ? 'Hali natija yo‘q'
                                  : 'Natija topilmadi',
                              subtitle: _query.isEmpty
                                  ? 'Birinchi testni ishlang — natijalaringiz '
                                      'shu yerda sanalar bo‘yicha to‘planadi.'
                                  : '"$_query" bo\'yicha hech narsa yo\'q',
                              actionLabel: _query.isEmpty ? 'Test ishlash' : null,
                              onAction: _query.isEmpty ? () => _startTest(context) : null,
                            ),
                          ),
                        for (final group in groups) ...[
                          if (group.label.isNotEmpty) _GroupHeading(group.label),
                          for (final item in group.items) ...[
                            const SizedBox(height: 8),
                            ResultRow(
                              item: item,
                              // An open session has no result to show yet, so
                              // the row goes back into the test instead.
                              onOpen: () => item.canResume
                                  ? context.push('/session/${item.sessionId}/play')
                                  : showResultDetailSheet(context, item: item),
                              onLeaderboard: () => _openLeaderboard(item),
                            ),
                          ],
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

/// Average and best, on one line that opens Statistika.
///
/// This was a 159 dp card with four tiles. Two are gone: "Savollar" is trivia,
/// and "Jami vaqt" summed `finishedAt - createdAt`, which counts a test left
/// open rather than time spent — it read 149 hours while the rows under it said
/// "0 daqiqa".
class _SummaryStrip extends ConsumerWidget {
  const _SummaryStrip({required this.items});

  final List<HistoryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final finished = items.where((i) => i.isFinished);
    final best = finished.isEmpty
        ? 0.0
        : finished.map((i) => i.percent).reduce((a, b) => a > b ? a : b);
    // The same average Statistika and the home page show. Computing it here
    // instead gave one app two different "o'rtacha ball" — 25 % against 36 %.
    final average = ref.watch(overallStatsProvider).valueOrNull?.averagePercent ?? 0;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.statistics),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Row(
            children: [
              ScoreRing(percent: average, size: 48),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'O‘rtacha ball',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Eng yuqori natija — ${formatPercent(best)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three orders and how many rows are showing.
class _SortRow extends StatelessWidget {
  const _SortRow({required this.sort, required this.count, required this.onSelected});

  final ResultSort sort;
  final int count;
  final ValueChanged<ResultSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        for (final option in ResultSort.values) ...[
          _SortChip(
            option: option,
            selected: option == sort,
            onTap: () => onSelected(option),
          ),
          const SizedBox(width: 7),
        ],
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: c.textMuted,
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.option, required this.selected, required this.onTap});

  final ResultSort option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);
    final tone = selected ? brand : c.textSecondary;

    return Material(
      color: selected ? AppColors.tint(brand, 0x24) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.tint(brand, 0x70) : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 14, color: tone),
              const SizedBox(width: 6),
              Text(
                option.label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}
