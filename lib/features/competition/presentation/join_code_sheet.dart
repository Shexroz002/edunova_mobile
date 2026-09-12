import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/competition_repository.dart';

/// Length of a backend join code (`generate_join_code` uses 6 characters).
const kJoinCodeLength = 6;

/// Asks for a session code, joins, and returns the session id
/// (null if the sheet was dismissed).
Future<int?> showJoinCodeSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => const _JoinCodeSheet(),
  );
}

class _JoinCodeSheet extends ConsumerStatefulWidget {
  const _JoinCodeSheet();

  @override
  ConsumerState<_JoinCodeSheet> createState() => _JoinCodeSheetState();
}

class _JoinCodeSheetState extends ConsumerState<_JoinCodeSheet> {
  final _controller = TextEditingController();
  bool _joining = false;
  String? _error;

  bool get _isComplete => _controller.text.length == kJoinCodeLength;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final sessionId = await ref.read(competitionRepositoryProvider).joinByCode(_controller.text);
      if (mounted) Navigator.of(context).pop(sessionId);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Jonli sessiyaga qo‘shilish',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '$kJoinCodeLength belgili qo‘shilish kodini kiriting',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_joining,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: kJoinCodeLength,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _isComplete ? _join() : null,
              onChanged: (_) => setState(() => _error = null),
              inputFormatters: [
                // The backend compares codes case-sensitively and only ever
                // generates A–Z and 0–9, so anything else is dropped and the
                // rest is uppercased as the student types.
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                TextInputFormatter.withFunction(
                  (_, next) => next.copyWith(text: next.text.toUpperCase()),
                ),
              ],
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                hintStyle: TextStyle(color: c.textMuted, letterSpacing: 10),
                filled: true,
                fillColor: c.bgInner,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                ),
              ),
            ),
            Text(
              'Kodda katta harflar va raqamlar bo‘ladi. 0 va O, 1 va I ni adashtirmang.',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Qo‘shilish',
              icon: Icons.login_rounded,
              loading: _joining,
              onPressed: _isComplete ? _join : null,
            ),
          ],
        ),
      ),
    );
  }
}
