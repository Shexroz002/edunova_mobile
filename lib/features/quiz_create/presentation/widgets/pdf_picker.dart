import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/quiz_job.dart';

/// Drop zone equivalent: an empty state that picks a file, and a chosen-file
/// state with its name, size and a remove button.
class PdfPicker extends StatelessWidget {
  const PdfPicker({super.key, required this.file, required this.onPick, required this.onClear});

  final File? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  /// `1.2 MB`, like the web's `(size / 1024 / 1024).toFixed(2)`.
  static String formatSize(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chosen = file;
    final tooBig = chosen != null && chosen.lengthSync() > CreateLimits.maxPdfBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF fayl *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        Material(
          color: c.bgInner,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPick,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tooBig
                      ? AppColors.error
                      : chosen != null
                          ? AppColors.tint(AppColors.success, 0x66)
                          : c.border,
                  width: 1.5,
                ),
              ),
              child: chosen == null ? _empty(context) : _chosen(context, chosen, tooBig),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.tint(AppColors.sky),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.upload_file_rounded, size: 26, color: AppColors.sky),
        ),
        const SizedBox(height: 12),
        Text(
          'PDF faylni yuklang',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Tanlash uchun bosing',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
        const SizedBox(height: 6),
        // The web promises 10 MB; the backend refuses anything over 5.
        Text('Maksimal: 5 MB', style: TextStyle(fontSize: 12, color: c.textMuted)),
      ],
    );
  }

  Widget _chosen(BuildContext context, File chosen, bool tooBig) {
    final c = context.colors;
    final size = chosen.lengthSync();

    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.tint(tooBig ? AppColors.error : AppColors.success),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.picture_as_pdf_rounded,
            size: 26,
            color: tooBig ? AppColors.error : AppColors.success,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          chosen.uri.pathSegments.last,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          tooBig ? '${formatSize(size)} — 5 MB dan katta' : formatSize(size),
          style: TextStyle(
            fontSize: 12,
            color: tooBig ? AppColors.error : c.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: onClear,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 17),
          label: const Text("O'chirish"),
        ),
      ],
    );
  }
}
