import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One of the two ways to build a quiz, as on the web's first step.
class MethodCard extends StatelessWidget {
  const MethodCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.duration,
    required this.trait,
    required this.traitIcon,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  /// e.g. `~2-3 daqiqa`.
  final String duration;

  /// e.g. `Avtomatik`.
  final String trait;
  final IconData traitIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.tint(color),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 23, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(fontSize: 13, height: 1.45, color: c.textMuted),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: c.textSecondary),
                  const SizedBox(width: 5),
                  Text(duration, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  const SizedBox(width: 10),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Icon(traitIcon, size: 13, color: c.textSecondary),
                  const SizedBox(width: 5),
                  Text(trait, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
