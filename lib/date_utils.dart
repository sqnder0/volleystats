const _dagen = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
const _maandenKort = [
  'jan',
  'feb',
  'mrt',
  'apr',
  'mei',
  'jun',
  'jul',
  'aug',
  'sep',
  'okt',
  'nov',
  'dec',
];

/// Parses a "DD/MM/YYYY" match date into its display parts, or null if
/// [dateStr] isn't in that shape.
Map<String, dynamic>? parseMatchDate(String dateStr) {
  try {
    final parts = dateStr.split('/');
    if (parts.length != 3) return null;

    final d = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );

    return {
      'day': _dagen[d.weekday - 1],
      'dayNum': d.day,
      'month': _maandenKort[d.month - 1],
    };
  } catch (e) {
    return null;
  }
}

/// Formats a "DD/MM/YYYY" match date as e.g. "Za 12 sep".
String formatDateFull(String dateStr) {
  final parts = dateStr.split('/');
  final d = DateTime(
    int.parse(parts[2]),
    int.parse(parts[1]),
    int.parse(parts[0]),
  );
  return '${_dagen[d.weekday - 1]} ${d.day} ${_maandenKort[d.month - 1]}';
}

/// Combines a date-only [date] with an "HH:MM" [time] string into one
/// DateTime, or null if [time] isn't in that shape.
DateTime? combineDateAndTime(DateTime date, String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return DateTime(date.year, date.month, date.day, hour, minute);
}
