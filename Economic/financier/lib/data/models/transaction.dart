import 'package:freezed_annotation/freezed_annotation.dart';
part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String userId,
    required String accountId,
    String? categoryId,
    required String type, // income, expense, transfer
    required double amount,
    required DateTime date,
    String? note,
    String? description,
    String? tags,
    String? receiptUrl,
    String? transferToAccountId,
    @Default(false) bool isRecurring,
    String? recurringId,
    @Default('completed') String status, // completed, pending, cancelled
    @Default(0.0) double adminFee,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);

  const Transaction._();

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';
}
