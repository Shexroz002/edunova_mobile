import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../data/quiz_create_repository.dart';
import '../domain/quiz_job.dart';
import 'job_progress_view.dart';
import 'widgets/method_card.dart';
import 'widgets/pdf_picker.dart';

/// Quiz creation, following the web's `CreateQuizModal`.
///
/// The web is a three-step modal; on a phone it is a full screen with the same
/// steps: pick a method, fill the form, then watch the job.
class CreateQuizScreen extends ConsumerStatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  CreateMethod? _method;
  File? _pdf;
  int? _subjectId;
  int _questions = CreateLimits.defaultQuestions;
  final _description = TextEditingController();

  bool _starting = false;
  String? _error;

  /// Set once the job is queued; the screen then shows the progress view.
  QuizJob? _job;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _canSubmit => _method == CreateMethod.pdf
      ? _pdf != null
      : _subjectId != null && _description.text.trim().isNotEmpty;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() {
      _pdf = File(path);
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final repository = ref.read(quizCreateRepositoryProvider);
      final job = _method == CreateMethod.pdf
          ? await repository.startPdfJob(_pdf!)
          : await repository.startAiJob(
              subjectId: _subjectId!,
              description: _description.text,
              questionCount: _questions,
            );
      if (mounted) setState(() => _job = job);
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _back() {
    if (_job != null) {
      setState(() => _job = null);
    } else if (_method != null) {
      setState(() => _method = null);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final job = _job;

    final subtitle = switch (_method) {
      null => 'PDF yoki AI yordamida',
      CreateMethod.pdf => 'PDF fayldan',
      CreateMethod.ai => 'AI yordamida',
    };

    return PopScope(
      canPop: _method == null && _job == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: PageAppBar(
          title: const Text('Test yaratish'),
          showThemeToggle: false,
          leading: IconButton(
            onPressed: _back,
            icon: Icon(Icons.arrow_back_rounded, color: c.textSecondary),
            tooltip: 'Orqaga',
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 32),
          children: [
            ContentConstraint(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    job != null
                        ? 'Jarayon tugashini kuting'
                        : _method == null
                            ? 'Test yaratish usulini tanlang'
                            : subtitle,
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                  const SizedBox(height: 16),
                  if (job != null)
                    JobProgressView(
                      started: job,
                      method: _method!,
                      onDone: (quizId) {
                        context.pop();
                        context.push('/tests/$quizId');
                      },
                      onRetry: () => setState(() => _job = null),
                    )
                  else if (_method == null)
                    _MethodStep(onPick: (m) => setState(() => _method = m))
                  else
                    _FormStep(
                      method: _method!,
                      pdf: _pdf,
                      onPickPdf: _pickPdf,
                      onClearPdf: () => setState(() => _pdf = null),
                      subjectId: _subjectId,
                      onSubject: (id) => setState(() => _subjectId = id),
                      description: _description,
                      onDescriptionChanged: () => setState(() {}),
                      questions: _questions,
                      onQuestions: (n) => setState(() => _questions = n),
                      error: _error,
                      starting: _starting,
                      canSubmit: _canSubmit,
                      onSubmit: _submit,
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

/// Step 1: the two method cards.
class _MethodStep extends StatelessWidget {
  const _MethodStep({required this.onPick});

  final ValueChanged<CreateMethod> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MethodCard(
          icon: Icons.upload_file_rounded,
          color: AppColors.sky,
          title: 'PDF fayldan',
          description: 'Mavjud PDF hujjatingizdan testni avtomatik yarating. '
              'AI savollarni tahlil qiladi va test tuzadi.',
          duration: '~2-3 daqiqa',
          trait: 'Avtomatik',
          traitIcon: Icons.bolt_rounded,
          onTap: () => onPick(CreateMethod.pdf),
        ),
        const SizedBox(height: 12),
        MethodCard(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.violet,
          title: 'AI bilan yaratish',
          description: 'Mavzu va parametrlarni kiriting, AI sizga qiyin va '
              'sifatli test savollarini yaratib beradi.',
          duration: '~1-2 daqiqa',
          trait: 'Intellektual',
          traitIcon: Icons.auto_awesome_rounded,
          onTap: () => onPick(CreateMethod.ai),
        ),
      ],
    );
  }
}

/// Step 2: the fields for the chosen method.
class _FormStep extends ConsumerWidget {
  const _FormStep({
    required this.method,
    required this.pdf,
    required this.onPickPdf,
    required this.onClearPdf,
    required this.subjectId,
    required this.onSubject,
    required this.description,
    required this.onDescriptionChanged,
    required this.questions,
    required this.onQuestions,
    required this.error,
    required this.starting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final CreateMethod method;
  final File? pdf;
  final VoidCallback onPickPdf;
  final VoidCallback onClearPdf;
  final int? subjectId;
  final ValueChanged<int> onSubject;
  final TextEditingController description;
  final VoidCallback onDescriptionChanged;
  final int questions;
  final ValueChanged<int> onQuestions;
  final String? error;
  final bool starting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (method == CreateMethod.pdf)
                PdfPicker(file: pdf, onPick: onPickPdf, onClear: onClearPdf)
              else ...[
                _SubjectPicker(value: subjectId, onChanged: onSubject),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Tavsif *',
                  hint: 'Masalan: Fizika fanidan dinamika va saqlanish qonunlari '
                      "bo'yicha test yaratib ber",
                  maxLines: 4,
                  maxLength: 500,
                  controller: description,
                  onChanged: (_) => onDescriptionChanged(),
                ),
                const SizedBox(height: 16),
                _QuestionCount(value: questions, onChanged: onQuestions),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        GradientButton(
          label: 'Test yaratish',
          icon: Icons.auto_awesome_rounded,
          enabled: canSubmit,
          loading: starting,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 10),
        Text(
          method == CreateMethod.pdf
              ? 'Faqat PDF, 5 MB gacha'
              : "Savollar soni ${CreateLimits.minQuestions}–${CreateLimits.maxQuestions} oralig'ida",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

/// "Fan *" dropdown over the real subject list.
class _SubjectPicker extends ConsumerWidget {
  const _SubjectPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final subjects = ref.watch(subjectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fan *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        subjects.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            ApiException.from(e).message,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          data: (items) => DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            hint: Text('Fanni tanlang', style: TextStyle(fontSize: 14, color: c.textMuted)),
            dropdownColor: c.bgCard,
            decoration: _fieldDecoration(context),
            items: [
              for (final Subject subject in items)
                DropdownMenuItem(
                  value: subject.id,
                  child: Text(
                    subject.displayName,
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                  ),
                ),
            ],
            onChanged: (selected) {
              if (selected != null) onChanged(selected);
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI test shu fan asosida yaratiladi',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

/// "Savollar soni" stepper — easier to hit than a number field on a phone.
class _QuestionCount extends StatelessWidget {
  const _QuestionCount({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _step = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Savollar soni',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: c.bgInner,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border, width: 1.5),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: value > CreateLimits.minQuestions,
                onTap: () => onChanged((value - _step).clamp(
                  CreateLimits.minQuestions,
                  CreateLimits.maxQuestions,
                )),
              ),
              Expanded(
                child: Text(
                  '$value ta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: value < CreateLimits.maxQuestions,
                onTap: () => onChanged((value + _step).clamp(
                  CreateLimits.minQuestions,
                  CreateLimits.maxQuestions,
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20),
        color: c.accent,
        disabledColor: c.textMuted,
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context) {
  final c = context.colors;
  OutlineInputBorder border(Color color, [double width = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    filled: true,
    fillColor: c.bgInner,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    border: border(c.border),
    enabledBorder: border(c.border),
    focusedBorder: border(AppColors.brand),
  );
}
