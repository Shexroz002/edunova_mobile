import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/page_app_bar.dart';
import '../../core/widgets/quiz/badges.dart';
import '../../core/widgets/responsive.dart';
import '../analytics/data/analytics_repository.dart';
import '../analytics/domain/analytics_models.dart';
import '../auth/presentation/auth_controller.dart';
import '../competition/presentation/join_code_sheet.dart';
import '../notifications/presentation/widgets/notification_bell.dart';

/// Student dashboard, laid out like the web `StudentHomePage.tsx`: greeting,
/// stat cards, the "Test ishlash" hero, quick actions, the competition card and
/// "Mening fanlarim".
///
/// The web's four stat cards (40 testlar, 7 kun streak, 1560 XP, #4 o'rin) are
/// hard-coded there; `CLAUDE.md` default decision 1 replaces them with the real
/// `analytics/overall/cards` values. The "+12 do'st onlayn" line and the
/// "~15 min" estimate are dropped for the same reason.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final columns = context.gridColumns(phone: 2, tablet: 4, large: 4);

    return Scaffold(
      appBar: PageAppBar(
        title: context.isPhone ? const BrandTitle(size: 28) : const Text('Bosh sahifa'),
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overallStatsProvider);
          ref.invalidate(subjectStatsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 28),
          children: [
            ContentConstraint(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Greeting(
                    name: user?.fullName ?? '',
                    school: user?.schoolName,
                    grade: user?.educationLevel,
                  ),
                  const SizedBox(height: 16),
                  const _StatCards(),
                  const SizedBox(height: 16),
                  _PlayHero(onStart: () => context.push('/tests')),
                  const SizedBox(height: 14),
                  _QuickActions(columns: columns),
                  const SizedBox(height: 14),
                  _CompetitionCard(onOpen: () => context.push('/competition/new')),
                  const SizedBox(height: 20),
                  const _MySubjects(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time-of-day greeting, name and the school / class line.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, this.school, this.grade});

  final String name;
  final String? school;
  final String? grade;

  /// Same three buckets as the web.
  static String greetingFor(int hour) {
    if (hour < 12) return 'Xayrli tong';
    if (hour < 18) return 'Xayrli kun';
    return 'Xayrli kech';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subtitle = [
      school?.trim().isNotEmpty == true ? school!.trim() : 'Maktab nomi kiritilmagan',
      grade?.trim().isNotEmpty == true ? grade!.trim() : "Sinf ko'rsatilmagan",
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingFor(DateTime.now().hour)} 👋',
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          name.isEmpty ? 'Xush kelibsiz' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 13, color: c.textMuted)),
      ],
    );
  }
}

/// Three real stat cards from `analytics/overall/cards`.
class _StatCards extends ConsumerWidget {
  const _StatCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(overallStatsProvider);
    final value = stats.valueOrNull ?? OverallStats.empty;
    final loading = stats.isLoading;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline_rounded,
            value: '${value.totalSessions}',
            label: 'Sessiyalar',
            color: AppColors.brandLight,
            loading: loading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.task_alt_rounded,
            value: '${value.correctAnswers}',
            label: "To'g'ri javob",
            color: AppColors.success,
            loading: loading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            value: formatPercent(value.averagePercent),
            label: "O'rtacha",
            color: AppColors.warning,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.loading,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A phone fits three narrow cards only stacked; a tablet card is three
    // times as wide, where a centred stack would float in empty space, so the
    // icon moves beside the number.
    final horizontal = context.isTablet;

    final badge = Container(
      width: horizontal ? 42 : 32,
      height: horizontal ? 42 : 32,
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(horizontal ? 12 : 10),
      ),
      child: Icon(icon, size: horizontal ? 21 : 17, color: color),
    );

    final number = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.textMuted),
          )
        : Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: horizontal ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          );

    final caption = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: TextStyle(fontSize: horizontal ? 13 : 11, color: c.textMuted),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal ? 16 : 10, vertical: 14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: horizontal
          ? Row(
              children: [
                badge,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [number, const SizedBox(height: 2), caption],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                badge,
                const SizedBox(height: 8),
                number,
                const SizedBox(height: 2),
                caption
              ],
            ),
    );
  }
}

