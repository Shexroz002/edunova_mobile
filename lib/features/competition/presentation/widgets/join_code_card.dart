import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';

/// Join code card, laid out like the web waiting room.
///
/// An indigo gradient panel holds the label and the code; the card body below
/// carries the hint and a full-width copy button. Gradient, wording and layout
/// come from `StudentWaitingRoomPage.tsx`.
class JoinCodeCard extends StatelessWidget {
  const JoinCodeCard({super.key, required this.code, this.quizName});

  final String code;
  final String? quizName;

  /// Indigo gradient of the web's code panel.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFFA78BFA)],
  );

  /// Same share text as the web share sheet.
  String get _shareText =>
      'Musobaqa kodingiz: $code\nMen sizni "${quizName ?? 'Test'}" testiga taklif qilaman!';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: gradient),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Musobaqa kodi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Do'stlaringizni bu kod bilan taklif qiling",
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MutedButton(
                        icon: Icons.copy_rounded,
                        label: 'Kodni nusxalash',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kod nusxalandi!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // No web equivalent, but on a phone a code is far more
                    // useful when it can go straight into a chat app.
                    _MutedButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'Ulashish',
                      onPressed: () => Share.share(_shareText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted filled button used inside the code card.
class _MutedButton extends StatelessWidget {
  const _MutedButton({required this.icon, required this.onPressed, this.label, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = Material(
      color: c.bgInner,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 14 : 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: c.textPrimary),
              if (label != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
