import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/quiz_job.dart';
import 'job_controller.dart';

/// Live progress of a generation job, as on the web's processing step.
class JobProgressView extends ConsumerWidget {
  const JobProgressView({
    super.key,
    required this.started,
    required this.method,
    required this.onDone,
    required this.onRetry,
  });

  /// The job as the `POST` returned it; the controller takes it from there.
  final QuizJob started;
  final CreateMethod method;

  /// Called with the finished quiz id.
  final void Function(int quizId) onDone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(jobControllerProvider(started));
    final job = state.job;

    ref.listen(jobControllerProvider(started), (_, next) {
      if (next.job.isDone) onDone(next.job.quizId!);
    });

    if (job.status == JobStatus.failed || state.timedOut) {
      return _Failure(
        message: state.timedOut
            ? "Jarayon juda uzoq davom etdi. Keyinroq qayta urinib ko'ring."
            : job.message ?? "Test yaratilmadi. Keyinroq qayta urinib ko'ring.",
        onRetry: onRetry,
      );
    }

    final title = method == CreateMethod.ai ? 'AI test yaratilmoqda' : 'PDF testga aylantirilmoqda';
    final intro = method == CreateMethod.ai
        ? "AI sizning so'rovingiz bo'yicha test tayyorlamoqda"
        : 'AI yuklangan PDF faylni testga aylantirmoqda';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.tint(AppColors.sky, 0x14),
          borderColor: AppColors.tint(AppColors.sky, 0x47),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.sky),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'AI JARAYONI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppColors.sky,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              // The backend writes its own Uzbek step text ("Savollar bazaga
              // saqlanmoqda"), so it is shown as-is when present.
              Text(
                job.message ?? intro,
                style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jarayon holati',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  Text(
                    '${job.progress}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sky,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: job.progress / 100,
                  minHeight: 10,
                  backgroundColor: c.bgInner,
                  valueColor: const AlwaysStoppedAnimation(AppColors.sky),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Test tayyor bo‘lgach avtomatik ochiladi. Ilovani yopmang.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

/// Failure card, matching the web's "PDF qayta ishlanmadi" dialog.
class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.error),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.tint(AppColors.error, 0x40)),
            ),
            child: const Icon(Icons.error_outline_rounded, size: 24, color: AppColors.error),
          ),
          const SizedBox(height: 14),
          Text(
            'Test yaratilmadi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          // The job's `error` field quotes the AI provider in English, so only
          // the backend's own Uzbek `message` is shown.
          Text(
            message,
            style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Qayta urinish',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
