import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../data/mistakes_repository.dart';
import '../domain/mistake_models.dart';
import 'widgets/review_question.dart';
import 'widgets/review_summary.dart';

/// Reviewing the questions that are due.
///
/// Deliberately not a quiz session: it creates nothing in Natijalar and does
/// not touch the student's average. That is why the answer is revealed as soon
/// as a choice is made — this is practice, and hiding the answer until the end
/// would only make the student afraid to practise.
class MistakeReviewScreen extends ConsumerStatefulWidget {
  const MistakeReviewScreen({super.key, this.subject});

  /// Limits the review to one subject, from a subject row.
  final String? subject;

  @override
  ConsumerState<MistakeReviewScreen> createState() => _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends ConsumerState<MistakeReviewScreen> {
  late Future<List<MistakeQuestion>> _future = _load();

  List<MistakeQuestion> _questions = const [];
  int _index = 0;

  /// The answer for the question on screen, null until one is chosen.
  MistakeAnswerResult? _result;
  String? _chosen;
  bool _sending = false;
  String? _error;

  int _correct = 0;
  int _wrong = 0;
  int _cleared = 0;
  bool _done = false;

  Future<List<MistakeQuestion>> _load() =>
      ref.read(mistakesRepositoryProvider).fetchReview(subject: widget.subject);

  Future<void> _answer(String label) async {
    if (_sending || _result != null) return;
    setState(() {
      _sending = true;
      _chosen = label;
      _error = null;
    });
    try {
      final result = await ref.read(mistakesRepositoryProvider).answer(
            questionId: _questions[_index].questionId,
            selectedOption: label,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        if (result.isCorrect) {
          _correct++;
        } else {
          _wrong++;
        }
        if (result.cleared) _cleared++;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      // The choice is given back so the student can answer again.
      setState(() {
        _error = error.message;
        _chosen = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _result = null;
      _chosen = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: const Text('Takrorlash'),
        showFriends: false,
        actions: [
          if (!_done && _questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '${_index + 1} / ${_questions.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<MistakeQuestion>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(
                message: ApiException.from(snapshot.error!).message,
                onRetry: () => setState(() => _future = _load()),
              );
            }

            _questions = snapshot.data ?? const [];
            if (_questions.isEmpty) {
              return const _NothingDue();
            }
            if (_done) {
              return ReviewSummary(
                correct: _correct,
                wrong: _wrong,
                cleared: _cleared,
                onClose: () => Navigator.of(context).pop(),
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                12,
                context.pagePadding,
                28,
              ),
              children: [
                ContentConstraint(
                  child: ReviewQuestion(
                    question: _questions[_index],
                    progress: (_index + 1) / _questions.length,
                    chosen: _chosen,
                    result: _result,
                    sending: _sending,
                    error: _error,
                    onChoose: _answer,
                    onNext: _next,
                    isLast: _index + 1 >= _questions.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Nothing is due. Reached by deep link or by finishing elsewhere.
class _NothingDue extends StatelessWidget {
  const _NothingDue();

  @override
  Widget build(BuildContext context) {
    return const EmptyView(
      icon: Icons.check_rounded,
      title: 'Takrorlash uchun savol yo‘q',
      subtitle: 'Bugungi navbat tugagan. Savollar o‘z muddatida qaytadi.',
    );
  }
}
