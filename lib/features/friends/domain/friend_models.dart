import '../../../core/utils/json_utils.dart';

/// A user as returned by the contact and search endpoints.
class UserBrief {
  const UserBrief({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.role,
    this.profileImage,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;

  /// Present on `contact/list/` and `contact/suggestions/` only.
  /// A contact can be a `teacher`, not just a student.
  final String? role;
  final String? profileImage;

  /// Falls back to the username when the name fields are blank.
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }

  /// `@username`, as the web shows it.
  String get handle => username.startsWith('@') ? username : '@$username';

  factory UserBrief.fromJson(Json json) => UserBrief(
        id: asInt(json['id']) ?? 0,
        username: asString(json['username']) ?? '',
        firstName: asString(json['first_name']) ?? '',
        lastName: asString(json['last_name']) ?? '',
        role: asString(json['role']),
        profileImage: asString(json['profile_image']),
      );
}

/// One row of `GET /users/contact/list/`: `{id, friend}`.
///
/// `id` is the contact row, not the user; adding and messaging use
/// `friend.id`.
class FriendContact {
  const FriendContact({required this.id, required this.friend});

  final int id;
  final UserBrief friend;

  factory FriendContact.fromJson(Json json) {
    final friend = json['friend'];
    return FriendContact(
      id: asInt(json['id']) ?? 0,
      friend: UserBrief.fromJson(friend is Map ? Map<String, dynamic>.from(friend) : const {}),
    );
  }
}

/// A candidate from `GET /users/search` or `GET /users/contact/suggestions/`.
class UserSearchResult {
  const UserSearchResult({required this.user, required this.isContact});

  final UserBrief user;

  /// True when the user is **already** in your contacts.
  ///
  /// The API field is called `contact_available`, which reads like the
  /// opposite; the backend sets it to `true` when a `Contact` row exists
  /// (`user_repo.users_with_contact_status`), so only `false` can be added.
  /// `contact/suggestions/` omits the field entirely and only ever returns
  /// non-contacts, hence the `false` default.
  final bool isContact;

  factory UserSearchResult.fromJson(Json json) => UserSearchResult(
        user: UserBrief.fromJson(json),
        isContact: asBool(json['contact_available']),
      );
}
