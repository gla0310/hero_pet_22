import 'package:intl/intl.dart';

class DateHelper {
  static String today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String nowDateTime() => DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  static String formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static String formatDateTime(DateTime date) => DateFormat('yyyy-MM-dd HH:mm').format(date);

  /// اسم اليوم بالعربي من تاريخ بصيغة yyyy-MM-dd
  static String arabicWeekday(String isoDate) {
    try {
      final date = DateTime.parse(isoDate.split(' ').first);
      const names = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return names[date.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  static String formatTime(TimeOfDayLike time) => time.format();

  static String displayDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoDate.split(' ').first);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  /// عدد أيام التأخير عن تاريخ الخروج المتوقع (0 أو أقل يعني غير متأخر)
  static int daysLate(String? expectedExitDate) {
    if (expectedExitDate == null || expectedExitDate.isEmpty) return 0;
    try {
      final expected = DateTime.parse(expectedExitDate.split(' ').first);
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final diff = todayDateOnly.difference(DateTime(expected.year, expected.month, expected.day)).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }
}

/// كلاس بسيط لتجنب الاعتماد المباشر على TimeOfDay في طبقة utils
class TimeOfDayLike {
  final int hour;
  final int minute;
  TimeOfDayLike(this.hour, this.minute);

  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
