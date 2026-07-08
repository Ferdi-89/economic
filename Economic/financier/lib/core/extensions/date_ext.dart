import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String toDefault() => DateFormat('dd MMM yyyy', 'id').format(this);
  String toFull() => DateFormat('EEEE, dd MMMM yyyy', 'id').format(this);
  String toMonthYear() => DateFormat('MMMM yyyy', 'id').format(this);
  String toMonthShort() => DateFormat('MMM', 'id').format(this);
  String toISOShort() => DateFormat('yyyy-MM-dd').format(this);
  String toTime() => DateFormat('HH:mm', 'id').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 0);
  DateTime get startOfWeek => subtract(Duration(days: weekday - 1));
  DateTime get endOfWeek => add(Duration(days: 7 - weekday));
}
