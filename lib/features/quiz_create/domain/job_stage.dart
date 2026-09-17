import 'quiz_job.dart';

/// Uzbek wording for one stage, in the three states a checklist row can show.
class StageLabels {
  const StageLabels({required this.pending, required this.active, required this.done});

  final String pending;
  final String active;
  final String done;
}

/// The four stages the backend walks a generation job through.
///
/// The worker writes its own Uzbek `message`, but that text names the AI
/// provider — "PDF Mistral serveriga yuklanmoqda", "AI provider tayyorlanmoqda:
/// gemini" — so the client never renders it. The stage is derived from
/// `progress` instead, whose steps are fixed in `app/services/pdf/tasks`:
/// PDF 10 → 15 → 30 → 50 → 80 → 85 → 100 and AI 10 → 50 → 75 → 80 → 85 → 100.
enum JobStage {
  prepare,
  send,
  generate,
  save;

  /// How many stages the checklist shows.
  static const count = 4;

  /// The stage a job reporting [progress] is in.
  static JobStage of(int progress) => switch (progress) {
        < 15 => prepare,
        < 50 => send,
        < 85 => generate,
        _ => save,
      };

  /// 1-based position, for "3 / 4-bosqich".
  int get step => index + 1;

  /// Checklist wording, which differs between the two methods for the first
  /// two stages: one uploads a file, the other sends a written request.
  StageLabels labels(CreateMethod method) {
    final pdf = method == CreateMethod.pdf;
    return switch (this) {
      prepare => pdf
          ? const StageLabels(
              pending: 'Faylni tekshirish',
              active: 'Fayl tekshirilmoqda',
              done: 'Fayl tekshirildi',
            )
          : const StageLabels(
              pending: 'So‘rovni tayyorlash',
              active: 'So‘rov tayyorlanmoqda',
              done: 'So‘rov tayyorlandi',
            ),
      send => pdf
          ? const StageLabels(
              pending: 'Faylni yuborish',
              active: 'Fayl yuborilmoqda',
              done: 'Fayl yuborildi',
            )
          : const StageLabels(
              pending: 'So‘rovni yuborish',
              active: 'So‘rov yuborilmoqda',
              done: 'So‘rov yuborildi',
            ),
      generate => const StageLabels(
          pending: 'Savollarni yaratish',
          active: 'Savollar yaratilmoqda',
          done: 'Savollar yaratildi',
        ),
      save => const StageLabels(
          pending: 'Testga saqlash',
          active: 'Testga saqlanmoqda',
          done: 'Testga saqlandi',
        ),
    };
  }

  /// The sentence under the ring, explaining what is happening right now.
  String headline(CreateMethod method) {
    final pdf = method == CreateMethod.pdf;
    return switch (this) {
      prepare => pdf
          ? 'Fayl hajmi va formati tekshirilmoqda'
          : 'Mavzu va savollar soni tayyorlanmoqda',
      send => pdf
          ? 'Fayl tahlil qilish uchun yuborilmoqda'
          : 'So‘rovingiz tahlil qilish uchun yuborilmoqda',
      generate => pdf
          ? 'AI fayl matnini o‘qib, savol va variantlarni tuzmoqda'
          : 'AI siz bergan mavzu bo‘yicha savol va variantlarni tuzmoqda',
      save => 'Tayyor savollar testga yozilmoqda',
    };
  }
}
