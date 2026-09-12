import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../../session/domain/session_models.dart';
import '../domain/group_models.dart';

/// Builds the PDF of a group session result.
///
/// Kept free of Flutter widgets so it can be unit-tested: it takes the same
/// data the screen shows and returns the bytes to share or print.
class SessionResultPdf {
  const SessionResultPdf._();

  /// Header, summary numbers, the ranking table and per-question accuracy.
  static Future<Uint8List> build({
    required String groupName,
    required GroupSessionResult result,
    required List<LeaderboardEntry> leaderboard,
    required List<QuestionAccuracy> accuracy,
  }) async {
    final document = pw.Document();
    final date = result.date;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            result.quizName,
            style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            [
              groupName,
              if (result.subject != null) result.subject!,
              if (date != null) formatDateTime(date),
            ].join(' · '),
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          _summary(result),
          pw.SizedBox(height: 20),
          pw.Text(
            'Reyting jadvali',
            style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _leaderboardTable(leaderboard),
          if (accuracy.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Savol aniqligi',
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _accuracyTable(accuracy),
          ],
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'EduNova · ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return document.save();
  }

  static pw.Widget _summary(GroupSessionResult result) {
    final cells = <List<String>>[
      ["O'rtacha ball", formatPercent(result.averageScore)],
      ['Eng yuqori ball', formatPercent(result.highestScore)],
      ['Eng past ball', formatPercent(result.lowestScore)],
      ["Ishtirokchilar", '${result.participantsCount} ta'],
      ['Davomiyligi', formatMinutes(result.durationMinutes)],
      if (result.hardestQuestionNumber != null)
        [
          'Qiyin savol',
          'Q${result.hardestQuestionNumber}'
              '${result.hardestQuestionAccuracy == null ? '' : ' (${formatPercent(result.hardestQuestionAccuracy!)})'}',
        ],
    ];

    return pw.Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final cell in cells)
          pw.Container(
            width: 155,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(cell[0], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(
                  cell[1],
                  style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _leaderboardTable(List<LeaderboardEntry> entries) {
    return pw.TableHelper.fromTextArray(
      headers: const ["#", "O'quvchi", 'Ball', "To'g'ri", 'Vaqt'],
      headerStyle: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
      data: [
        for (final entry in entries)
          [
            '${entry.rank}',
            entry.fullName,
            formatPercent(entry.percent),
            '${entry.score ?? 0}/${entry.totalQuestions ?? 0}',
            formatSeconds(entry.spendSeconds),
          ],
      ],
    );
  }

  static pw.Widget _accuracyTable(List<QuestionAccuracy> accuracy) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Savol', "To'g'ri", 'Jami', 'Aniqlik', 'Daraja'],
      headerStyle: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
      data: [
        for (final question in accuracy)
          [
            'Q${question.number}',
            '${question.correctAnswers}',
            '${question.totalAnswers}',
            formatPercent(question.accuracyPercent),
            question.band.label,
          ],
      ],
    );
  }
}
