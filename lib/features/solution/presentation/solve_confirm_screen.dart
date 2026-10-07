import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../data/solution_repository.dart';
import 'solve_home_screen.dart';
import 'widgets/solution_tex.dart';
import 'widgets/step_card.dart';

/// "Shu masalami?" — the text is confirmed before anything is solved.
///
/// If a photo is misread (5 instead of −5), the model solves a *different*
/// problem perfectly and the student never notices. This screen is the only
/// place that silent mistake can be caught, so it comes before solving.
class SolveConfirmScreen extends ConsumerStatefulWidget {
  const SolveConfirmScreen({super.key, required this.draft});

  final SolveDraft draft;

  @override
  ConsumerState<SolveConfirmScreen> createState() => _SolveConfirmScreenState();
}

class _SolveConfirmScreenState extends ConsumerState<SolveConfirmScreen> {
  late final TextEditingController _text;
  late String _subject;
  late bool _editing;
  bool _sending = false;

  bool get _fromPhoto => widget.draft.recognized != null;

  @override
  void initState() {
    super.initState();
    final recognized = widget.draft.recognized;
    _text = TextEditingController(text: recognized?.text ?? '');
    _subject = widget.draft.subject == 'fizika' ? 'fizika' : 'matematika';
    // Typed problems start in the editor; a readable photo starts as a preview,
    // because raw LaTeX in a text box is unreadable for a student.
    _editing = !_fromPhoto || !(recognized?.readable ?? false);
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _solve() async {
    final text = _text.text.trim();
    if (text.length < 5 || _sending) return;
    setState(() => _sending = true);
    try {
      final item = await ref.read(solutionRepositoryProvider).submit(
            requestId: widget.draft.recognized?.requestId,
            text: text,
            subject: _subject,
          );
      ref
        ..invalidate(solveQuotaProvider)
        ..invalidate(solveHistoryProvider);
      if (!mounted) return;
      context.pushReplacement(Routes.solveRequestPath(item.id));
    } on ApiException catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('Yuborib bo‘lmadi. Internetni tekshiring.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final recognized = widget.draft.recognized;
    final ready = _text.text.trim().length >= 5;

    return Scaffold(
      appBar: PageAppBar(
        title: Text(_fromPhoto ? 'Masalani tekshiring' : 'Masalani yozing'),
        showFriends: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                if (widget.draft.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Image.file(File(widget.draft.imagePath!), fit: BoxFit.contain),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Qayta olish'),
                    ),
                  ),
                ],
                if (recognized != null && !recognized.readable)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SolutionNote(
                      icon: '📷',
                      text: 'Rasmni o‘qib bo‘lmadi. Masalani o‘zingiz yozing yoki qayta rasmga oling.',
                      tone: AppColors.warning,
                    ),
                  ),
                if (recognized != null && recognized.multiple)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SolutionNote(
                      icon: 'ℹ️',
                      text: 'Rasmda bir nechta masala bor edi — eng to‘liq ko‘ringani olindi.',
                      tone: AppColors.brand,
                    ),
                  ),
                Text(
                  (_fromPhoto ? 'Ilova shunday o‘qidi' : 'Masala matni').toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                if (_editing)
                  TextField(
                    controller: _text,
                    autofocus: !_fromPhoto,
                    minLines: 4,
                    maxLines: 10,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Masalan: 2x² − 5x − 3 = 0 tenglamani yeching',
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
                    decoration: BoxDecoration(
                      color: c.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.readable(AppColors.brand), width: 1.6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProseMath(_text.text),
                        TextButton.icon(
                          onPressed: () => setState(() => _editing = true),
                          style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Tahrirlash'),
                        ),
                      ],
                    ),
                  ),
                if (_fromPhoto) ...[
                  const SizedBox(height: 10),
                  const SolutionNote(
                    icon: '🔎',
                    text: 'Bir belgi xato o‘qilsa, butun yechim boshqa masalaga bo‘ladi. Iltimos, rasm bilan solishtirib ko‘ring.',
                    tone: AppColors.warning,
                  ),
                ],
                const SizedBox(height: 16),
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
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: c.bgBase, border: Border(top: BorderSide(color: c.border))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: GradientButton(
                  label: _fromPhoto ? 'Ha, yechib ber' : 'Yechib ber',
                  height: 52,
                  enabled: ready,
                  loading: _sending,
                  onPressed: _solve,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
