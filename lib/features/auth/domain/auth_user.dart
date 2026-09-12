import '../../../core/utils/json_utils.dart';

/// A school subject from `GET /api/v1/subject/list/`.
class Subject {
  const Subject({required this.id, this.name, this.type, this.icon});

  final int id;
  final String? name;
  final String? type;

  /// Short emoji / icon key.
  final String? icon;

  String get displayName => name ?? 'Fan #$id';

  factory Subject.fromJson(Json json) => Subject(
        id: asInt(json['id']) ?? 0,
        name: asString(json['name']),
        type: asString(json['type']),
        icon: asString(json['icon']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'icon': icon};
}

/// Signed-in user.
///
/// Built from the login response (short form) and from `GET /api/v1/auth/me/`
/// (detailed form: contacts, school, subjects).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.role,
    this.profileImage,
    this.email,
    this.phoneNumber,
    this.schoolName,
    this.educationLevel,
    this.subjects = const [],
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;

  /// `schoolboy` | `student` | `teacher`.
  final String? role;
  final String? profileImage;
  final String? email;
  final String? phoneNumber;
  final String? schoolName;

  /// e.g. `7-sinf`, `Universitet`.
  final String? educationLevel;
  final List<Subject> subjects;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }

  /// The mobile app is for students only (`schoolboy` / `student` roles).
  bool get isStudent {
    final value = role?.toLowerCase().trim();
    return value == 'schoolboy' || value == 'student' || value == 'pupil';
  }

  factory AuthUser.fromJson(Json json) {
    // `/auth/me/` returns subjects as `[{id, subject: {...}}]`; the cached copy
    // stores plain subject objects. Both shapes are accepted.
    final subjects = asJsonList(json['subjects']).map((item) {
      final nested = item['subject'];
      return Subject.fromJson(nested is Map ? Map<String, dynamic>.from(nested) : item);
    }).toList();

    return AuthUser(
      id: asInt(json['id']) ?? 0,
      username: asString(json['username']) ?? '',
      firstName: asString(json['first_name']) ?? '',
      lastName: asString(json['last_name']) ?? '',
      role: asString(json['role']),
      profileImage: asString(json['profile_image']),
      email: asString(json['email']),
      phoneNumber: asString(json['phone_number']),
      schoolName: asString(json['school_name']),
      educationLevel: asString(json['education_level']),
      subjects: subjects,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'profile_image': profileImage,
        'email': email,
        'phone_number': phoneNumber,
        'school_name': schoolName,
        'education_level': educationLevel,
        'subjects': subjects.map((s) => s.toJson()).toList(),
      };
}

/// Data collected by the registration form.
class RegisterRequest {
  const RegisterRequest({
    required this.username,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.subjectIds,
  });

  final String username;
  final String password;
  final String firstName;
  final String lastName;
  final List<int> subjectIds;

  Map<String, dynamic> toJson() => {
        'username': username.trim().toLowerCase(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'subjects': [
          for (final id in subjectIds) {'id': id}
        ],
        'role': 'schoolboy',
      };
}
