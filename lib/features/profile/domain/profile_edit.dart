/// The twelve values the backend's `EducationLevel` enum accepts.
///
/// Anything else is rejected with 422 (verified live with `12-sinf`).
const educationLevels = <String>[
  '1-sinf',
  '2-sinf',
  '3-sinf',
  '4-sinf',
  '5-sinf',
  '6-sinf',
  '7-sinf',
  '8-sinf',
  '9-sinf',
  '10-sinf',
  '11-sinf',
  'Universitet',
];

/// The fields `PUT /api/v1/users/{id}/` accepts.
///
/// Only the fields the user actually changed are sent: the backend applies
/// `model_dump(exclude_unset=True)`, so an omitted field keeps its value while
/// an explicit `null` clears it.
class ProfilePatch {
  const ProfilePatch({
    this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    this.schoolName,
    this.educationLevel,
    this.subjectIds,
  });

  final String? firstName;
  final String? lastName;

  /// `null` clears the address; an empty string is rejected with 422.
  final String? email;
  final String? phoneNumber;
  final String? schoolName;
  final String? educationLevel;

  /// The complete selection: the backend deletes the subjects missing from it.
  /// An **empty** list is silently ignored (`if subject_ids:` in the service),
  /// so subjects can never be cleared — see `docs/BACKEND_ISSUES.md`.
  final List<int>? subjectIds;

  /// Builds the diff between [before] and [after]; `null` fields stay out of
  /// the request body.
  static ProfilePatch diff({
    required ProfileForm before,
    required ProfileForm after,
  }) {
    return ProfilePatch(
      firstName: after.firstName == before.firstName ? null : after.firstName,
      lastName: after.lastName == before.lastName ? null : after.lastName,
      email: after.email == before.email ? null : after.email,
      phoneNumber: after.phone == before.phone ? null : after.phone,
      schoolName: after.school == before.school ? null : after.school,
      educationLevel: after.educationLevel == before.educationLevel ? null : after.educationLevel,
      subjectIds: after.sameSubjectsAs(before) ? null : after.subjectIds.toList(),
    );
  }

  /// True when nothing changed, so no request is needed.
  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      email == null &&
      phoneNumber == null &&
      schoolName == null &&
      educationLevel == null &&
      subjectIds == null;

  /// Blank text becomes `null`, which is how a field is cleared.
  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> toJson() => {
        if (firstName != null) 'first_name': firstName!.trim(),
        if (lastName != null) 'last_name': lastName!.trim(),
        if (email != null) 'email': _orNull(email),
        if (phoneNumber != null) 'phone_number': _orNull(phoneNumber),
        if (schoolName != null) 'school_name': _orNull(schoolName),
        if (educationLevel != null) 'education_level': _orNull(educationLevel),
        if (subjectIds != null) 'subject_ids': subjectIds,
      };
}

/// What the edit form holds while the user types.
class ProfileForm {
  const ProfileForm({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.school,
    required this.educationLevel,
    required this.subjectIds,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String school;

  /// One of [educationLevels], or empty when the user has not picked one.
  final String educationLevel;
  final Set<int> subjectIds;

  bool sameSubjectsAs(ProfileForm other) =>
      subjectIds.length == other.subjectIds.length && subjectIds.containsAll(other.subjectIds);

  /// `Ism`, `Familiya` and, when filled in, a syntactically valid email.
  ///
  /// The backend requires 2–50 characters for both names, and rejects an empty
  /// email string with 422 — both are checked here so the user sees Uzbek text
  /// instead of a pydantic message.
  String? validate() {
    if (firstName.trim().length < 2) return 'Ism kamida 2 ta belgidan iborat bo\'lsin';
    if (lastName.trim().length < 2) return 'Familiya kamida 2 ta belgidan iborat bo\'lsin';
    final mail = email.trim();
    if (mail.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      return "Email noto'g'ri kiritilgan";
    }
    return null;
  }

  /// Share of the fields that are filled in, as on the web's
  /// "Profil to'ldirish" bar. The web counts the avatar too, which the form
  /// does not own, so [hasAvatar] is passed in.
  int completionPercent({required bool hasAvatar}) {
    final filled = [
      hasAvatar,
      firstName.trim().isNotEmpty,
      lastName.trim().isNotEmpty,
      email.trim().isNotEmpty,
      phone.trim().isNotEmpty,
      school.trim().isNotEmpty,
      subjectIds.isNotEmpty,
    ].where((done) => done).length;
    return (filled * 100 / 7).round();
  }

  ProfileForm copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? school,
    String? educationLevel,
    Set<int>? subjectIds,
  }) {
    return ProfileForm(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      school: school ?? this.school,
      educationLevel: educationLevel ?? this.educationLevel,
      subjectIds: subjectIds ?? this.subjectIds,
    );
  }
}
