import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import '../domain/session_models.dart';

/// Tests the student can still walk back into, newest first.
///
/// Only untimed sessions qualify — a timed one has to be sat in one go. Open
/// sessions are the newest rows in the history, so one page is enough.
///
/// It lives here rather than beside the home carousel that draws it because
/// the play screen has to invalidate it: the moment a test is handed in, the
/// list is stale, and the screen that closed it is the only one that knows.
final unfinishedSessionsProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  final page = await ref.watch(sessionRepositoryProvider).fetchHistory(size: 30);
  return page.items.where((item) => item.canResume).toList();
});
