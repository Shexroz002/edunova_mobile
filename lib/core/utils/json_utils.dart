/// Tolerant JSON readers.
///
/// The backend is not always consistent: some numbers arrive as strings
/// (Python `Decimal`), some dates have no timezone offset. These helpers
/// keep model `fromJson` factories short and crash-free.
library;

/// A decoded JSON object.
typedef Json = Map<String, dynamic>;

/// Reads an int from `int`, `double` or numeric `String`.
int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? double.tryParse(value.toString())?.toInt();
}

/// Reads a double from `num` or numeric `String` (e.g. `"89.50"`).
double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Reads a non-empty string, returning `null` for `null` or blank values.
String? asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.trim().isEmpty ? null : text;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

/// Reads a list of JSON objects, skipping anything that is not a map.
List<Json> asJsonList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

final RegExp _hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Parses a server timestamp; values without an offset are treated as UTC.
///
/// Use for `created_at` / `updated_at` style fields.
DateTime? parseUtcDate(dynamic value) => _parseDate(value, naiveOffset: 'Z');

/// Parses a server timestamp; values without an offset are treated as
/// Asia/Tashkent wall-clock time (UTC+5).
///
/// Only use this where the backend really sends naive local time. It is **not**
/// right for participants' `joined_at`: that field arrives without an offset but
/// is UTC (verified live — a session created at 21:38 Tashkent time reports
/// `2026-09-11T16:38:41.167808`), so it needs [parseUtcDate].
DateTime? parseTashkentDate(dynamic value) => _parseDate(value, naiveOffset: '+05:00');

DateTime? _parseDate(dynamic value, {required String naiveOffset}) {
  final text = asString(value);
  if (text == null) return null;
  // Date-only values ("2026-09-11") are parsed as-is.
  if (!text.contains('T') && !text.contains(' ')) return DateTime.tryParse(text);
  final withOffset = _hasOffset.hasMatch(text) ? text : '$text$naiveOffset';
  return DateTime.tryParse(withOffset)?.toLocal();
}

/// One page of a `fastapi-pagination` response: `{items,total,page,size,pages}`.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  bool get hasMore => page < pages;

  factory PageResult.fromJson(Json json, T Function(Json item) parse) {
    return PageResult(
      items: asJsonList(json['items']).map(parse).toList(),
      total: asInt(json['total']) ?? 0,
      page: asInt(json['page']) ?? 1,
      size: asInt(json['size']) ?? 0,
      pages: asInt(json['pages']) ?? 0,
    );
  }
}
