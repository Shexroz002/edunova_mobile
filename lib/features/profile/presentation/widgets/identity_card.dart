import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand.dart';
import '../../../auth/domain/auth_user.dart';

/// Who the student is: the photo, the name and the handle.
///
/// This used to be a gradient block carrying three numbers — sessions, correct
/// answers, average — which is the fourth copy of them in the app: Statistika
/// shows all three, Natijalar shows the average, and the home page lost them
/// for exactly this reason. Profil is not a report, and the numbers said
/// nothing a student could act on here.
///
/// The subtitle went too. It read "11-sinf • O'quvchi": the class is a row in
/// the details list below, and "O'quvchi" is true of everyone in this app.
class IdentityCard extends StatelessWidget {
  const IdentityCard({super.key, required this.user, required this.onEdit});

  final AuthUser user;

  /// Opens profile editing — where the photo is changed too.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(name: user.fullName, imageUrl: user.profileImage, size: 68),
                  // Changing the photo lives in the edit screen, but tapping
                  // the avatar is what a reader expects to do it.
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brandDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bgCard, width: 2),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
