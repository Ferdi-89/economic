class MonthlySummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int transactionCount;

  MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
  }) : balance = totalIncome - totalExpense;

  double get savingsRate =>
      totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0;
}
