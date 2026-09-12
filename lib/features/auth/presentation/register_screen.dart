import 'package:flutter/material.dart';
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
  final _confirm = TextEditingController();

  int _step = 1;
  final Set<int> _selectedSubjects = {};
  Map<String, String> _errors = {};
  String? _submitError;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
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
    if (_confirm.text != _password.text) errors['confirm'] = 'Parollar mos kelmadi';

    setState(() => _errors = errors);
    return errors.isEmpty;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_validateStep1()) {
      setState(() {
        _step = 2;
        _submitError = null;
      });
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
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => setState(() => _step = 1),
                    child: const Text('Orqaga'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: "Ro'yxatdan o'tish",
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
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
                errorText: _errors['first_name'],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Familiya',
                hint: 'Familiyangiz',
                controller: _lastName,
                errorText: _errors['last_name'],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Foydalanuvchi nomi',
          hint: 'username',
          icon: Icons.alternate_email_rounded,
          controller: _username,
          errorText: _errors['username'],
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newUsername],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Parol',
          hint: 'Kamida 8 belgi',
          icon: Icons.lock_outline_rounded,
          controller: _password,
          isPassword: true,
          errorText: _errors['password'],
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Parolni tasdiqlang',
          hint: 'Parolni qayta kiriting',
          icon: Icons.lock_outline_rounded,
          controller: _confirm,
          isPassword: true,
          errorText: _errors['confirm'],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
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
        Text(
          '${_selectedSubjects.length} ta tanlandi',
          style:
              const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6)
              ],
              Text(
                subject.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.success : c.textPrimary,
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

  static const _labels = ["Shaxsiy ma'lumotlar", 'Fanlar'];

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
          _StepDot(index: i + 1, label: _labels[i], current: current),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.label, required this.current});

  final int index;
  final String label;
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
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? c.textPrimary : c.textMuted,
          ),
        ),
      ],
    );
  }
}
