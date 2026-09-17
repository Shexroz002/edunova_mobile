import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Two-step student registration: personal info → subjects (at least 2).
///
/// The role is always `schoolboy`; teachers register on the web.
///
/// The form is built for a pupil on a phone: it asks for as little as it can,
/// shapes the username while it is typed instead of rejecting it afterwards,
/// and only turns red once — after that every field re-checks itself on each
/// keystroke, so a fixed mistake clears immediately.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _minSubjects = 2;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  /// Ordered the way the form reads, so a failed submit can land the caret on
  /// the first thing that needs fixing instead of leaving the pupil to hunt.
  late final _focus = <String, FocusNode>{
    'first_name': FocusNode(),
    'last_name': FocusNode(),
    'username': FocusNode(),
    'password': FocusNode(),
  };

  int _step = 1;
  final Set<int> _selectedSubjects = {};
  Map<String, String> _errors = {};
  String? _submitError;
  bool _loading = false;

  /// True once "Keyingi" has been pressed. Before that the form stays quiet;
  /// after it, every keystroke re-checks so a corrected field clears at once
  /// instead of staying red until the next submit.
  bool _attempted = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _username, _password]) {
      c.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// The username the server will actually store: it lowercases on its side,
  /// so the field does the same and the pupil sees what they will get.
  static final _usernameFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    // Length-preserving, so the caret never jumps.
    TextInputFormatter.withFunction(
      (_, next) => TextEditingValue(text: next.text.toLowerCase(), selection: next.selection),
    ),
  ];

  /// Re-runs validation while the user types, but only after a failed attempt.
  void _revalidate() {
    if (_attempted) _validateStep1();
  }

  /// Mirrors web + backend rules: names 2..50, username 3..30 without spaces, password ≥ 8.
  bool _validateStep1() {
    final errors = <String, String>{};
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final username = _username.text.trim();

    if (first.length < 2) errors['first_name'] = "Ism kamida 2 ta harf bo'lsin";
    if (last.length < 2) errors['last_name'] = "Familiya kamida 2 ta harf bo'lsin";
    if (username.isEmpty) {
      errors['username'] = 'Foydalanuvchi nomi kiritilmadi';
    } else if (username.contains(' ')) {
      errors['username'] = "Bo'sh joy bo'lmasin";
    } else if (username.length < 3 || username.length > 30) {
      errors['username'] = "3 tadan 30 tagacha belgi bo'lsin";
    }
    if (_password.text.length < 8) errors['password'] = "Kamida 8 ta belgi bo'lsin";

    setState(() => _errors = errors);
    return errors.isEmpty;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    if (_validateStep1()) {
      setState(() {
        _step = 2;
        _submitError = null;
      });
      return;
    }
    // Point at the first problem rather than showing four and walking away.
    for (final field in _focus.keys) {
      if (_errors.containsKey(field)) {
        _focus[field]!.requestFocus();
        return;
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedSubjects.length < _minSubjects) {
      setState(() => _submitError = 'Kamida $_minSubjects ta fan tanlang');
      return;
    }

    setState(() {
      _loading = true;
      _submitError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            RegisterRequest(
              username: _username.text,
              password: _password.text,
              firstName: _firstName.text,
              lastName: _lastName.text,
              subjectIds: _selectedSubjects.toList(),
            ),
          );
      // Router redirects to home once the session is authenticated.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        // Field errors belong to step 1 — send the user back there.
        const step1Fields = {'username', 'password', 'first_name', 'last_name'};
        final step1Errors = {
          for (final entry in e.fieldErrors.entries)
            if (step1Fields.contains(entry.key)) entry.key: entry.value,
        };
        if (e.message == 'Bu foydalanuvchi nomi band') step1Errors['username'] = e.message;
        if (step1Errors.isNotEmpty) {
          _errors = step1Errors;
          _step = 1;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AuthScaffold(
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(title: "Ro'yxatdan o'tish", subtitle: "O'quvchi hisobini yarating"),
          const SizedBox(height: 20),
          _StepIndicator(current: _step),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _step == 1 ? _buildStep1() : _buildStep2(),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(_submitError!),
          ],
          const SizedBox(height: 24),
          if (_step == 1)
            PrimaryButton(label: 'Keyingi', icon: Icons.arrow_forward_rounded, onPressed: _next)
          else ...[
            PrimaryButton(
              label: "Ro'yxatdan o'tish",
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            Align(
              child: TextButton.icon(
                onPressed: _loading ? null : () => setState(() => _step = 1),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Orqaga', maxLines: 1),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.textSecondary,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text('Hisobingiz bormi? ', style: TextStyle(color: c.textMuted, fontSize: 13)),
              GestureDetector(
                onTap: _loading ? null : () => context.go('/login'),
                child: const Text(
                  'Kirish',
                  style:
                      TextStyle(color: AppColors.brand, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Ism',
                hint: 'Ismingiz',
                controller: _firstName,
                focusNode: _focus['first_name'],
                errorText: _errors['first_name'],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                onChanged: (_) => _revalidate(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Familiya',
                hint: 'Familiyangiz',
                controller: _lastName,
                focusNode: _focus['last_name'],
                errorText: _errors['last_name'],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                onChanged: (_) => _revalidate(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Foydalanuvchi nomi',
          hint: 'masalan: ali_valiyev',
          icon: Icons.alternate_email_rounded,
          controller: _username,
          focusNode: _focus['username'],
          errorText: _errors['username'],
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newUsername],
          inputFormatters: _usernameFormatters,
          onChanged: (_) => _revalidate(),
        ),
        if (_errors['username'] == null)
          const _FieldHint('Kirish uchun ishlatasiz. Kichik harf, raqam va _ belgisi.'),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Parol',
          hint: 'Kamida 8 belgi',
          icon: Icons.lock_outline_rounded,
          controller: _password,
          focusNode: _focus['password'],
          isPassword: true,
          errorText: _errors['password'],
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(_revalidate),
          onSubmitted: (_) => _next(),
        ),
        if (_errors['password'] == null)
          _FieldHint(
            _password.text.length >= 8
                ? "Parol yetarli uzunlikda"
                : "Kamida 8 ta belgi — ko'zcha bilan tekshirib oling",
            ok: _password.text.length >= 8,
          ),
      ],
    );
  }

  Widget _buildStep2() {
    final c = context.colors;
    final subjects = ref.watch(subjectsProvider);

    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Qaysi fanlarni o'rganasiz? Kamida $_minSubjects ta tanlang.",
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        // Green only once the minimum is met: "0 ta tanlandi" in success green
        // read as if the step were already done.
        Text(
          '${_selectedSubjects.length} / $_minSubjects ta tanlandi',
          style: TextStyle(
            color: _selectedSubjects.length >= _minSubjects ? AppColors.success : c.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        subjects.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: LoadingView(),
          ),
          error: (e, _) => ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(subjectsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyView(icon: Icons.menu_book_outlined, title: 'Fanlar topilmadi')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in items)
                      _SubjectChip(
                        subject: subject,
                        selected: _selectedSubjects.contains(subject.id),
                        onTap: () => setState(() {
                          _submitError = null;
                          if (!_selectedSubjects.remove(subject.id)) {
                            _selectedSubjects.add(subject.id);
                          }
                        }),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Guidance under a field — shown instead of an error, never beside one.
class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text, {this.ok = false});

  final String text;

  /// Turns the line green once the rule it describes is satisfied.
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 13,
            color: ok ? AppColors.success : c.textMuted,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: ok ? AppColors.success : c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.subject, required this.selected, required this.onTap});

  final Subject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = subject.icon;
    // Icons are short emoji strings; ignore anything longer (icon keys, urls).
    final emoji = (icon != null && icon.runes.length <= 2) ? icon : null;

    return Material(
      color: selected ? const Color(0x1A22C55E) : c.bgInner,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? const Color(0x8022C55E) : c.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6)
              ],
              // "Ona tili va adabiyoti" is wider than a phone row on its own.
              Flexible(
                child: Text(
                  subject.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.success : c.textPrimary,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  static const _labels = ["Ma'lumotlar", 'Fanlar'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: current > i ? AppColors.brand : c.border,
              ),
            ),
          Flexible(
            child: _StepDot(
              index: i + 1,
              label: i + 1 == current ? _labels[i] : null,
              current: current,
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.label, required this.current});

  final int index;

  /// Shown for the current step only, so the row fits at any text scale.
  final String? label;
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = index < current;
    final active = index == current;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? AppColors.brand : c.bgInner,
            border: Border.all(color: done || active ? AppColors.brand : c.border),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : c.textMuted,
                  ),
                ),
        ),
        if (label != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? c.textPrimary : c.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
