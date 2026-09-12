import 'package:edunova_mobile/features/analytics/domain/analytics_models.dart';
import 'package:edunova_mobile/features/friends/domain/friend_models.dart';
import 'package:edunova_mobile/features/profile/domain/profile_edit.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileForm _form({
  String firstName = 'Ali',
  String lastName = 'Valiyev',
  String email = '',
  String phone = '',
  String school = '',
  String educationLevel = '',
  Set<int> subjectIds = const {1, 2},
}) {
  return ProfileForm(
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    school: school,
    educationLevel: educationLevel,
    subjectIds: subjectIds,
  );
}

void main() {
  group('DailyActivity.lastWeek', () {
    final now = DateTime(2026, 9, 12, 15);

    test('covers seven days ending today, oldest first', () {
      final days = DailyActivity.lastWeek(const [], now: now);

      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 9, 6));
      expect(days.last.day, DateTime(2026, 9, 12));
      expect(days.every((d) => d.count == 0), isTrue);
    });

    test('counts sessions per day and ignores older ones', () {
      final days = DailyActivity.lastWeek(
        [
          DateTime(2026, 9, 12, 9),
          DateTime(2026, 9, 12, 23, 30),
          DateTime(2026, 9, 10, 8),
          DateTime(2026, 8, 1), // outside the window
          null,
        ],
        now: now,
      );

      expect(days.last.count, 2);
      expect(days[4].count, 1); // 10 September
      expect(days.fold<int>(0, (sum, d) => sum + d.count), 3);
    });

    test('labels weekdays the way the web chart does', () {
      final days = DailyActivity.lastWeek(const [], now: DateTime(2026, 9, 12));
      expect(days.map((d) => d.label).toList(), ['Ya', 'Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sha']);
    });
  });

  group('UserSearchResult', () {
    test('contact_available true means the user is already a contact', () {
      final result = UserSearchResult.fromJson(const {
        'id': 2,
        'username': 'shehroz1',
        'first_name': 'Shehroz',
        'last_name': "Toshpo'latov",
        'contact_available': true,
      });

      expect(result.isContact, isTrue);
      expect(result.user.handle, '@shehroz1');
      expect(result.user.fullName, "Shehroz Toshpo'latov");
    });

    test('suggestions omit the flag, so they count as addable', () {
      final result = UserSearchResult.fromJson(const {
        'id': 4,
        'username': 'shehroz3',
        'first_name': '',
        'last_name': '',
      });

      expect(result.isContact, isFalse);
      expect(result.user.fullName, 'shehroz3');
    });
  });

  test('FriendContact reads the nested friend, not the contact row id', () {
    final contact = FriendContact.fromJson(const {
      'id': 7,
      'friend': {'id': 2, 'username': 'shehroz1', 'first_name': 'A', 'last_name': 'B', 'role': 'teacher'},
    });

    expect(contact.id, 7);
    expect(contact.friend.id, 2);
    expect(contact.friend.role, 'teacher');
  });

  group('ProfilePatch.diff', () {
    test('sends nothing when nothing changed', () {
      final before = _form();
      expect(ProfilePatch.diff(before: before, after: _form()).isEmpty, isTrue);
    });

    test('sends only the changed fields', () {
      final patch = ProfilePatch.diff(
        before: _form(),
        after: _form(school: '42-maktab'),
      );

      expect(patch.toJson(), {'school_name': '42-maktab'});
    });

    test('clears a field with null rather than an empty string', () {
      final patch = ProfilePatch.diff(
        before: _form(email: 'ali@example.com'),
        after: _form(email: '   '),
      );

      expect(patch.toJson(), {'email': null});
    });

    test('sends the whole subject selection, not the delta', () {
      final patch = ProfilePatch.diff(
        before: _form(subjectIds: {1, 2}),
        after: _form(subjectIds: {2, 3}),
      );

      expect((patch.toJson()['subject_ids'] as List).toSet(), {2, 3});
    });

    test('ignores subject reordering', () {
      final patch = ProfilePatch.diff(
        before: _form(subjectIds: {1, 2}),
        after: _form(subjectIds: {2, 1}),
      );

      expect(patch.isEmpty, isTrue);
    });
  });

  group('ProfileForm.validate', () {
    test('accepts a filled form', () {
      expect(_form(email: 'ali@example.com').validate(), isNull);
    });

    test('rejects a one-letter name, as the backend does', () {
      expect(_form(firstName: 'A').validate(), contains('Ism'));
      expect(_form(lastName: 'V').validate(), contains('Familiya'));
    });

    test('rejects a malformed email but allows a blank one', () {
      expect(_form(email: 'ali').validate(), isNotNull);
      expect(_form(email: '').validate(), isNull);
    });
  });

  group('ProfileForm.completionPercent', () {
    test('counts the seven fields the web counts', () {
      final full = _form(
        email: 'a@b.uz',
        phone: '+998901234567',
        school: '42-maktab',
      );

      expect(full.completionPercent(hasAvatar: true), 100);
      expect(full.completionPercent(hasAvatar: false), 86);
    });

    test('an empty profile is not complete', () {
      final empty = _form(firstName: '', lastName: '', subjectIds: const {});
      expect(empty.completionPercent(hasAvatar: false), 0);
    });
  });
}
