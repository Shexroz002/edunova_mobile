import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/friend_models.dart';

/// Contacts: the friend list, user search and adding a contact.
class FriendsRepository {
  FriendsRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/users';

  /// One page of contacts. The trailing slash is required.
  Future<PageResult<FriendContact>> fetchFriends({
    String? search,
    int page = 1,
    int size = 30,
  }) async {
    final data = await _api.get(
      '$_base/contact/list/',
      query: {
        'page': page,
        'size': size,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    ) as Json;
    return PageResult.fromJson(data, FriendContact.fromJson);
  }

  /// Users matching [search] (username, first or last name), with a flag
  /// saying whether each one is already a contact.
  Future<PageResult<UserSearchResult>> searchUsers({
    required String search,
    int page = 1,
    int size = 20,
  }) async {
    final data = await _api.get(
      '$_base/search',
      query: {'search': search, 'page': page, 'size': size},
    ) as Json;
    return PageResult.fromJson(data, UserSearchResult.fromJson);
  }

  /// People to add when nothing has been typed yet. The rows carry no
  /// `contact_available` field, but the endpoint only returns non-contacts.
  Future<PageResult<UserSearchResult>> fetchSuggestions({int page = 1, int size = 20}) async {
    final data = await _api.get(
      '$_base/contact/suggestions/',
      query: {'page': page, 'size': size},
    ) as Json;
    return PageResult.fromJson(data, UserSearchResult.fromJson);
  }

  /// Adds [friendId] to the contacts. It really is a `GET` that creates a row.
  Future<void> addContact(int friendId) => _api.get('$_base/contact/create/$friendId');
}

/// Provides [FriendsRepository].
final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(apiClientProvider)),
);
