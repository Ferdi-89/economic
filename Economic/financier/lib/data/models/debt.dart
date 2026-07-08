import 'package:freezed_annotation/freezed_annotation.dart';
part 'debt.freezed.dart';
part 'debt.g.dart';

@freezed
class Debt with _$Debt {
  const factory Debt({
    required String id,
    required String userId,
    required String contactName,
    required double amount,
    required String type,
    DateTime? dueDate,
    @Default('unpaid') String status,
    required DateTime createdAt,
  }) = _Debt;

  factory Debt.fromJson(Map<String, dynamic> json) => _$DebtFromJson(json);

  const Debt._();

  bool get isDebt => type == 'debt';
  bool get isLoan => type == 'loan';
  bool get isPaid => status == 'paid';
}
