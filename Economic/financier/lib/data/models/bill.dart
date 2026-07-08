import 'package:freezed_annotation/freezed_annotation.dart';
part 'bill.freezed.dart';
part 'bill.g.dart';

@freezed
class Bill with _$Bill {
  const factory Bill({
    required String id,
    required String userId,
    required String name,
    required double amount,
    required DateTime dueDate,
    @Default('pending') String status,
    required DateTime createdAt,
  }) = _Bill;

  factory Bill.fromJson(Map<String, dynamic> json) => _$BillFromJson(json);

  const Bill._();

  bool get isPaid => status == 'paid';
  bool get isOverdue => !isPaid && dueDate.isBefore(DateTime.now());
}
