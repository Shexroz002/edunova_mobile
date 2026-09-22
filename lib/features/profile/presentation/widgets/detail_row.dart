import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One fact about the student, and the way to change it.
///
/// The row used to print "—" for anything unfilled and lead nowhere: the only
/// entry into editing was a list tile below the subjects card, so a student
/// looking at an empty "Maktab" had to scroll past two cards to find it. Every
/// row opens the edit screen now, and an empty one asks to be filled instead of
/// showing a dash.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isLast;

  /// Whether the field has anything in it.
  bool get _filled => value?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Icon(icon, size: 17, color: c.textMuted),
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _filled ? value!.trim() : 'Kiritilmagan',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _filled ? FontWeight.w700 : FontWeight.w600,
                    color: _filled ? c.textPrimary : brand,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _filled ? c.textMuted : brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
