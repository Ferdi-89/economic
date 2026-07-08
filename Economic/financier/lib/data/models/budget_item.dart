import 'package:freezed_annotation/freezed_annotation.dart';
part 'budget_item.freezed.dart';
part 'budget_item.g.dart';

@freezed
class BudgetItem with _$BudgetItem {
  const factory BudgetItem({
    required String id,
    required String budgetId,
    required String categoryId,
    required double allocated,
    double? spent,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BudgetItem;

  factory BudgetItem.fromJson(Map<String, dynamic> json) => _$BudgetItemFromJson(json);
}
