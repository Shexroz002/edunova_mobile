import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../data/solution_repository.dart';
import '../domain/solution_models.dart';
import 'widgets/tex_prose.dart';

/// "Masala yechish": photograph or type a problem, see recent ones.
///
/// The photo is the main way in: typing fractions, roots and powers on a
/// phone is hard, and the problem is usually in a textbook already.
class SolveHomeScreen extends ConsumerStatefulWidget {
  const SolveHomeScreen({super.key});

  @override
  ConsumerState<SolveHomeScreen> createState() => _SolveHomeScreenState();
}

class _SolveHomeScreenState extends ConsumerState<SolveHomeScreen> {
  String _subject = 'matematika';
  bool _reading = false;

  Future<void> _photo(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1800, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _reading = true);
    try {
      final file = File(picked.path);
      final result = await ref.read(solutionRepositoryProvider).recognize(file);
      ref.invalidate(solveQuotaProvider);
      if (!mounted) return;
      context.push(
        Routes.solveConfirm,
        extra: SolveDraft(recognized: result, imagePath: file.path, subject: result.subject),
      );
    } on ApiException catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('Rasmni yuborib bo‘lmadi. Internetni tekshiring.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _type() => context.push(Routes.solveConfirm, extra: SolveDraft(subject: _subject));

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quota = ref.watch(solveQuotaProvider).valueOrNull;
    final history = ref.watch(solveHistoryProvider);
    final blocked = quota != null && quota.left <= 0;

    return Scaffold(
      appBar: const PageAppBar(title: Text('Masala yechish'), showFriends: false),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(solveQuotaProvider);
          ref.invalidate(solveHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _CameraCard(
              busy: _reading,
              enabled: !blocked,
              onCamera: () => _photo(ImageSource.camera),
              onGallery: () => _photo(ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            _TypeCard(enabled: !blocked && !_reading, onTap: _type),
            const SizedBox(height: 18),
            const _Section('Fan'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in const [('matematika', 'Matematika'), ('fizika', 'Fizika')])
                  ChoiceChip(
                    label: Text(label),
                    selected: _subject == value,
                    onSelected: (_) => setState(() => _subject = value),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            history.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Section('Oxirgi yechimlar'),
                        const SizedBox(height: 8),
                        for (final item in items.take(8)) _HistoryRow(item: item),
                      ],
                    ),
            ),
            if (quota != null) ...[
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                  children: blocked
                      ? const [TextSpan(text: 'Bugungi limit tugadi. Ertaga yana masala yechish mumkin.')]
                      : [
                          const TextSpan(text: 'Bugun yana '),
                          TextSpan(
                            text: '${quota.left} ta',
                            style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary),
                          ),
                          const TextSpan(text: ' masala yechish mumkin'),
                        ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The problem on its way to the confirm screen: read from a photo, or empty.
class SolveDraft {
  const SolveDraft({this.recognized, this.imagePath, required this.subject});

  final RecognizeResult? recognized;
  final String? imagePath;
  final String subject;
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.busy, required this.enabled, required this.onCamera, required this.onGallery});

  final bool busy;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: AppColors.tint(AppColors.brand, 0x1F),
      child: InkWell(
        onTap: enabled && !busy ? onCamera : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.tint(AppColors.brand, 0x66)),
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [AppColors.brand, AppColors.violet]),
                ),
                child: busy
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                busy ? 'Rasm o‘qilmoqda…' : 'Masalani rasmga oling',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
              ),
              const SizedBox(height: 3),
              Text('Darslik, daftar yoki ekrandan', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: enabled && !busy ? onGallery : null,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Galereyadan tanlash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(c.textMuted, 0x24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.keyboard_alt_outlined, size: 20, color: c.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Yozib kiritish', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    Text('Qisqa masalalar uchun', style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final SolveRequestItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, tone) = switch (item.status) {
      SolveStatus.done => ('yechildi', AppColors.success),
      SolveStatus.failed => ('yechilmadi', AppColors.error),
      SolveStatus.pending => ('yechilmoqda', AppColors.brand),
      SolveStatus.recognized => ('yuborilmagan', AppColors.warning),
    };
    final when = item.createdAt == null ? '' : ' · ${formatRelativeShort(item.createdAt!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.status == SolveStatus.recognized ? null : () => context.push(Routes.solveRequestPath(item.id)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texPreview(item.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                    children: [
                      TextSpan(text: item.subject == 'fizika' ? 'Fizika' : 'Matematika'),
                      TextSpan(text: '$when · '),
                      TextSpan(
                        text: label,
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.readable(tone)),
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

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.colors.textMuted,
        ),
      );
}
