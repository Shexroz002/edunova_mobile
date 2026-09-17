import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One of the two ways to build a quiz.
///
/// Led by who the method is for, then by facts that decide it — the size limit,
/// who picks the question count, how long it takes. The card used to end in
/// "Avtomatik" and "Intellektual", which tell a student nothing about which one
/// to choose.
class MethodCard extends StatelessWidget {
  const MethodCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.who,
    required this.facts,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;

  /// e.g. `Darslik yoki konspekt bo‘lsa`.
  final String who;

  /// Three short lines that settle the choice.
  final List<String> facts;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = context.readable(color);

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
            border: Border.all(color: AppColors.tint(accent, 0x73), width: 1.5),
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
                      color: AppColors.tint(accent, 0x29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.tint(accent, 0x52)),
                    ),
                    child: Icon(icon, size: 23, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          who,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: c.border),
              const SizedBox(height: 12),
              for (final (index, fact) in facts.indexed) ...[
                if (index > 0) const SizedBox(height: 7),
                _Fact(text: fact),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.check_rounded, size: 14, color: c.textMuted),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
