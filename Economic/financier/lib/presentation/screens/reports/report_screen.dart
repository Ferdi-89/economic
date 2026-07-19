import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/models/account.dart';
import '../../widgets/transaction_tile.dart';

final reportProvider = FutureProvider.autoDispose<ReportData>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  final txRepo = ref.read(transactionRepositoryProvider);
  final catRepo = ref.read(categoryRepositoryProvider);
  final accRepo = ref.read(accountRepositoryProvider);

  final now = DateTime.now();
  final months = List.generate(6, (i) => DateTime(now.year, now.month - i, 1));

  final monthData = await Future.wait(months.map((m) async {
    final start = m;
    final end = DateTime(m.year, m.month + 1, 0);
    final income = await txRepo.getTotalIncome(userId, start, end);
    final expense = await txRepo.getTotalExpense(userId, start, end);
    return (month: DateFormat('MMM', 'id').format(m), income: income, expense: expense);
  }));

  final categories = await catRepo.getAll(userId, type: 'expense');
  final accounts = await accRepo.getAll(userId);
  final recentTxs = await txRepo.getAll(
      userId, startDate: months.last, endDate: now, limit: 500);

  // Category breakdown
  final catSpending = <String, double>{};
  for (final tx in recentTxs.where((t) => t.type == 'expense')) {
    final catId = tx.categoryId ?? 'uncategorized';
    catSpending.update(
        catId, (v) => v + tx.amount, ifAbsent: () => tx.amount);
  }

  // Account stats (Masukan & Keluaran per Rekening)
  final accountStats = <String, ({double income, double expense})>{};
  for (final acc in accounts) {
    double income = 0;
    double expense = 0;
    for (final tx in recentTxs) {
      if (tx.accountId == acc.id) {
        if (tx.type == 'income') {
          income += tx.amount;
        } else if (tx.type == 'expense') {
          expense += tx.amount;
        } else if (tx.type == 'transfer') {
          expense += (tx.amount + tx.adminFee);
        }
      } else if (tx.transferToAccountId == acc.id) {
        if (tx.type == 'transfer') {
          income += tx.amount;
        }
      }
    }
    accountStats[acc.id] = (income: income, expense: expense);
  }

  return ReportData(
      monthlyData: monthData.reversed.toList(),
      categories: categories,
      catSpending: catSpending,
      recentTransactions: recentTxs,
      allTransactions: recentTxs,
      accounts: accounts,
      accountStats: accountStats);
});

class ReportData {
  final List<({String month, double income, double expense})> monthlyData;
  final List<Category> categories;
  final Map<String, double> catSpending;
  final List<Transaction> recentTransactions;
  final List<Transaction> allTransactions;
  final List<Account> accounts;
  final Map<String, ({double income, double expense})> accountStats;

