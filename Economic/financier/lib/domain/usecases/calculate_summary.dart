import '../entities/summary.dart';

class CalculateSummary {
  MonthlySummary call({
    required List<({String type, double amount})> transactions,
  }) {
    double income = 0, expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') income += t.amount;
      else if (t.type == 'expense') expense += t.amount;
    }
    return MonthlySummary(
      totalIncome: income,
      totalExpense: expense,
      transactionCount: transactions.length,
    );
  }
}
