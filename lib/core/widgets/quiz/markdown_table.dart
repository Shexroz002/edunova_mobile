import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'math_text.dart';

/// Renders a pipe-style markdown table (`| a | b |`) from `table_markdown`.
///
/// The first row is the header; separator rows (`| --- |`) are skipped.
/// Wide tables scroll horizontally.
class MarkdownTable extends StatelessWidget {
  const MarkdownTable(this.markdown, {super.key});

  final String markdown;

  /// Parses the table into rows of cells; returns an empty list if nothing is found.
  static List<List<String>> parse(String markdown) {
    final separator = RegExp(r'^:?-{2,}:?$');
    final rows = <List<String>>[];
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trim();
      if (!line.contains('|')) continue;
      final trimmed = line.replaceFirst(RegExp(r'^\|'), '').replaceFirst(RegExp(r'\|$'), '');
      final cells = trimmed.split('|').map((c) => c.trim()).toList();
      if (cells.every((c) => separator.hasMatch(c) || c.isEmpty)) continue;
      rows.add(cells);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = parse(markdown);
    if (rows.isEmpty) return const SizedBox.shrink();

    final c = context.colors;
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    TableRow buildRow(List<String> cells, {bool header = false}) => TableRow(
          decoration: BoxDecoration(color: header ? c.accentMuted : c.bgCard),
          children: [
            for (var i = 0; i < columns; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: MathText(
                  i < cells.length ? cells[i] : '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: header ? FontWeight.w700 : FontWeight.w400,
                    color: c.textPrimary,
                  ),
                ),
              ),
          ],
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: c.border),
          children: [
            buildRow(rows.first, header: true),
            for (final row in rows.skip(1)) buildRow(row),
          ],
        ),
      ),
    );
  }
}
