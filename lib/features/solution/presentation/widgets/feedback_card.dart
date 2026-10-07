import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "Tushunarli bo'ldimi?" — the only measure of a solution's quality we have.
///
/// [onSend] gets `helpful`, `unclear` or `wrong`. A solution can be right and
/// still unclear; only the student can say so.
class FeedbackCard extends StatefulWidget {
  const FeedbackCard({super.key, required this.onSend});

  final Future<void> Function(String verdict) onSend;

  @override
  State<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<FeedbackCard> {
  String? _sent;
  bool _busy = false;

  Future<void> _send(String verdict) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSend(verdict);
      if (mounted) setState(() => _sent = verdict);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fikr yuborilmadi. Internetni tekshiring.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_sent != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Text(
          _sent == 'wrong' ? 'Rahmat! Yechim tekshiruvga yuborildi.' : 'Rahmat! Fikringiz yechimni yaxshilashga yordam beradi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: c.textSecondary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          const Text('Tushunarli bo‘ldimi?', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Choice(label: '👍 Ha', onTap: _busy ? null : () => _send('helpful'))),
              const SizedBox(width: 9),
              Expanded(child: _Choice(label: '🤔 Unchalik', onTap: _busy ? null : () => _send('unclear'))),
            ],
          ),
          TextButton(
            onPressed: _busy ? null : () => _send('wrong'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text.rich(
              TextSpan(
                text: 'Xato ko‘rdingizmi? ',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
                children: [
                  TextSpan(
                    text: 'Xabar berish',
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.readable(AppColors.error)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: BorderSide(color: context.colors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: context.colors.textPrimary,
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}
