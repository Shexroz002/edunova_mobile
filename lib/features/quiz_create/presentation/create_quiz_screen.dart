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
import '../../../core/widgets/hint_pill.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../data/quiz_create_repository.dart';
import '../domain/quiz_job.dart';
import 'job_progress_view.dart';
import 'widgets/method_card.dart';
import 'widgets/pdf_picker.dart';
import 'widgets/source_card.dart';
import 'widgets/step_rail.dart';

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

  /// Size of [_pdf], read once at pick time.
  int? _pdfSize;
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
      ? _pdf != null && (_pdfSize ?? 0) <= CreateLimits.maxPdfBytes
      : _subjectId != null && _description.text.trim().isNotEmpty;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final picked = result?.files.single;
    if (picked?.path == null || !mounted) return;
    setState(() {
      _pdf = File(picked!.path!);
      _pdfSize = picked.size;
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

  /// What the progress screen shows the job was started from.
  JobSource get _source {
    if (_method == CreateMethod.pdf) {
      final file = _pdf;
      return JobSource(
        icon: Icons.picture_as_pdf_rounded,
        title: file == null ? 'PDF fayl' : file.uri.pathSegments.last,
        meta: _pdfSize == null ? 'PDF fayldan' : '${PdfPicker.formatSize(_pdfSize!)} · PDF fayldan',
      );
    }
    final subject =
        ref.read(subjectsProvider).valueOrNull?.where((s) => s.id == _subjectId).firstOrNull;
    return JobSource(
      icon: Icons.auto_awesome_rounded,
      title: subject?.displayName ?? 'AI test',
      meta: '$_questions ta savol · AI yordamida',
    );
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

    final step = job != null
        ? CreateStep.job
        : _method == null
            ? CreateStep.method
            : CreateStep.form;

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
        // A full-screen route has no bottom bar of its own, so without this
        // the last action sits under the system navigation bar.
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.pagePadding, 14, context.pagePadding, 4),
                child: ContentConstraint(child: StepRail(current: step)),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(context.pagePadding, 14, context.pagePadding, 32),
                  children: [
                    ContentConstraint(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (job != null)
                            JobProgressView(
                              started: job,
                              method: _method!,
                              source: _source,
                              onDone: (quizId) {
                                context.pop();
                                context.push('/tests/$quizId');
                              },
                              onRetry: () => setState(() => _job = null),
                              onChangeMethod: () => setState(() {
                                _job = null;
                                _method = null;
                                _pdf = null;
                                _pdfSize = null;
                                _error = null;
                              }),
                            )
                          else if (_method == null)
                            _MethodStep(onPick: (m) => setState(() => _method = m))
                          else
                            _FormStep(
                              method: _method!,
                              pdf: _pdf,
                              pdfBytes: _pdfSize,
                              onPickPdf: _pickPdf,
                              onClearPdf: () => setState(() {
                                _pdf = null;
                                _pdfSize = null;
                              }),
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
            ],
          ),
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
    final c = context.colors;

    final pdf = MethodCard(
      icon: Icons.upload_file_rounded,
      color: AppColors.blue,
      title: 'PDF fayldan',
      who: 'Darslik yoki konspekt bo‘lsa',
      facts: const [
        'Matnli PDF, 5 MB gacha',
        'Savollar fayl mazmunidan olinadi',
        'Odatda 2–3 daqiqa',
      ],
      onTap: () => onPick(CreateMethod.pdf),
    );
    final ai = MethodCard(
      icon: Icons.auto_awesome_rounded,
      color: AppColors.violet,
      title: 'AI bilan yaratish',
      who: 'Faqat mavzu bo‘lsa',
      facts: const [
        'Fan va mavzuni yozasiz',
        'Savollar sonini o‘zingiz tanlaysiz',
        'Odatda 1–2 daqiqa',
      ],
      onTap: () => onPick(CreateMethod.ai),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Test qanday yaratilsin?',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 5),
        Text(
          'Ikkalasida ham savollarni AI tuzadi — farqi nimadan boshlashingizda.',
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        // Side by side on a tablet, as on the web's `md:grid-cols-2`.
        if (context.isTablet)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: pdf),
                const SizedBox(width: 16),
                Expanded(child: ai),
              ],
            ),
          )
        else ...[
          pdf,
          const SizedBox(height: 12),
          ai,
        ],
        const SizedBox(height: 16),
        const HintPill(
          text: 'Tayyor test “Testlar” bo‘limiga saqlanadi va uni keyin tahrirlashingiz mumkin.',
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
    required this.pdfBytes,
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
  final int? pdfBytes;
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

  /// What still has to be filled in, or `null` once the form can be submitted.
  String? get _missing {
    if (canSubmit) return null;
    if (method == CreateMethod.pdf) {
      if (pdf == null) return 'Davom etish uchun PDF fayl tanlang.';
      return 'Bu fayl juda katta. Kichikroq PDF tanlang — masalan, faqat '
          'kerakli boblardan iborat faylni.';
    }
    if (subjectId == null) return 'Fanni tanlang.';
    return 'Mavzu va talablarni yozing.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = method == CreateMethod.ai;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormHeader(method: method),
              const _FormDivider(),
              if (!ai)
                PdfPicker(
                  file: pdf,
                  bytes: pdfBytes,
                  onPick: onPickPdf,
                  onClear: onClearPdf,
                )
              else ...[
                _SubjectPicker(value: subjectId, onChanged: onSubject),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Mavzu va talablar *',
                  hint: 'Masalan: Fizika fanidan dinamika va saqlanish qonunlari '
                      'bo‘yicha test yaratib ber',
                  maxLines: 4,
                  maxLength: 500,
                  controller: description,
                  onChanged: (_) => onDescriptionChanged(),
                ),
                const _FieldHelp(
                  text: 'Qanchalik aniq yozsangiz, savollar shunchalik mos bo‘ladi: '
                      'fan, bo‘lim va qamrab olinadigan mavzular.',
                ),
                const SizedBox(height: 18),
                _QuestionCount(value: questions, onChanged: onQuestions),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          HintPill(text: error!, icon: Icons.error_outline_rounded, tone: AppColors.error),
        ],
        const SizedBox(height: 20),
        GradientButton(
          label: 'Test yaratish',
          icon: Icons.auto_awesome_rounded,
          enabled: canSubmit,
          loading: starting,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 12),
        // While the form is incomplete the pill says what is missing; the
        // disabled button on its own never did.
        if (_missing != null)
          HintPill(text: _missing!, icon: Icons.info_outline_rounded)
        else
          HintPill(
            icon: Icons.schedule_rounded,
            text: ai
                ? 'Savollar soni ${CreateLimits.minQuestions}–${CreateLimits.maxQuestions} '
                    'oralig‘ida. Tayyorlash odatda 1–2 daqiqa davom etadi.'
                : 'Tayyorlash odatda 2–3 daqiqa davom etadi.',
          ),
      ],
    );
  }
}

/// Says which method is being filled in, so step 2 does not look like a bare
/// list of fields.
class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.method});

  final CreateMethod method;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ai = method == CreateMethod.ai;
    final tone = context.readable(ai ? AppColors.violet : AppColors.blue);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.tint(tone, 0x21),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.tint(tone, 0x4D)),
          ),
          child: Icon(
            ai ? Icons.auto_awesome_rounded : Icons.upload_file_rounded,
            size: 22,
            color: tone,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ai ? 'AI bilan yaratish' : 'PDF fayldan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                ai
                    ? 'Mavzuni yozing — AI savol va variantlarni o‘zi tuzadi'
                    : 'Faylni yuklang — AI uni testga aylantiradi',
                style: TextStyle(fontSize: 12, height: 1.4, color: c.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
        child: Container(height: 1, color: context.colors.border),
      );
}

/// Helper line under a field.
class _FieldHelp extends StatelessWidget {
  const _FieldHelp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, height: 1.4, color: context.colors.textMuted),
        ),
      );
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
