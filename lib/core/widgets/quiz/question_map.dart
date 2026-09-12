import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Status of a cell in the question map.
enum MapCellStatus { unanswered, answered, correct, wrong }

/// Grid of question numbers colored by status; the current one is outlined.
class QuestionMapGrid extends StatelessWidget {
  const QuestionMapGrid({
    super.key,
    required this.count,
    required this.current,
    required this.statusOf,
    required this.onTap,
  });

  final int count;

  /// Index of the question on screen (outlined).
  final int current;
  final MapCellStatus Function(int index) statusOf;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < count; i++) _cell(c, i),
      ],
    );
  }

  Widget _cell(AppColors c, int index) {
    final status = statusOf(index);
    final color = switch (status) {
      MapCellStatus.unanswered => null,
      MapCellStatus.answered => AppColors.brand,
      MapCellStatus.correct => AppColors.success,
      MapCellStatus.wrong => AppColors.error,
    };
    final isCurrent = index == current;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(index),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color == null ? c.bgInner : AppColors.tint(color, 0x33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent ? c.textPrimary : (color ?? c.border),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(fontWeight: FontWeight.w700, color: color ?? c.textSecondary),
        ),
      ),
    );
  }
}

/// A legend row item: colored square + label.
class MapLegendItem extends StatelessWidget {
  const MapLegendItem({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
      ],
    );
  }
}

/// Opens the question map in a bottom sheet (phones).
Future<void> showQuestionMapSheet({
  required BuildContext context,
  required String title,
  required Widget grid,
  List<Widget> legend = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
              ),
              if (legend.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 6, children: legend),
              ],
              const SizedBox(height: 16),
              grid,
            ],
          ),
        ),
      ),
    ),
  );
}
