class BudgetProgress {
  double percentage(double spent, double budget) {
    if (budget <= 0) return 0;
    return (spent / budget).clamp(0, 2);
  }

  bool isOverBudget(double spent, double budget) => spent > budget;

  double remaining(double spent, double budget) =>
      (budget - spent).clamp(0, double.infinity);

  String alertLevel(double percentage) {
    if (percentage >= 1) return 'critical';
    if (percentage >= 0.8) return 'warning';
    if (percentage >= 0.5) return 'normal';
    return 'safe';
  }
}
