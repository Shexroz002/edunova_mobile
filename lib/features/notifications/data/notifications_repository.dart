import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/app_notification.dart';

/// Notification list and read-state endpoints.
class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/notifications';

  /// One page, newest first. The trailing slash is required (`307` without it).
  Future<PageResult<AppNotification>> fetchPage({int page = 1, int size = 30}) async {
    final data = await _api.get('$_base/', query: {'page': page, 'size': size}) as Json;
    return PageResult.fromJson(data, (json) => AppNotification.fromJson(json));
  }

  /// Marks one notification read and returns its new read state.
  Future<void> markRead(int id) => _api.patch('$_base/$id/read/');

  /// Marks every notification read; the response is the number affected.
  Future<int> markAllRead() async {
    final data = await _api.patch('$_base/read-all/');
    return asInt(data) ?? 0;
  }

  /// Accepts a friend request. It really is a `GET` that creates the contact.
  Future<void> acceptFriend(int friendId) => _api.get('/api/v1/users/contact/create/$friendId');
}

/// Provides [NotificationsRepository].
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);
