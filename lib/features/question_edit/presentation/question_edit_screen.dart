import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/difficulty.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/quiz/math_text.dart';
import '../../../core/widgets/quiz/option_tile.dart';
import '../../../core/widgets/quiz/question_view.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../tests/data/tests_repository.dart';
import '../../tests/domain/quiz.dart';
import '../data/question_edit_repository.dart';
import '../domain/question_patch.dart';

/// Loads one question for editing; kept apart from the read-only preview
/// provider so saving can refresh just this screen.
final editableQuestionProvider = FutureProvider.autoDispose.family<QuestionContent, int>(
  (ref, questionId) => ref.watch(testsRepositoryProvider).fetchQuestion(questionId),
);

/// Student question editor.
///
/// `CLAUDE.md` default decision 6 designs it tablet-first: on a wide screen the
/// form and a live preview sit side by side; a phone gets the same fields in
/// one column, with the preview below.
///
/// Only what the API supports is editable — question text, topic, difficulty,
/// the correct option and the images. Option **text** has no endpoint.
class QuestionEditScreen extends ConsumerWidget {
  const QuestionEditScreen({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(editableQuestionProvider(questionId));

    return Scaffold(
      appBar: const PageAppBar(title: Text('Savolni tahrirlash'), showThemeToggle: false),
      body: question.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: ApiException.from(e).message,
          onRetry: () => ref.invalidate(editableQuestionProvider(questionId)),
        ),
        data: (data) => _Editor(question: data),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.question});

  final QuestionContent question;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late QuestionForm _initial = QuestionForm.of(widget.question);
  late QuestionForm _form = _initial;

  late final _text = TextEditingController(text: _initial.text);
  late final _topic = TextEditingController(text: _initial.topic);

