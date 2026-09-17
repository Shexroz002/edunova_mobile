import 'package:flutter/material.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/brand.dart';
import '../../domain/group_models.dart';

/// Top-3 podium: second place left, first in the middle and taller, third
/// right — the arrangement of the web's group leaderboard.
///
/// Callers pass the students already ordered best-first; the web's own podium
/// is sorted wrong (web bug #4).
class GroupPodium extends StatelessWidget {
  const GroupPodium({super.key, required this.students});

  final List<GroupStudent> students;

  /// Medal colours for places 1–3.
  static const _medals = [Color(0xFFFBBF24), Color(0xFF94A3B8), Color(0xFFB45309)];

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const SizedBox.shrink();

    final first = students.first;
    final second = students.length > 1 ? students[1] : null;
    final third = students.length > 2 ? students[2] : null;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: second == null ? const SizedBox() : _Place(student: second, place: 2)),
            Expanded(child: _Place(student: first, place: 1)),
            Expanded(child: third == null ? const SizedBox() : _Place(student: third, place: 3)),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < students.length; i++) ...[
          _RankRow(student: students[i], place: i + 1),
          if (i < students.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  static Color medalOf(int place) => _medals[(place - 1).clamp(0, _medals.length - 1)];
}

class _Place extends StatelessWidget {
  const _Place({required this.student, required this.place});

  final GroupStudent student;
  final int place;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final medal = GroupPodium.medalOf(place);
    final size = place == 1 ? 66.0 : 52.0;

    return Column(
      children: [
        if (place == 1) const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFBBF24)),
        if (place == 1) const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medal, width: 2.5),
              ),
              child: UserAvatar(
                name: student.fullName,
                imageUrl: MediaUrl.resolve(student.profileImage),
                size: size,
              ),
            ),
            Positioned(
              top: -4,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: medal,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bgCard, width: 2),
                ),
                child: Text(
                  '$place',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          student.fullName.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: place == 1 ? 14 : 13,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.tint(medal, 0x24),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            formatPercent(student.averageScore),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: medal),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.student, required this.place});

  final GroupStudent student;
  final int place;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final medal = GroupPodium.medalOf(place);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, size: 17, color: medal),
          const SizedBox(width: 10),
          UserAvatar(
            name: student.fullName,
            imageUrl: MediaUrl.resolve(student.profileImage),
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              student.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tint(medal, 0x24),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              formatPercent(student.averageScore),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: medal),
            ),
          ),
        ],
      ),
    );
  }
}
