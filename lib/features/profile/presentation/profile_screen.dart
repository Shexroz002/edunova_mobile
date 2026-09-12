import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';

/// Profile: personal info, subjects, theme switch, editing and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final header = _HeaderCard(user: user);
    final info = _InfoCard(user: user);
    final subjects = _SubjectsCard(subjects: user.subjects);
    const settings = _SettingsCard();

    return Scaffold(
      appBar: const PageAppBar(title: Text('Profil'), showThemeToggle: false),
      body: RefreshIndicator(
        onRefresh: ref.read(authControllerProvider.notifier).refreshProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.pagePadding),
          children: [
            ContentConstraint(
              child: context.isTablet
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [header, const SizedBox(height: 16), info],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [subjects, const SizedBox(height: 16), settings],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 16),
                        info,
                        const SizedBox(height: 16),
                        subjects,
                        const SizedBox(height: 16),
                        settings,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient profile header, as on the web — but the web's level, "Top 10%",
/// XP, test count and streak are all hard-coded, so `CLAUDE.md` default
/// decision 1 replaces them with the real `analytics/overall/cards` values.
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(overallStatsProvider);
    final value = stats.valueOrNull ?? OverallStats.empty;
    final subtitle = [
      user.educationLevel?.trim().isNotEmpty == true
          ? user.educationLevel!.trim()
          : "Sinf ko'rsatilmagan",
      "O'quvchi",
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: user.fullName, imageUrl: user.profileImage, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFE0E7FF)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${value.totalSessions}',
                  label: 'Sessiyalar',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  icon: Icons.task_alt_rounded,
                  value: '${value.correctAnswers}',
                  label: "To'g'ri javob",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  icon: Icons.trending_up_rounded,
                  value: formatPercent(value.averagePercent),
                  label: "O'rtacha",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Translucent stat tile inside the gradient header.
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFFE0E7FF)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email),
          _InfoRow(icon: Icons.phone_outlined, label: 'Telefon', value: user.phoneNumber),
          _InfoRow(icon: Icons.apartment_rounded, label: 'Maktab', value: user.schoolName),
          _InfoRow(
              icon: Icons.school_outlined, label: 'Sinf', value: user.educationLevel, isLast: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.value, this.isLast = false});

  final IconData icon;
  final String label;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? '—',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectsCard extends StatelessWidget {
  const _SubjectsCard({required this.subjects});

  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fanlarim',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            Text('Fanlar tanlanmagan', style: TextStyle(fontSize: 13, color: c.textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.accentBorder),
                    ),
                    child: Text(
                      s.displayName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Hisobingizdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SwitchListTile(
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            secondary: Icon(Icons.dark_mode_outlined, color: c.textSecondary),
            title: Text('Tungi rejim', style: TextStyle(fontSize: 14, color: c.textPrimary)),
          ),
          Divider(height: 1, color: c.border),
          ListTile(
            onTap: () => context.push(Routes.profileEdit),
            leading: Icon(Icons.edit_outlined, color: c.textSecondary),
            title:
                Text('Profilni tahrirlash', style: TextStyle(fontSize: 14, color: c.textPrimary)),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ),
          Divider(height: 1, color: c.border),
          ListTile(
            onTap: () => _confirmLogout(context, ref),
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Chiqish',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