/// Indigo "Test ishlash" hero, the page's primary call to action.
class _PlayHero extends StatelessWidget {
  const _PlayHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // The web runs a three-stop gradient that ends in blue, and uses a
    // different opening colour per theme; a flat indigo-to-purple pair reads
    // far more purple than the site.
    final gradient = context.isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4C1D95), Color(0xFF6366F1), Color(0xFF3B82F6)],
            stops: [0, 0.55, 1],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3B82F6)],
            stops: [0, 0.60, 1],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x666366F1), blurRadius: 32, offset: Offset(0, 8)),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: gradient,
          ),
          child: InkWell(
            onTap: onStart,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ASOSIY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Test ishlash',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Bilimingizni sinang',
                          style: TextStyle(fontSize: 13, color: Color(0xFFE0E7FF)),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 17, color: Colors.white),
                              SizedBox(width: 7),
                              Text(
                                'Boshlash',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 34, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The web's quick-action grid.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <Widget>[
      _ActionTile(
        icon: Icons.add_box_outlined,
        color: AppColors.emerald,
        title: 'Test yaratish',
        subtitle: 'PDF yoki AI orqali test yarating',
        action: 'Yaratish',
        onTap: () => context.push(Routes.quizCreate),
      ),
      _ActionTile(
        icon: Icons.play_circle_outline_rounded,
        color: AppColors.brandLight,
        title: 'Testlar',
        subtitle: 'Barcha testlarni oching',
        action: 'Ochish',
        onTap: () => context.push('/tests'),
      ),
      _ActionTile(
        icon: Icons.history_rounded,
        color: AppColors.warning,
        title: 'Natijalar',
        subtitle: 'Test tarixi va natijalar',
        action: "Ko'rish",
        onTap: () => context.push('/results'),
      ),
      _ActionTile(
        icon: Icons.sensors_rounded,
        color: AppColors.sky,
        title: 'Jonli sessiya',
        subtitle: 'Kod bilan qo‘shiling',
        action: "Qo'shilish",
        onTap: () async {
          final sessionId = await showJoinCodeSheet(context);
          if (sessionId != null && context.mounted) {
            context.push('/session/$sessionId/lobby');
          }
        },
      ),
    ];

    // A fixed tile height instead of an aspect ratio: on a tablet four columns
    // of ~215 dp would otherwise be 205 dp tall, leaving most of each card
    // empty. The content is the same in every tile, so one height fits all.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 152,
      ),
      children: tiles,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final dark = context.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: c.cardShadow,
      ),
      child: Material(
        // Each tile carries a wash of its own accent, as on the web; a plain
        // card here reads as four identical grey boxes.
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withAlpha(dark ? 0x24 : 0x12),
                  color.withAlpha(dark ? 0x14 : 0x0A),
                ],
              ),
              border: Border.all(color: color.withAlpha(dark ? 0x40 : 0x33)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.tint(color),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.3, color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      action,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right_rounded, size: 15, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Competition entry card. The web's "+12 do'st onlayn" line is fabricated and
/// is left out (`CLAUDE.md` default decision 2).
class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.accentBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.groups_rounded, size: 22, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Do'stlar bilan ishlash",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Real vaqt rejimida birga test ishlang",
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, color) in const [
                    ('Real-vaqt', Color(0xFFFBBF24)),
                    ('Reyting', Color(0xFFA78BFA)),
                    ('Komanda jang', Color(0xFF38BDF8)),
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.tint(color),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.tint(color, 0x3D)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mening fanlarim" — per-subject accuracy from `analytics/subjects`.
class _MySubjects extends ConsumerWidget {
  const _MySubjects();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final subjects = ref.watch(subjectStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mening fanlarim',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          "Hozirgi o'rganayotgan fanlar",
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
        const SizedBox(height: 12),
        subjects.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => AppCard(
            child: Text(
              ApiException.from(e).message,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
          data: (items) => items.isEmpty
              ? AppCard(
                  child: Text(
                    "Hali fan bo'yicha natija yo'q — birinchi testingizni ishlang",
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (final subject in items) ...[
                      _SubjectCard(stats: subject),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.stats});

  final SubjectStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Per-subject icon, as the web picks one from the subject name.
              SubjectIconTile(stats.subject, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stats.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                '${stats.percent.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (stats.percent / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: c.border,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Fact(
                  icon: Icons.check_circle_outline_rounded,
                  text: "${stats.correct} to'g'ri",
                  color: AppColors.success),
              _Fact(
                  icon: Icons.cancel_outlined, text: '${stats.wrong} xato', color: AppColors.error),
              _Fact(
                  icon: Icons.bolt_rounded,
                  text: '${stats.total} jami javob',
                  color: AppColors.warning),
            ],
          ),
          if (stats.firstAttempt != null || stats.lastAttempt != null) ...[
            const SizedBox(height: 10),
            if (stats.firstAttempt != null)
              _DateRow(label: 'Birinchi urinish', date: stats.firstAttempt!),
            if (stats.lastAttempt != null) ...[
              const SizedBox(height: 6),
              _DateRow(label: "So'nggi urinish", date: stats.lastAttempt!),
            ],
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('$label:', style: TextStyle(fontSize: 12, color: c.textMuted)),
          const Spacer(),
          Text(
            formatDate(date),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
