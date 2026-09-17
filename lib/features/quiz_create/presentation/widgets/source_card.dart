import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

/// The request a job was started from, as the progress screen shows it.
class JobSource {
  const JobSource({required this.icon, required this.title, required this.meta});

  final IconData icon;
  final String title;
  final String meta;
}

/// What the job is being built from: the chosen file, or the subject and
/// question count.
///
/// The progress screen used to show nothing about the request, so a student who
/// picked the wrong file only found out two minutes later.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.source, required this.tone});

  final JobSource source;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = context.readable(tone);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tint(accent, 0x21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.tint(accent, 0x4D)),
            ),
            child: Icon(source.icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(source.meta, style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
