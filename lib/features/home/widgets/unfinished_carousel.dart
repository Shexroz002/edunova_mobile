import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/subject_style.dart';
import '../../session/presentation/unfinished_sessions.dart';
import '../../session/domain/session_models.dart';

/// How many the home page carries before it starts pointing at Natijalar.
///
/// An untimed session never expires by itself, so this list can only grow.
/// Uncapped, the home page would slowly turn into a ledger of abandoned work.
const _maxCards = 5;

/// "Tugallanmagan" — the open tests, one per swipe.
///
/// It sits above the "Test ishlash" hero because a test already started beats
/// starting a new one, and it renders nothing at all when there is none: an
/// empty-state card here would be noise on the busiest screen in the app.
class UnfinishedCarousel extends ConsumerStatefulWidget {
  const UnfinishedCarousel({super.key});

  @override
  ConsumerState<UnfinishedCarousel> createState() => _UnfinishedCarouselState();
}

class _UnfinishedCarouselState extends ConsumerState<UnfinishedCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the test, then re-reads the list: the student may have handed it in.
  Future<void> _resume(int sessionId) async {
    await context.push('/session/$sessionId/play');
    if (mounted) ref.invalidate(unfinishedSessionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(unfinishedSessionsProvider).valueOrNull ?? const <HistoryItem>[];
    if (all.isEmpty) return const SizedBox.shrink();

    final items = all.take(_maxCards).toList();
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 17, color: brand),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Tugallanmagan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (all.length > items.length)
                InkWell(
                  onTap: () => context.push(Routes.results),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text(
                      'Barchasi →',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: brand),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 142,
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => _Card(
                item: items[index],
                onResume: () => _resume(items[index].sessionId),
              ),
            ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 10),
            _Dots(count: items.length, active: _page),
          ],
        ],
      ),
    );
  }
}

/// One open test: how far it got, and the way back in.
class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onResume});

  final HistoryItem item;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = SubjectStyle.of(item.subject);
    final brand = context.readable(AppColors.brand);
    final total = item.totalQuestions ?? 0;
    final started = item.answered > 0;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onResume,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tint(style.color, 0x2B),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(style.icon, size: 20, color: context.readable(style.color)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title ?? 'Test',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _meta(total, started),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatPercent(item.progress * 100),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: started ? brand : c.textMuted,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 6,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation(brand),
                ),
              ),
              // The whole card already resumes; the button is here because on a
              // banner the student should not have to guess that.
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(started ? 'Davom ettirish' : 'Boshlash'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tint(brand, 0x29),
                  foregroundColor: brand,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(color: AppColors.tint(brand, 0x55)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _meta(int total, bool started) {
    final subject = SubjectStyle.displayName(item.subject);
    final progress =
        !started || total == 0 ? 'hali javob berilmagan' : '${item.answered}/$total javob berilgan';
    return subject.isEmpty ? progress : '$subject · $progress';
  }
}

/// Which card of how many. The only sign that there is another one, now that
/// the card fills the width and nothing peeks in from the side.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final brand = context.readable(AppColors.brand);
    final c = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? brand : c.textMuted.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ],
    );
  }
}
