import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/subject_style.dart';
import '../../../session/domain/session_models.dart';

/// The join code and the session it opens.
///
/// The code used to sit alone in a 74 px panel while the quiz was named only in
/// the header — which scrolls away — and its length and question count lived in
/// a separate amber card. All of it is one card now, and the code is grouped in
/// threes so a host can read it out over the phone.
class JoinCodeCard extends StatelessWidget {
  const JoinCodeCard({super.key, required this.info});

  final SessionInfo info;

  /// Indigo gradient of the web's code panel.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand, AppColors.violet],
  );

  /// `MYJ LOI` — easier to dictate than one run of six characters.
  String get _grouped {
    final code = info.joinCode;
    if (code.length < 6) return code;
    final half = code.length ~/ 2;
    return '${code.substring(0, half)} ${code.substring(half)}';
  }

  /// Same share text as the web share sheet.
  String get _shareText => 'Musobaqa kodingiz: ${info.joinCode}\n'
      'Men sizni "${info.quizName ?? 'Test'}" testiga taklif qilaman!';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: context.colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'MUSOBAQA KODI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _grouped,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Do‘stlaringizga yuboring',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _GlassButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Ulashish',
                onTap: () => Share.share(_shareText),
              ),
              const SizedBox(width: 8),
              _GlassButton(
                icon: Icons.copy_rounded,
                tooltip: 'Kodni nusxalash',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: info.joinCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kod nusxalandi')),
                    );
                  }
                },
              ),
            ],
          ),
          const _Divider(),
          Text(
            info.quizName ?? 'Test',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.subjectName != null)
                _Chip(icon: SubjectStyle.of(info.subjectName).icon, label: info.subjectName!),
              _Chip(icon: Icons.format_list_bulleted_rounded, label: '${info.questionsCount} ta savol'),
              _Chip(icon: Icons.schedule_rounded, label: formatMinutes(info.durationMinutes)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 14),
        color: Colors.white.withValues(alpha: 0.22),
      );
}

/// Translucent square action on the gradient.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// One fact about the session, on the gradient.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white.withValues(alpha: 0.92);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: white),
          ),
        ],
      ),
    );
  }
}
