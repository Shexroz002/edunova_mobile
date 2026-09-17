import 'package:flutter/material.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand.dart';
import '../../domain/competition_models.dart';

/// Who is in the room, and the way to invite more.
///
/// The old card carried a `N/M tayyor` pill, a per-person status pill and a
/// "Hozircha N ishtirokchi qo'shildi" footer — three statements of the same
/// fact. Joining the socket is what marks a student ready, so that number is
/// almost always full and says nothing; only somebody who is *not* here is
/// worth calling out, on their own row.
class ParticipantsCard extends StatelessWidget {
  const ParticipantsCard({
    super.key,
    required this.participants,
    required this.currentUserId,
    this.onInvite,
  });

  final List<SessionParticipant> participants;

  /// Marks the signed-in student's own row.
  final int? currentUserId;

  /// Omitted for a joiner: inviting is the host's job.
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);
    final present = participants.where((p) => p.status.isPresent).toList();
    // The backend keeps rows for people who left; show them last, dimmed.
    final gone = participants.where((p) => !p.status.isPresent).toList();
    final rows = [...present, ...gone];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.tint(brand, 0x2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.tint(brand, 0x52)),
                ),
                child: Icon(Icons.people_alt_rounded, size: 17, color: brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ishtirokchilar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(brand, 0x24),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.tint(brand, 0x4D)),
                ),
                child: Text(
                  '${present.length} kishi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brand),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: Container(height: 1, color: c.border),
          ),
          for (final participant in rows)
            _PersonRow(
              participant: participant,
              you: participant.userId == currentUserId,
            ),
          if (onInvite != null) _InviteRow(onTap: onInvite!),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.participant, required this.you});

  final SessionParticipant participant;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final here = participant.status.isPresent;
    final success = context.readable(AppColors.success);

    return Opacity(
      opacity: here ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  name: participant.displayName,
                  imageUrl: MediaUrl.resolve(participant.profileImage),
                  size: 40,
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: here ? success : c.textMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bgCard, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                participant.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            // "Siz" is a badge rather than a name suffix: next to the Host
            // badge a long name used to eat the marker instead of ellipsing.
            if (you) ...[
              const SizedBox(width: 8),
              _Badge(label: 'Siz', color: context.readable(AppColors.brand)),
            ],
            if (participant.isHost) ...[
              const SizedBox(width: 8),
              _Badge(
                label: 'Host',
                color: context.readable(AppColors.warning),
                icon: Icons.workspace_premium_rounded,
              ),
            ],
            if (!here) ...[
              const SizedBox(width: 8),
              _Badge(label: 'Ulanmagan', color: c.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Last row of the list: inviting belongs where the people are, not in a
/// full-width green button competing with "Testni boshlash".
class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Icon(Icons.person_add_alt_rounded, size: 19, color: brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Do‘st qo‘shish',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: brand),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 9 : 8),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0x24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.tint(color, 0x57)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
