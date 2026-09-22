import 'package:flutter/material.dart';

import '../../../core/network/media_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand.dart';
import '../../auth/domain/auth_user.dart';

/// Greeting, name and school on one row.
///
/// This was three stacked lines — "Xayrli tong 👋", the name, then school and
/// class — 75 dp at the top of the page for something that offers no action.
/// Two of those lines were usually apologies: a student who has not filled the
/// profile in read "Maktab nomi kiritilmagan • Sinf ko'rsatilmagan". The row is
/// 48 dp now, and where the profile is empty it asks to fill it instead.
class HelloRow extends StatelessWidget {
  const HelloRow({super.key, required this.user, required this.onCompleteProfile});

  final AuthUser? user;

  /// Opens profile editing, offered only while school or class is missing.
  final VoidCallback onCompleteProfile;

  /// Same three buckets as the web.
  static String greetingFor(int hour) {
    if (hour < 12) return 'Xayrli tong';
    if (hour < 18) return 'Xayrli kun';
    return 'Xayrli kech';
  }

  /// School and class, or null while neither has been filled in.
  static String? subtitleFor(AuthUser? user) {
    final parts = [user?.schoolName, user?.educationLevel]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = user?.fullName ?? '';
    final first = name.split(RegExp(r'\s+')).firstWhere((p) => p.isNotEmpty, orElse: () => '');
    final subtitle = subtitleFor(user);

    return Row(
      children: [
        UserAvatar(name: name, imageUrl: MediaUrl.resolve(user?.profileImage), size: 40),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                first.isEmpty
                    ? '${greetingFor(DateTime.now().hour)} 👋'
                    : '${greetingFor(DateTime.now().hour)}, $first',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                )
              else
                _CompletePrompt(onTap: onCompleteProfile),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stands in for the school line while the profile is empty.
class _CompletePrompt extends StatelessWidget {
  const _CompletePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.readable(AppColors.brand);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        // The label has to give way rather than push the chevron off the row:
        // it is already the widest thing on a narrow phone at a large font.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Maktab va sinfni kiriting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brand),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 15, color: brand),
          ],
        ),
      ),
    );
  }
}
