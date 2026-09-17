import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/quiz_job.dart';

/// Picks the PDF a quiz is built from.
///
/// The two rules that decide whether a file works — selectable text, 5 MB —
/// are stated **before** the pick. They used to surface only as small print and
/// as a failure two minutes into generation.
class PdfPicker extends StatelessWidget {
  const PdfPicker({
    super.key,
    required this.file,
    required this.bytes,
    required this.onPick,
    required this.onClear,
  });

  final File? file;

  /// Size of [file], read once at pick time.
  final int? bytes;

  final VoidCallback onPick;
  final VoidCallback onClear;

  /// `1.20 MB`, like the web's `(size / 1024 / 1024).toFixed(2)`.
  static String formatSize(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chosen = file;
    final size = bytes ?? chosen?.lengthSync();
    final tooBig = size != null && size > CreateLimits.maxPdfBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF fayl *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
        const SizedBox(height: 8),
        if (chosen == null)
          _Empty(onPick: onPick)
        else
          _Chosen(
            name: chosen.uri.pathSegments.last,
            size: size == null ? '' : formatSize(size),
            tooBig: tooBig,
            onClear: onClear,
          ),
      ],
    );
  }
}

/// Drop zone with the two requirements spelled out.
class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});

  final VoidCallback onPick;

  static const _requirements = [
    'Matn tanlanadigan PDF bo‘lsin',
    'Hajmi 5 MB dan oshmasin',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = context.readable(AppColors.blue);

    return Material(
      color: c.bgInner,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: CustomPaint(
          painter: _DashedBorder(color: c.border, radius: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.tint(accent, 0x24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.tint(accent, 0x4D)),
                  ),
                  child: Icon(Icons.upload_file_rounded, size: 26, color: accent),
                ),
                const SizedBox(height: 12),
                Text(
                  'PDF faylni tanlang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Telefoningizdagi fayllardan',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 12),
                for (final requirement in _requirements)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        // Flexible, so a long requirement wraps instead of
                        // overflowing a narrow card or a large font scale.
                        Flexible(
                          child: Text(
                            requirement,
                            style: TextStyle(fontSize: 12, height: 1.35, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picked file, or the reason it will not do.
class _Chosen extends StatelessWidget {
  const _Chosen({
    required this.name,
    required this.size,
    required this.tooBig,
    required this.onClear,
  });

  final String name;
  final String size;
  final bool tooBig;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = context.readable(tooBig ? AppColors.error : AppColors.emerald);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tint(tone, 0x80), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tint(tone, 0x29),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.tint(tone, 0x57)),
            ),
            child: Icon(Icons.picture_as_pdf_rounded, size: 21, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  tooBig ? '$size — 5 MB dan katta' : size,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: tooBig ? FontWeight.w600 : FontWeight.w400,
                    color: tooBig ? tone : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onClear,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed rounded outline, which Flutter has no border side for.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const width = 1.5;
  static const dash = 7.0;
  static const gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(width / 2),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (final metric in outline.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + dash, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
