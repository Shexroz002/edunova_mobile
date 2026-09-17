import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/chat/presentation/chat_info_screen.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/chat/presentation/chats_screen.dart';
import '../../features/common/splash_screen.dart';
import '../../features/competition/presentation/competition_create_screen.dart';
import '../../features/competition/presentation/lobby_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/group_session_result_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/question_edit/presentation/question_edit_screen.dart';
import '../../features/quiz_create/presentation/create_quiz_screen.dart';
import '../../features/results/presentation/results_screen.dart';
import '../../features/session/domain/session_models.dart';
import '../../features/session/presentation/play/play_screen.dart';
import '../../features/session/presentation/result_screen.dart';
import '../../features/session/presentation/review_screen.dart';
import '../../features/shell/student_shell.dart';
import '../../features/statistics/statistics_screen.dart';
import '../../features/tests/presentation/quiz_detail_screen.dart';
import '../../features/tests/presentation/tests_screen.dart';

/// Route paths in one place.
class Routes {
  Routes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const groups = '/groups';
  static const friends = '/friends';
  static const chats = '/chats';
  static const statistics = '/statistics';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const quizCreate = '/quiz/new';
  static const tests = '/tests';
  static const results = '/results';
  static const notifications = '/notifications';
  static const competitionNew = '/competition/new';

  static const _public = {login, register};
}

/// Reads an integer path parameter (0 if missing or invalid).
int _intParam(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '') ?? 0;

/// Re-runs router redirects whenever the auth state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
  }
}

/// App router with auth-based redirects and the 5-tab student shell.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;
      final isPublic = Routes._public.contains(location);

      return switch (status) {
        AuthStatus.unknown => location == Routes.splash ? null : Routes.splash,
        AuthStatus.unauthenticated => isPublic ? null : Routes.login,
        AuthStatus.authenticated => (isPublic || location == Routes.splash) ? Routes.home : null,
      };
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),

      // Full-screen pages opened on top of the tabs.
      GoRoute(path: Routes.tests, builder: (_, __) => const TestsScreen()),
      GoRoute(
        path: '/tests/:quizId',
        builder: (_, state) => QuizDetailScreen(quizId: _intParam(state, 'quizId')),
      ),
      GoRoute(
        path: Routes.results,
        builder: (_, state) => ResultsScreen(
          // `?sessionId=` opens that row's leaderboard once the list has
          // loaded, so a competition-result notification lands on the page the
          // result belongs to rather than showing a sheet over the notification.
          openSessionId: int.tryParse(state.uri.queryParameters['sessionId'] ?? ''),
        ),
      ),
      GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(
        path: '/chats/:chatId',
        builder: (_, state) => ChatRoomScreen(chatId: _intParam(state, 'chatId')),
      ),
      GoRoute(
        path: '/chats/:chatId/info',
        builder: (_, state) => ChatInfoScreen(chatId: _intParam(state, 'chatId')),
      ),
      GoRoute(path: Routes.profileEdit, builder: (_, __) => const ProfileEditScreen()),
      GoRoute(path: Routes.quizCreate, builder: (_, __) => const CreateQuizScreen()),
      GoRoute(
        path: '/questions/:questionId/edit',
        builder: (_, state) => QuestionEditScreen(
          questionId: int.parse(state.pathParameters['questionId']!),
        ),
      ),
      GoRoute(
        path: Routes.competitionNew,
        builder: (_, state) => CompetitionCreateScreen(
          initialQuizId: int.tryParse(state.uri.queryParameters['quizId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/lobby',
        builder: (_, state) => LobbyScreen(sessionId: _intParam(state, 'sessionId')),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (_, state) => GroupDetailScreen(groupId: _intParam(state, 'groupId')),
      ),
      GoRoute(
        path: '/groups/:groupId/sessions/:sessionId',
        builder: (_, state) => GroupSessionResultScreen(
          groupId: _intParam(state, 'groupId'),
          sessionId: _intParam(state, 'sessionId'),
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/play',
        builder: (_, state) => PlayScreen(sessionId: _intParam(state, 'sessionId')),
      ),
      GoRoute(
        path: '/session/:sessionId/result',
        builder: (_, state) => ResultScreen(
          sessionId: _intParam(state, 'sessionId'),
          initial: state.extra is FinishResult ? state.extra as FinishResult : null,
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/review',
        builder: (_, state) => ReviewScreen(sessionId: _intParam(state, 'sessionId')),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => StudentShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.groups, builder: (_, __) => const GroupsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.friends, builder: (_, __) => const FriendsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.chats, builder: (_, __) => const ChatsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.statistics, builder: (_, __) => const StatisticsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });
  return router;
});
