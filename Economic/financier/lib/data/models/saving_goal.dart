import 'package:freezed_annotation/freezed_annotation.dart';
part 'saving_goal.freezed.dart';
part 'saving_goal.g.dart';

@freezed
class SavingGoal with _$SavingGoal {
  const factory SavingGoal({
    required String id,
    required String userId,
    required String name,
    required double targetAmount,
    @Default(0) double currentAmount,
    DateTime? targetDate,
    required DateTime createdAt,
  }) = _SavingGoal;

  factory SavingGoal.fromJson(Map<String, dynamic> json) => _$SavingGoalFromJson(json);

  const SavingGoal._();

  double get percentage => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0, 1) : 0;
  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);
  bool get isCompleted => currentAmount >= targetAmount;
}
