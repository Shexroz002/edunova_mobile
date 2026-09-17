import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';

/// Temporary content for tabs that are built in later stages.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.stage,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Development stage in which this screen will be implemented.
  final int stage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(color: c.accentMuted, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.warning),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$stage-bosqichda',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
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
