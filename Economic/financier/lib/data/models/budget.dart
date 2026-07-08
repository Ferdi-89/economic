import 'package:freezed_annotation/freezed_annotation.dart';
part 'budget.freezed.dart';
part 'budget.g.dart';

@freezed
class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String userId,
    required String name,
    required double amount,
    required String period, // monthly, weekly, yearly, custom
    DateTime? startDate,
    DateTime? endDate,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    // Computed from related budget_items
    double? spent,
    String? color,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);

  const Budget._();

  double get percentage => spent != null && amount > 0 ? (spent! / amount) : 0.0;
  double get remaining => amount - (spent ?? 0);
  bool get isOverBudget => spent != null && spent! > amount;
}