  bool _saving = false;
  bool _busyImage = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _topic.dispose();
    super.dispose();
  }

  QuestionContent get _question => widget.question;

  bool get _dirty =>
      !QuestionPatch.diff(before: _question, after: _form).isEmpty ||
      _form.correctOptionId != _initial.correctOptionId;

  Future<void> _save() async {
    final problem = _form.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repository = ref.read(questionEditRepositoryProvider);
      await repository.updateQuestion(
        _question.id,
        QuestionPatch.diff(before: _question, after: _form),
      );

      final correct = _form.correctOptionId;
      if (correct != null && correct != _initial.correctOptionId) {
        await repository.setCorrectOption(questionId: _question.id, optionId: correct);
      }

      // The caller refreshes the quiz detail when this route pops.
      ref.invalidate(editableQuestionProvider(_question.id));
      if (!mounted) return;
      setState(() => _initial = _form);
      _toast('Savol saqlandi');
      // Waits a frame so `PopScope` sees a clean form before the pop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _busyImage = true);
    try {
      await ref.read(questionEditRepositoryProvider).uploadImage(_question.id, File(picked.path));
      ref.invalidate(editableQuestionProvider(_question.id));
      if (mounted) _toast('Rasm qo‘shildi');
    } catch (e) {
      if (mounted) _toast(ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busyImage = false);
    }
  }

  Future<void> _removeImage(QuestionImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rasmni o'chirish"),
        content: const Text("Rasm butunlay o'chiriladi. Davom etasizmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyImage = true);
    try {
      await ref
          .read(questionEditRepositoryProvider)
          .deleteImage(questionId: _question.id, imageId: image.id);
      ref.invalidate(editableQuestionProvider(_question.id));
      if (mounted) _toast("Rasm o'chirildi");
    } catch (e) {
      if (mounted) _toast(ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busyImage = false);
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
        title: const Text("Saqlanmagan o'zgarishlar"),
        content: const Text("O'zgarishlarni saqlamasdan chiqasizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Qolish')),
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
    final padding = context.pagePadding;

    final form = _FormPane(
      question: _question,
      form: _form,
      textController: _text,
      topicController: _topic,
      busyImage: _busyImage,
      onText: (v) => setState(() => _form = _form.copyWith(text: v)),
      onTopic: (v) => setState(() => _form = _form.copyWith(topic: v)),
      onDifficulty: (d) => setState(() => _form = _form.copyWith(difficulty: d)),
      onCorrect: (id) => setState(() => _form = _form.copyWith(correctOptionId: id)),
      onAddImage: _addImage,
      onRemoveImage: _removeImage,
      error: _error,
      saving: _saving,
      dirty: _dirty,
      onSave: _save,
    );

    final preview = _PreviewPane(question: _question, form: _form);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) context.pop();
      },
      // A full-screen route has no bottom bar of its own, so without this the
      // Saqlash button sits under the system navigation bar.
      child: SafeArea(
        top: false,
        child: context.isLargeScreen
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(padding, 0, padding / 2, 32),
                      children: [form],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(padding / 2, 0, padding, 32),
                      children: [preview],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                children: [
                  ContentConstraint(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [form, const SizedBox(height: 16), preview],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Every editable field.
class _FormPane extends StatelessWidget {
  const _FormPane({
    required this.question,
    required this.form,
    required this.textController,
    required this.topicController,
    required this.busyImage,
    required this.onText,
    required this.onTopic,
    required this.onDifficulty,
    required this.onCorrect,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.error,
    required this.saving,
    required this.dirty,
    required this.onSave,
  });

  final QuestionContent question;
  final QuestionForm form;
  final TextEditingController textController;
  final TextEditingController topicController;
  final bool busyImage;
  final ValueChanged<String> onText;
  final ValueChanged<String> onTopic;
  final ValueChanged<Difficulty> onDifficulty;
  final ValueChanged<int> onCorrect;
  final VoidCallback onAddImage;
  final ValueChanged<QuestionImage> onRemoveImage;
  final String? error;
  final bool saving;
  final bool dirty;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Savol matni',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                r'LaTeX qo‘llab-quvvatlanadi: $x^2$',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Matn *',
                controller: textController,
                maxLines: 5,
                onChanged: onText,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Mavzu',
                hint: 'Masalan: Vieta teoremasi',
                controller: topicController,
                onChanged: onTopic,
              ),
              const SizedBox(height: 14),
              Text(
                'Qiyinlik',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final level in Difficulty.editable) ...[
                    Expanded(
                      child: _DifficultyOption(
                        level: level,
                        selected: form.difficulty == level,
                        onTap: () => onDifficulty(level),
                      ),
                    ),
                    if (level != Difficulty.editable.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CorrectOptionCard(
            question: question, selectedId: form.correctOptionId, onSelect: onCorrect),
        const SizedBox(height: 16),
        _ImagesCard(
          question: question,
          busy: busyImage,
          onAdd: onAddImage,
          onRemove: onRemoveImage,
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        GradientButton(
          label: 'Saqlash',
          icon: Icons.check_rounded,
          enabled: dirty,
          loading: saving,
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({required this.level, required this.selected, required this.onTap});

  final Difficulty level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: selected ? AppColors.tint(level.color) : c.bgInner,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.tint(level.color, 0x88) : c.border,
              width: 1.5,
            ),
          ),
          child: Text(
            level.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? level.color : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio-style list where the student marks the right answer.
class _CorrectOptionCard extends StatelessWidget {
  const _CorrectOptionCard({
    required this.question,
    required this.selectedId,
    required this.onSelect,
  });

  final QuestionContent question;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "To'g'ri javob",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          // Said plainly: there is no endpoint for editing option text.
          Text(
            "Javob variantlarining matnini o'zgartirib bo'lmaydi",
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
          const SizedBox(height: 12),
          for (final option in question.options) ...[
            _OptionChoice(
              option: option,
              selected: option.id != null && option.id == selectedId,
              onTap: option.id == null ? null : () => onSelect(option.id!),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _OptionChoice extends StatelessWidget {
  const _OptionChoice({required this.option, required this.selected, required this.onTap});

  final AnswerOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: selected ? AppColors.tint(AppColors.success) : c.bgInner,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.tint(AppColors.success, 0x88) : c.border,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.success : c.textMuted,
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentMuted,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MathText(
                  option.text,
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attached images with add and delete, capped at what the backend accepts.
class _ImagesCard extends StatelessWidget {
  const _ImagesCard({
    required this.question,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final QuestionContent question;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<QuestionImage> onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final full = question.images.length >= maxQuestionImages;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rasmlar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
              ),
              Text(
                '${question.images.length}/$maxQuestionImages',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final image in question.images) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image.url,
                    width: double.infinity,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 170,
                      alignment: Alignment.center,
                      color: c.bgInner,
                      child: Text(
                        'Rasm yuklanmadi',
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      onPressed: busy ? null : () => onRemove(image),
                      tooltip: "O'chirish",
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: busy || full ? null : onAdd,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: c.accent,
              side: BorderSide(color: c.border),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 19),
            label: Text(full ? 'Rasm limiti to‘ldi' : 'Rasm qo‘shish'),
          ),
        ],
      ),
    );
  }
}

/// Live preview of the edited question, rendered with the play-time widget.
class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.question, required this.form});

  final QuestionContent question;
  final QuestionForm form;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final edited = QuestionContent(
      id: question.id,
      text: form.text,
      subject: question.subject,
      topic: form.topic.trim().isEmpty ? null : form.topic.trim(),
      difficulty: form.difficulty,
      tableMarkdown: question.tableMarkdown,
      images: question.images,
      options: question.options,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text(
                "Ko'rinishi",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          QuestionView(
            question: edited,
            stateOf: (option) => option.id != null && option.id == form.correctOptionId
                ? OptionState.correct
                : OptionState.idle,
          ),
        ],
      ),
    );
  }
}
