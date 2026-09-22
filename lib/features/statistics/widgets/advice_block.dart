import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../analytics/domain/analytics_models.dart';

/// One block of the study advice, clamped until it is tapped.
///
/// The three blocks ran to about 550 dp of prose. The text comes from
/// `analytics/recommendation`, so rewriting it is the backend's business —
/// showing it is ours. Two lines are enough to tell the blocks apart; the rest
/// is a tap away, and the action stays visible either way.
class AdviceBlock extends StatefulWidget {
  const AdviceBlock({
    super.key,
    required this.block,
    required this.color,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final RecommendationBlock block;
  final Color color;
  final IconData icon;

  /// Shown only when the block has somewhere to go.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<AdviceBlock> createState() => _AdviceBlockState();
}

class _AdviceBlockState extends State<AdviceBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = context.readable(widget.color);
    final label = widget.actionLabel;

    return Material(
      color: AppColors.tint(widget.color, 0x1A),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.tint(widget.color, 0x38)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 15, color: tone),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.block.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        color: tone,
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: c.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.block.text,
                maxLines: _open ? null : 2,
                overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, height: 1.45, color: c.textSecondary),
              ),
              if (label != null && widget.onAction != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: widget.onAction,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: tone,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 15, color: tone),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
