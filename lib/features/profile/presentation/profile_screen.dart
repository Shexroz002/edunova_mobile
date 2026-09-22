import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/detail_row.dart';
import 'widgets/identity_card.dart';

/// Profile: who the student is, what they study, and the two settings there are.
///
/// The page opened like a dashboard — a gradient header carrying the same three
/// numbers Statistika, Natijalar and (until this pass) the home page showed —
/// and then listed facts that could not be changed from where they were read.
/// It is an identity page now: every row leads to editing, and the one
/// destructive action stands apart from the rest.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Hisobingizdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
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
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    void edit() => context.push(Routes.profileEdit);

    final identity = IdentityCard(user: user, onEdit: edit);
    final details = _Details(user: user, onEdit: edit);
    final subjects = _Subjects(subjects: user.subjects, onEdit: edit);
    const settings = _Settings();
    final logout = _LogoutButton(onTap: () => _confirmLogout(context, ref));

    return Scaffold(
      appBar: const PageAppBar(
        title: Text('Profil'),
        showFriends: false,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: ref.read(authControllerProvider.notifier).refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 28),
            children: [
              ContentConstraint(
                child: context.isTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [identity, const SizedBox(height: 16), details],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                subjects,
                                const SizedBox(height: 16),
                                settings,
                                const SizedBox(height: 16),
                                logout,
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          const SizedBox(height: 12),
                          details,
                          const SizedBox(height: 12),
                          subjects,
                          const SizedBox(height: 12),
                          settings,
                          const SizedBox(height: 24),
                          logout,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section label, with an optional link to the one place things are changed.
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, this.linkLabel, this.onLink});

  final String label;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final link = linkLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: c.textMuted,
              ),
            ),
          ),
          if (link != null && onLink != null)
            InkWell(
              onTap: onLink,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      link,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.readable(AppColors.brand),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: context.readable(AppColors.brand),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card that holds a list of rows with one shared border.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // A Material, not a DecoratedBox: the rows paint their own ink, and a
    // coloured box between them and the nearest Material swallows the splash.
    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: child,
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.user, required this.onEdit});

  final AuthUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(label: 'Ma’lumotlarim', linkLabel: 'Tahrirlash', onLink: onEdit),
        _ListCard(
          child: Column(
            children: [
              DetailRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: user.email,
                onTap: onEdit,
              ),
              DetailRow(
                icon: Icons.phone_outlined,
                label: 'Telefon',
                value: user.phoneNumber,
                onTap: onEdit,
              ),
              DetailRow(
                icon: Icons.apartment_rounded,
                label: 'Maktab',
                value: user.schoolName,
                onTap: onEdit,
              ),
              DetailRow(
                icon: Icons.school_outlined,
                label: 'Sinf',
                value: user.educationLevel,
                onTap: onEdit,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The subjects the student picked.
///
/// Named "Fanlarim" until now, which is also what the home page and Statistika
/// call their per-subject *scores* — one word for two different things.
class _Subjects extends StatelessWidget {
  const _Subjects({required this.subjects, required this.onEdit});

  final List<Subject> subjects;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          label: 'Tanlangan fanlar',
          linkLabel: subjects.isEmpty ? 'Tanlash' : 'O‘zgartirish',
          onLink: onEdit,
        ),
        _ListCard(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: subjects.isEmpty
                ? Text(
                    'Hali fan tanlanmagan — tanlansa, test yaratishda taklif qilinadi.',
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textMuted),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final subject in subjects)
                        Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.tint(AppColors.brand, 0x24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.tint(AppColors.brand, 0x42)),
                          ),
                          // A non-null `alignment` makes the Container fill the
                          // constraints the Wrap offers, so every chip took a
                          // whole row. `Center` with a width factor keeps it
                          // tight around the label and still centres it.
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              subject.displayName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: brand,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Everything the student can change about the app itself.
///
/// Password change is deliberately absent: there is no endpoint for it
/// (`CLAUDE.md` default decision 5).
class _Settings extends ConsumerWidget {
  const _Settings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHead(label: 'Sozlamalar'),
        _ListCard(
          child: SwitchListTile(
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            secondary: Icon(Icons.dark_mode_outlined, size: 20, color: c.textMuted),
            title: Text(
              'Tungi rejim',
              style: TextStyle(fontSize: 14, color: c.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Signing out, on its own.
///
/// It used to sit in one card under the theme switch and the edit row, at the
/// same weight and spacing as both — a destructive action one stray tap from a
/// toggle.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final error = context.readable(AppColors.error);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.tint(AppColors.error, 0x5C)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: error),
              const SizedBox(width: 8),
              Text(
                'Chiqish',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
