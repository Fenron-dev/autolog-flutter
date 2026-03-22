import 'package:intl/intl.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');
final _isoFormat = DateFormat('yyyy-MM-dd');

String formatDate(String isoDate) {
  try {
    return _dateFormat.format(DateTime.parse(isoDate));
  } catch (_) {
    return isoDate;
  }
}

String todayIso() => _isoFormat.format(DateTime.now());

String nowTime() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isSameWeek(DateTime date, DateTime ref) {
  final monday = ref.subtract(Duration(days: ref.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  return date.isAfter(monday.subtract(const Duration(days: 1))) &&
      date.isBefore(sunday.add(const Duration(days: 1)));
}

bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

bool isSameYear(DateTime a, DateTime b) => a.year == b.year;
