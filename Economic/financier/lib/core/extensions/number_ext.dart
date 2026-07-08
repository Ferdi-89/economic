import 'package:intl/intl.dart';

extension NumberFormatting on num {
  String toCurrency({String symbol = 'Rp', int decimalDigits = 0}) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final formatted = formatter.format(this);
    return '$symbol$formatted';
  }

  String toShortString() {
    if (this >= 1000000000) return '${(this / 1000000000).toStringAsFixed(1)}M';
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}JT';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}RB';
    return toString();
  }
}
