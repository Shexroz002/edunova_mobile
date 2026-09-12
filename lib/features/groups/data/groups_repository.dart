import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../../session/domain/session_models.dart';
import '../domain/group_models.dart';

/// Groups the student belongs to, and their session results.
///
/// A non-member gets a plain-text `500` from these paths, which `ApiException`
/// turns into a generic Uzbek message (`BACKEND_ISSUES.md` #16).
class GroupsRepository {
  GroupsRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/student/group';

  /// One page of the student's groups. **Trailing slash required.**
  Future<PageResult<StudentGroup>> fetchGroups(
      {String? search, int page = 1, int size = 20}) async {
    final data = await _api.get(
      '$_base/',
      query: {'search': search, 'page': page, 'size': size},
    ) as Json;
    return PageResult.fromJson(data, StudentGroup.fromJson);
  }

  /// Group header. **No trailing slash.**
  ///
  /// [fallbackCover] carries the list's `cover_image` over, because this
  /// endpoint always returns `null` for it.
  Future<StudentGroup> fetchGroup(int groupId, {String? fallbackCover}) async {
    final data = await _api.get('$_base/$groupId/detail-card') as Json;
    final group = StudentGroup.fromJson(data);
    if (group.coverImage != null || fallbackCover == null) return group;
    return StudentGroup(
      id: group.id,
      name: group.name,
      status: group.status,
      color: group.color,
      studentsCount: group.studentsCount,
      testsCount: group.testsCount,
      averageScore: group.averageScore,
      subject: group.subject,
      description: group.description,
      lastActivity: group.lastActivity,
      coverImage: fallbackCover,
    );
  }

  /// Tests assigned to the group, newest first.
  Future<List<GroupTest>> fetchTests(int groupId) async {
    final data =
        await _api.get('$_base/$groupId/sessions', query: {'page': 1, 'size': 100}) as Json;
    return PageResult.fromJson(data, GroupTest.fromJson).items;
  }

  /// Every member's accuracy, best first.
  Future<List<GroupStudent>> fetchStudents(int groupId, {String? search}) async {
    final data = await _api.get(
      '$_base/$groupId/students-performance',
      query: {'search': search, 'page': 1, 'size': 100},
    ) as Json;
    final items = PageResult.fromJson(data, GroupStudent.fromJson).items;
    // The web's podium is ordered wrong (web bug #4); sort it here.
    return [...items]..sort((a, b) => b.averageScore.compareTo(a.averageScore));
  }

  /// Header numbers of one group session.
  Future<GroupSessionResult> fetchSessionResult(int groupId, int sessionId) async {
    final data = await _api.get('$_base/$groupId/results/$sessionId') as Json;
    return GroupSessionResult.fromJson(data);
  }

  /// Per-question accuracy of one group session, in question order.
  Future<List<QuestionAccuracy>> fetchQuestionAccuracy(int groupId, int sessionId) async {
    final data = await _api.get('$_base/$groupId/question-accuracy/$sessionId');
    final items = asJsonList(data).map(QuestionAccuracy.fromJson).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return items;
  }

  /// Session leaderboard, ranked on the client (the API has no rank field and
  /// sorts null scores first).
  Future<List<LeaderboardEntry>> fetchLeaderboard(int groupId, int sessionId) async {
    final data = await _api.get(
      '$_base/$groupId/leaderboard/$sessionId',
      query: {'page': 1, 'size': 100},
    ) as Json;
    final page = PageResult.fromJson(data, LeaderboardEntry.fromJson);
    return LeaderboardEntry.ranked(page.items);
  }
}

/// Provides [GroupsRepository].
final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(ref.watch(apiClientProvider)),
);

/// Header of one group.
final groupDetailProvider = FutureProvider.autoDispose.family<StudentGroup, int>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).fetchGroup(groupId),
);

/// Tests assigned to one group.
final groupTestsProvider = FutureProvider.autoDispose.family<List<GroupTest>, int>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).fetchTests(groupId),
);

/// Member performance of one group.
final groupStudentsProvider = FutureProvider.autoDispose.family<List<GroupStudent>, int>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).fetchStudents(groupId),
);
