import 'package:dio/dio.dart';

/// A user-facing error produced from any failed API call.
///
/// [message] is already translated to Uzbek and safe to show in the UI.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;

  /// Validation errors (HTTP 422) keyed by field name, e.g. `{'username': '...'}`.
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isNetwork => statusCode == null;

  /// Converts any error (usually a [DioException]) into an [ApiException].
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return _fromDio(error);
    return const ApiException("Kutilmagan xatolik yuz berdi");
  }

  static ApiException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException("Server javob bermadi. Keyinroq qayta urinib ko'ring.");
      case DioExceptionType.connectionError:
        return const ApiException(
          "Serverga ulanib bo'lmadi. Internet yoki server manzilini tekshiring.",
        );
      case DioExceptionType.cancel:
        return const ApiException("So'rov bekor qilindi");
      default:
        break;
    }

    final response = e.response;
    if (response == null) {
      return const ApiException("Serverga ulanib bo'lmadi");
    }

    final status = response.statusCode;
    final data = response.data;

    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) {
        return ApiException(_translate(detail), statusCode: status);
      }
      if (detail is List) {
        final fields = <String, String>{};
        for (final item in detail) {
          if (item is Map) {
            final loc = item['loc'];
            final field = loc is List && loc.isNotEmpty ? loc.last.toString() : 'form';
            fields[field] = item['msg']?.toString() ?? "Noto'g'ri qiymat";
          }
        }
        final first = fields.isEmpty ? "Ma'lumotlar noto'g'ri" : fields.values.first;
        return ApiException(first, statusCode: status, fieldErrors: fields);
      }
    }

    return ApiException(_byStatus(status), statusCode: status);
  }

  static String _byStatus(int? status) {
    switch (status) {
      case 400:
        return "So'rov noto'g'ri";
      case 401:
        return 'Sessiya tugagan. Qayta kiring';
      case 403:
        return "Bu amal uchun ruxsat yo'q";
      case 404:
        return 'Maʼlumot topilmadi';
      case 500:
      case 502:
      case 503:
        return 'Serverda xatolik yuz berdi';
      default:
        return 'Xatolik yuz berdi ($status)';
    }
  }

  /// Translates known backend English messages to Uzbek.
  static String _translate(String detail) {
    const known = {
      'Invalid credentials': "Login yoki parol noto'g'ri",
      'Username already taken': 'Bu foydalanuvchi nomi band',
      'Not authenticated': 'Tizimga kirilmagan',
      'Invalid token': 'Sessiya tugagan. Qayta kiring',
      'Invalid refresh token': 'Sessiya tugagan. Qayta kiring',
      'User not found': 'Foydalanuvchi topilmadi',
      'Permission denied': "Bu amal uchun ruxsat yo'q",
      'Object not found': 'Maʼlumot topilmadi',
      'Session not found': 'Sessiya topilmadi',
      'Invalid session code': "Sessiya kodi noto'g'ri",
      'Session already started': 'Sessiya allaqachon boshlangan',
      'Quiz not found': 'Test topilmadi',
    };
    return known[detail] ?? detail;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
