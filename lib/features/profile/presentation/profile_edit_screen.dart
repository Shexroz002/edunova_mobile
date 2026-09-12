import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile_edit.dart';

/// Profile editing, following the web `StudentProfileEditPage.tsx`.
///
/// The web's "Parolni o'zgartirish" card is hidden: there is no endpoint for it
/// (`CLAUDE.md` default decision 5). The web also sends every field on every
/// save; here only what changed is sent.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final AuthUser _user = ref.read(currentUserProvider)!;
  late ProfileForm _initial = ProfileForm(
    firstName: _user.firstName,
    lastName: _user.lastName,
    email: _user.email ?? '',
    phone: _user.phoneNumber ?? '',
    school: _user.schoolName ?? '',
    educationLevel: _user.educationLevel ?? '',
    subjectIds: {for (final subject in _user.subjects) subject.id},
  );

  late ProfileForm _form = _initial;

  late final _firstName = TextEditingController(text: _initial.firstName);
  late final _lastName = TextEditingController(text: _initial.lastName);
  late final _email = TextEditingController(text: _initial.email);
  late final _phone = TextEditingController(text: _initial.phone);
  late final _school = TextEditingController(text: _initial.school);

  bool _saving = false;
  bool _uploading = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  /// Set right after an upload so the new picture shows before `/auth/me/`
  /// comes back.
  File? _localAvatar;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _school.dispose();
    super.dispose();
  }

  bool get _dirty => !ProfilePatch.diff(before: _initial, after: _form).isEmpty;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(_user.id, File(picked.path));
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() => _localAvatar = File(picked.path));
      _toast('Rasm yangilandi');
    } catch (e) {
      if (mounted) _toast(ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final problem = _form.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    // The backend ignores an empty `subject_ids`, so clearing every subject
    // would silently keep the old ones.
    if (_form.subjectIds.isEmpty && _initial.subjectIds.isNotEmpty) {
      setState(() => _error = 'Kamida bitta fan tanlang');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            _user.id,
            ProfilePatch.diff(before: _initial, after: _form),
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      // The form is clean again; the pop waits one frame so `PopScope` has
      // rebuilt with `canPop: true` and does not ask about unsaved changes.
      setState(() => _initial = _form);
      _toast('Profil saqlandi');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    } catch (e) {
      final error = ApiException.from(e);
      if (mounted) {
        setState(() {
          _error = error.message;
          _fieldErrors = error.fieldErrors;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Leaves the screen. Opened deep-linked (a restored route) there is nothing
  /// to pop back to, so the profile tab is restored instead.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.profile);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saqlanmagan oʻzgarishlar'),
        content: const Text('Oʻzgarishlarni saqlamasdan chiqasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Qolish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final padding = context.pagePadding;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) _close();
      },
      child: Scaffold(
        appBar: const PageAppBar(title: Text('Profilni tahrirlash'), showThemeToggle: false),
        body: ListView(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
          children: [
            ContentConstraint(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CompletionBar(
                    percent: _form.completionPercent(
                      hasAvatar: _localAvatar != null || _user.profileImage != null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AvatarCard(
                    user: _user,
                    localAvatar: _localAvatar,
                    uploading: _uploading,
                    onPick: _uploading ? null : _pickAvatar,
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: "Shaxsiy ma'lumotlar",
                    children: [
                      AppTextField(
                        label: 'Ism',
                        icon: Icons.person_outline_rounded,
                        controller: _firstName,
                        errorText: _fieldErrors['first_name'],
                        textInputAction: TextInputAction.next,
                        onChanged: (v) => setState(() => _form = _form.copyWith(firstName: v)),
                      ),
                      AppTextField(
                        label: 'Familiya',
                        icon: Icons.person_outline_rounded,
                        controller: _lastName,
                        errorText: _fieldErrors['last_name'],
                        textInputAction: TextInputAction.next,
                        onChanged: (v) => setState(() => _form = _form.copyWith(lastName: v)),
                      ),
                      AppTextField(
                        label: 'Email',
                        icon: Icons.mail_outline_rounded,
                        controller: _email,
                        errorText: _fieldErrors['email'],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: (v) => setState(() => _form = _form.copyWith(email: v)),
                      ),
                      AppTextField(
                        label: 'Telefon',
                        hint: '+998 XX XXX XX XX',
                        icon: Icons.phone_outlined,
                        controller: _phone,
                        errorText: _fieldErrors['phone_number'],
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        onChanged: (v) => setState(() => _form = _form.copyWith(phone: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: "Ta'lim",
                    children: [
                      AppTextField(
                        label: 'Maktab / Muassasa',
                        icon: Icons.apartment_rounded,
                        controller: _school,
                        errorText: _fieldErrors['school_name'],
                        textInputAction: TextInputAction.done,
                        onChanged: (v) => setState(() => _form = _form.copyWith(school: v)),
                      ),
                      _LevelPicker(
                        value: _form.educationLevel,
                        onChanged: (v) => setState(() => _form = _form.copyWith(educationLevel: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SubjectsPicker(
                    selected: _form.subjectIds,
                    onToggle: (id) {
                      final next = Set<int>.from(_form.subjectIds);
                      next.contains(id) ? next.remove(id) : next.add(id);
                      setState(() => _form = _form.copyWith(subjectIds: next));
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 13, color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Saqlash',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    enabled: _dirty,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (await _confirmDiscard() && context.mounted) {
                              _close();
                            }
                          },
                    style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                    child: const Text('Bekor qilish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Profil to'ldirish" progress bar from the web.
class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (percent >= 100) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(AppColors.brand, 0x33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Profil to'ldirish",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: AppColors.tint(AppColors.brand, 0x26),
              valueColor: const AlwaysStoppedAnimation(AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar with the gradient camera button from the web.
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.user,
    required this.localAvatar,
    required this.uploading,
    required this.onPick,
  });

  final AuthUser user;
  final File? localAvatar;
  final bool uploading;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (localAvatar != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(localAvatar!, width: 84, height: 84, fit: BoxFit.cover),
                )
              else
                UserAvatar(name: user.fullName, imageUrl: user.profileImage, size: 84),
              Positioned(
                right: -6,
                bottom: -6,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: GradientButton.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: onPick,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: uploading
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.photo_camera_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                Text(
                  'JPG, PNG yoki WEBP',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Titled card wrapping a group of fields.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// "Sinf" dropdown over the backend's `EducationLevel` values.
class _LevelPicker extends StatelessWidget {
  const _LevelPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.school_outlined, size: 15, color: c.textMuted),
            const SizedBox(width: 6),
            Text(
              'Sinf',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text('Tanlanmagan', style: TextStyle(fontSize: 14, color: c.textMuted)),
          dropdownColor: c.bgCard,
          decoration: InputDecoration(
            filled: true,
            fillColor: c.bgInner,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
          ),
          items: [
            for (final level in educationLevels)
              DropdownMenuItem(
                value: level,
                child: Text(
                  level,
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                ),
              ),
          ],
          onChanged: (selected) => onChanged(selected ?? ''),
        ),
      ],
    );
  }
}

/// "Fanlar" chips, toggled on tap like the web grid.
class _SubjectsPicker extends ConsumerWidget {
  const _SubjectsPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final subjects = ref.watch(subjectsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text(
                'Fanlar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Qiziqadigan fanlaringizni tanlang',
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
          const SizedBox(height: 12),
          subjects.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              ApiException.from(e).message,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            data: (items) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subject in items)
                  _SubjectChip(
                    label: subject.displayName,
                    selected: selected.contains(subject.id),
                    onTap: () => onToggle(subject.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: selected ? c.accentMuted : c.bgInner,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.tint(AppColors.brand, 0x66) : c.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? c.accent : c.textSecondary,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_rounded, size: 16, color: c.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