  ReportData({
    required this.monthlyData,
    required this.categories,
    required this.catSpending,
    required this.recentTransactions,
    required this.allTransactions,
    required this.accounts,
    required this.accountStats,
  });
}

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(reportProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Keuangan')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(reportProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Monthly bar chart
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('6 Bulan Terakhir',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: d.monthlyData.fold<double>(
                                    0, (s, m) => s > m.income ? (s > m.expense ? s : m.expense) : (m.income > m.expense ? m.income : m.expense)) *
                                1.2,
                            barGroups: d.monthlyData
                                .asMap()
                                .entries
                                .map((e) => BarChartGroupData(
                                      x: e.key,
                                      barRods: [
                                        BarChartRodData(
                                            toY: e.value.income,
                                            color: const Color(0xFF10B981), // Emerald Green
                                            width: 8,
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(4))),
                                        BarChartRodData(
                                            toY: e.value.expense,
                                            color: const Color(0xFFEF4444), // Rose Red
                                            width: 8,
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(4))),
                                      ],
                                    ))
                                .toList(),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    if (v.toInt() >= 0 && v.toInt() < d.monthlyData.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          d.monthlyData[v.toInt()].month,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (v, _) => Text(
                                    '${(v / 1000).toInt()}k',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1000000,
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Chart Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legendDot(const Color(0xFF10B981), 'Pemasukan'),
                          const SizedBox(width: 24),
                          _legendDot(const Color(0xFFEF4444), 'Pengeluaran'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Stat cards
              if (d.allTransactions.isNotEmpty) ..._buildStatCards(context, d),
              const SizedBox(height: 16),

              // Category breakdown
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengeluaran per Kategori',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ...d.categories
                          .where((c) => d.catSpending.containsKey(c.id))
                          .map((c) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            color: AppColors.categoryColors[
                                                d.categories.indexOf(c) %
                                                    AppColors.categoryColors.length],
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                      c.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                    const SizedBox(width: 8),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Rp${fmt.format(d.catSpending[c.id]!.toInt())}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                      if (d.catSpending.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Belum ada data pengeluaran',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arus Kas per Rekening / Tabungan',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ...d.accounts.map((acc) {
                        final stats = d.accountStats[acc.id] ?? (income: 0.0, expense: 0.0);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    acc.type == 'bank'
                                        ? Icons.account_balance
                                        : acc.type == 'cash'
                                            ? Icons.money
                                            : acc.type == 'ewallet'
                                                ? Icons.account_balance_wallet
                                                : Icons.savings,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      acc.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    'Saldo: Rp${fmt.format(acc.balance.toInt())}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Row(
                                  children: [
                                    Text(
                                      'Masukan: +Rp${fmt.format(stats.income.toInt())}',
                                      style: const TextStyle(
                                          color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Keluaran: -Rp${fmt.format(stats.expense.toInt())}',
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                            ],
                          ),
                        );
                      }),
                      if (d.accounts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Belum ada rekening terdaftar',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Recent transaction history in reports
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Transaksi Terakhir',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      if (d.recentTransactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Belum ada riwayat transaksi',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: d.recentTransactions.take(10).length, // Show top 10 items
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = d.recentTransactions[index];
                             return TransactionTile(
                               transaction: tx,
                               onDeleteSuccess: () => ref.refresh(reportProvider.future),
                             );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStatCards(BuildContext context, ReportData d) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthTx = d.allTransactions
        .where((t) => (t.date.year == now.year && t.date.month == now.month))
        .toList();
    final income = monthTx.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final expense = monthTx.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
    final net = income - expense;
    final savingsRate = income > 0 ? (net / income * 100).toInt() : 0;

    // MoM comparison
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthExpense = d.allTransactions
        .where((t) => t.type == 'expense' && t.date.year == lastMonth.year && t.date.month == lastMonth.month)
        .fold<double>(0, (s, t) => s + t.amount);
    final momPct = lastMonthExpense > 0 ? ((expense - lastMonthExpense) / lastMonthExpense * 100).toInt() : 0;

    // Daily average
    final dayCount = now.day;
    final dailyAvg = dayCount > 0 ? expense / dayCount : 0;

    // Top category
    final catMap = <String, double>{};
    for (final t in monthTx.where((t) => t.type == 'expense')) {
      final catId = t.categoryId ?? 'uncategorized';
      catMap.update(catId, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    String? topCatId;
    double topCatVal = 0;
    for (final e in catMap.entries) {
      if (e.value > topCatVal) { topCatVal = e.value; topCatId = e.key; }
    }
    final topCatName = topCatId != null
        ? d.categories.where((c) => c.id == topCatId).firstOrNull?.name ?? '–'
        : '–';

    return [
      // Row 1: Savings rate + MoM
      Row(children: [
        Expanded(child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rasio Tabungan', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('$savingsRate%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: net >= 0 ? AppColors.income : AppColors.expense)),
            Text('Bersih: ${fmt.format(net.toInt())}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ])),
        )),
        const SizedBox(width: 12),
        Expanded(child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MoM Pengeluaran', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${momPct > 0 ? '+' : ''}$momPct%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: momPct > 0 ? AppColors.expense : (momPct < 0 ? AppColors.income : theme.colorScheme.onSurface))),
            Text('Bulan lalu: ${fmt.format(lastMonthExpense.toInt())}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ])),
        )),
      ]),
      const SizedBox(height: 12),
      // Row 2: Daily avg + Top category
      Row(children: [
        Expanded(child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rata-rata Harian', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(fmt.format(dailyAvg.toInt()), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            Text('${dayCount} hari bulan ini', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ])),
        )),
        const SizedBox(width: 12),
        Expanded(child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Top Kategori', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(topCatName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Total: ${fmt.format(topCatVal.toInt())}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ])),
        )),
      ]),
      const SizedBox(height: 16),
    ];
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }
}
