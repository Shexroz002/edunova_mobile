import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'tex_prose.dart';

/// The problem the student sent, so a wait never raises "is this mine?".
///
/// A preview of at most three lines; the solution screen draws it in full.
class ProblemCard extends StatelessWidget {
  const ProblemCard({super.key, required this.text, this.label = true});

  final String text;

  /// Shows "Sizning masalangiz" above the card.
  final bool label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label) ...[
          Text(
            'SIZNING MASALANGIZ',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: c.textMuted),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 13, 10),
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.brand, 0x26),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.description_outlined, size: 16, color: context.readable(AppColors.brand)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texPreview(text),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, height: 1.45, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
