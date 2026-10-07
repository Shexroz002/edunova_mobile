/// Small Uzbek formatting helpers (no `intl` dependency needed).
library;

const _months = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentyabr',
  'oktyabr',
  'noyabr',
  'dekabr',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// `11-sentyabr, 2026` (local time).
String formatDate(DateTime date) {
  final d = date.toLocal();
  return '${d.day}-${_months[d.month - 1]}, ${d.year}';
}

/// Heading a history row belongs under: `Bugun`, `Kecha`, `Bu hafta`, then the
/// month — `Sentyabr`, or `Sentyabr 2025` once the year is not this one.
///
/// A results list repeats the same date shape on every row otherwise; forty
/// rows carry forty copies of `11-sentyabr, 2026 · 21:29`.
String historyGroup(DateTime date, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final d = date.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;

  if (days == 0) return 'Bugun';
  if (days == 1) return 'Kecha';
  if (days < 7) return 'Bu hafta';
  final month = _months[d.month - 1];
  final name = month[0].toUpperCase() + month.substring(1);
  return d.year == today.year ? name : '$name ${d.year}';
}

/// `11-sentyabr, 2026 · 18:30` (local time).
String formatDateTime(DateTime date) {
  final d = date.toLocal();
  return '${formatDate(d)} · ${_two(d.hour)}:${_two(d.minute)}';
}

/// Countdown style: `04:59` or `1:04:59`.
String formatClock(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return hours > 0
      ? '$hours:${_two(minutes)}:${_two(seconds)}'
      : '${_two(minutes)}:${_two(seconds)}';
}

/// Seconds (possibly fractional) as `m:ss`; `—` when null.
String formatSeconds(num? seconds) {
  if (seconds == null) return '—';
  return formatClock(Duration(seconds: seconds.round()));
}

/// `40%` (rounded).
String formatPercent(double value) => '${value.round()}%';

/// Minutes as `45 daqiqa` / `1 soat` / `1 soat 30 daqiqa`.
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes daqiqa';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours soat' : '$hours soat $rest daqiqa';
}

/// Minutes in a form that fits a narrow stat tile: `45 daq`, `2 soat`,
/// `12 soat`. Hours are rounded to the nearest hour, which is precise enough
/// for a total and keeps the tile from truncating.
String formatMinutesCompact(int minutes) {
  if (minutes < 60) return '$minutes daq';
  final hours = (minutes / 60).round();
  return '$hours soat';
}

/// Relative time, worded exactly as the web notification list
/// (`StudentNotificationsPage.tsx`): `Hozir`, `5 daqiqa oldin`, `2 soat oldin`,
/// `Kecha`, `3 kun oldin`, then an absolute date.
String formatRelative(DateTime date, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(date.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Hozir';
  if (difference.inMinutes < 60) return '${difference.inMinutes} daqiqa oldin';
  if (difference.inHours < 24) return '${difference.inHours} soat oldin';
  if (difference.inDays == 1) return 'Kecha';
  if (difference.inDays < 7) return '${difference.inDays} kun oldin';
  return formatDate(date);
}

/// Relative time without the trailing "oldin", for narrow stat tiles:
/// When something in the future comes back: `ertaga`, `3 kundan keyin`.
///
/// [formatRelativeShort] answers "how long ago" and collapses every future
/// date to "hozir", so a review schedule needs its own wording.
String formatUntil(DateTime date, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final target = date.toLocal();
  final days = DateTime(target.year, target.month, target.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;

  if (days <= 0) return 'bugun';
  if (days == 1) return 'ertaga';
  if (days < 7) return '$days kundan keyin';
  return formatDate(target);
}

/// `hozir`, `5 daq`, `2 soat`, `3 kun`, then a date.
String formatRelativeShort(DateTime date, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(date.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'hozir';
  if (difference.inMinutes < 60) return '${difference.inMinutes} daq';
  if (difference.inHours < 24) return '${difference.inHours} soat';
  if (difference.inDays < 7) return '${difference.inDays} kun';
  return formatDate(date);
}

/// True when [date] falls on the same local day as [now].
bool isToday(DateTime date, {DateTime? now}) {
  final a = date.toLocal();
  final b = (now ?? DateTime.now()).toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
