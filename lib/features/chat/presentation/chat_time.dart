/// Chat-specific time wording, in the same Uzbek register as
/// `core/utils/formatters.dart`.
library;

const _shortMonths = [
  'yan',
  'fev',
  'mar',
  'apr',
  'may',
  'iyn',
  'iyl',
  'avg',
  'sen',
  'okt',
  'noy',
  'dek',
];

const _longMonths = [
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

const _weekdays = ['Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan', 'Yak'];

String _two(int value) => value.toString().padLeft(2, '0');

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// `14:32` — the clock shown inside a bubble.
String formatMessageClock(DateTime date) {
  final d = date.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// Right-hand stamp on a chat list row: today is a clock, yesterday is
/// `Kecha`, this week is a weekday, anything older is `12-sen`.
String formatChatStamp(DateTime date, {DateTime? now}) {
  final d = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (_sameDay(d, today)) return formatMessageClock(d);

  final yesterday = today.subtract(const Duration(days: 1));
  if (_sameDay(d, yesterday)) return 'Kecha';

  final age = today.difference(d);
  if (age.inDays < 7 && age.inDays >= 0) return _weekdays[d.weekday - 1];

  return '${d.day}-${_shortMonths[d.month - 1]}';
}

/// Separator above the first message of a day: `Bugun`, `Kecha` or
/// `9-sentyabr`.
String formatDaySeparator(DateTime date, {DateTime? now}) {
  final d = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (_sameDay(d, today)) return 'Bugun';
  if (_sameDay(d, today.subtract(const Duration(days: 1)))) return 'Kecha';
  final label = '${d.day}-${_longMonths[d.month - 1]}';
  return d.year == today.year ? label : '$label, ${d.year}';
}

/// Presence subtitle for a chat header: `oxirgi faollik 10:50`.
///
/// Returns `null` when the server never recorded a last-seen time, so the
/// header can simply show nothing rather than a made-up value.
String? formatLastSeen(DateTime? lastSeen, {DateTime? now}) {
  if (lastSeen == null) return null;
  final d = lastSeen.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (_sameDay(d, today)) return 'oxirgi faollik ${formatMessageClock(d)}';
  if (_sameDay(d, today.subtract(const Duration(days: 1)))) {
    return 'oxirgi faollik kecha ${formatMessageClock(d)}';
  }
  return 'oxirgi faollik ${d.day}-${_shortMonths[d.month - 1]}';
}
