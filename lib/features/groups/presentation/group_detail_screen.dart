import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/media_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../data/groups_repository.dart';
import '../domain/group_models.dart';
import 'widgets/group_podium.dart';

/// One group: header numbers, a top-3 podium, the assigned tests and every
/// member's accuracy — the sections of the web `StudentGroupDetailPage.tsx`.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));

    return Scaffold(
      body: SafeArea(
        child: group.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(groupId));
              ref.invalidate(groupTestsProvider(groupId));
              ref.invalidate(groupStudentsProvider(groupId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 28),
              children: [
                ContentConstraint(
                  maxWidth: 860,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(title: data.name, subtitle: data.subject),
                      const SizedBox(height: 16),
                      _HeaderCard(group: data),
                      const SizedBox(height: 16),
                      _LeaderboardCard(groupId: groupId),
                      const SizedBox(height: 16),
                      _TestsCard(groupId: groupId),
                      const SizedBox(height: 16),
                      _StudentsCard(groupId: groupId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Coloured tile, description, status and the four group numbers.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.group});

  final StudentGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = group.color.color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.tint(accent, 0x24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.school_rounded, size: 28, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (group.subject != null)
                          _Pill(
                            label: group.subject!,
                            color: accent,
                            icon: Icons.menu_book_rounded,
                          ),
                        _Pill(label: group.status.label, color: group.status.color, dot: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (group.description != null && group.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              group.description!.trim(),
              style: TextStyle(fontSize: 13, height: 1.45, color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.people_alt_rounded,
                  label: "O'quvchilar",
                  value: '${group.studentsCount}',
                  color: AppColors.brandLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  icon: Icons.assignment_outlined,
                  label: 'Testlar',
                  value: '${group.testsCount}',
                  color: AppColors.sky,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.track_changes_rounded,
                  label: "O'rtacha ball",
                  value: formatPercent(group.averageScore),
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  icon: Icons.schedule_rounded,
                  label: "So'nggi faollik",
                  // Short form so the tile does not truncate ("5 soat ol…").
                  value:
                      group.lastActivity == null ? '—' : formatRelativeShort(group.lastActivity!),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon, this.dot = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0x0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(color, 0x33)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.tint(color, 0x1F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-3 podium of the group's members.
class _LeaderboardCard extends ConsumerWidget {
  const _LeaderboardCard({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(groupStudentsProvider(groupId));

    return _Section(
      title: 'Leaderboard',
      subtitle: "Top 3 o'quvchi",
      child: students.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          ApiException.from(e).message,
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        data: (items) => items.isEmpty
            ? Text(
                "Hali natija yo'q",
                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              )
            // Already sorted best-first by the repository; the web's podium is
            // ordered wrong (web bug #4).
            : GroupPodium(students: items.take(3).toList()),
      ),
    );
  }
}

/// Tests assigned to the group.
class _TestsCard extends ConsumerWidget {
  const _TestsCard({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tests = ref.watch(groupTestsProvider(groupId));
    final count = tests.valueOrNull?.length ?? 0;

    return _Section(
      title: 'Testlar',
      subtitle: '$count ta test tayinlangan',
      child: tests.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          ApiException.from(e).message,
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        data: (items) => items.isEmpty
            ? Text('Test tayinlanmagan', style: TextStyle(fontSize: 13, color: c.textMuted))
            : Column(
                children: [
                  for (final test in items) ...[
                    _TestRow(groupId: groupId, test: test),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({required this.groupId, required this.test});

  final int groupId;
  final GroupTest test;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final band = AccuracyBand.of(test.averageScore);

    return Material(
      color: c.bgInner,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/groups/$groupId/sessions/${test.sessionId}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bar_chart_rounded, size: 17, color: c.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      test.quizName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tint(band.color),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      formatPercent(test.averageScore),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: band.color,
                      ),
                    ),
                  ),
                  Text(
                    '${test.completedStudents}/${test.totalStudents} ta',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  if (test.date != null)
                    Text(
                      // The web renders this as "M09 11" (web bug #3).
                      formatDate(test.date!),
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (test.averageScore / 100).clamp(0, 1),
                  minHeight: 5,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation(band.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every member's accuracy, with a name filter.
class _StudentsCard extends ConsumerStatefulWidget {
  const _StudentsCard({required this.groupId});

  final int groupId;

  @override
  ConsumerState<_StudentsCard> createState() => _StudentsCardState();
}

class _StudentsCardState extends ConsumerState<_StudentsCard> {
  String _search = '';
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final students = ref.watch(groupStudentsProvider(widget.groupId));

    return _Section(
      title: "O'quvchilar ko'rsatkichi",
      subtitle: 'Batafsil natijalar va statistika',
      child: students.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          ApiException.from(e).message,
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        data: (all) {
          final query = _search.trim().toLowerCase();
          final matched = query.isEmpty
              ? all
              : all.where((s) => s.fullName.toLowerCase().contains(query)).toList();
          final shown = _expanded ? matched : matched.take(3).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (value) => setState(() => _search = value),
                style: TextStyle(fontSize: 14, color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "Ism bo'yicha qidirish...",
                  hintStyle: TextStyle(color: c.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: c.textMuted),
                  filled: true,
                  fillColor: c.bgInner,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Text('Hech kim topilmadi', style: TextStyle(fontSize: 13, color: c.textMuted))
              else
                for (final student in shown) ...[
                  _StudentRow(student: student),
                  const SizedBox(height: 10),
                ],
              if (matched.length > 3)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Yopish' : "Barcha ${matched.length} ta o'quvchini ko'rsatish",
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final GroupStudent student;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final band = AccuracyBand.of(student.averageScore);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: student.fullName,
                imageUrl: MediaUrl.resolve(student.profileImage),
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tint(band.color),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            formatPercent(student.averageScore),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: band.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${student.testsCount} ta test',
                          style: TextStyle(fontSize: 12, color: c.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Two tall boxes for two numbers wasted most of the card on a phone,
          // so correct and wrong are inline counters above the progress bar.
          Row(
            children: [
              _Counter(
                icon: Icons.check_circle_rounded,
                value: '${student.correct}',
                label: "to'g'ri",
                color: AppColors.success,
              ),
              const SizedBox(width: 14),
              _Counter(
                icon: Icons.cancel_rounded,
                value: '${student.wrong}',
                label: "noto'g'ri",
                color: AppColors.error,
              ),
              const Spacer(),
              Text(
                formatPercent(student.averageScore),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: band.color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (student.averageScore / 100).clamp(0, 1),
              minHeight: 5,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(band.color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline `✓ 12 to'g'ri` counter.
class _Counter extends StatelessWidget {
  const _Counter({
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
      ],
    );
  }
}

/// Card with a title and subtitle, used by every section of the page.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
