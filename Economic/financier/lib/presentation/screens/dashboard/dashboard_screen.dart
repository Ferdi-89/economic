import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/extensions/date_ext.dart';
import '../../../core/extensions/number_ext.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/saving_goal.dart';
import '../../../data/models/debt.dart';
import '../../../data/repositories/new_features_repository.dart';
import '../../widgets/transaction_tile.dart';
import 'wishlist_provider.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  final txRepo = ref.read(transactionRepositoryProvider);
  final accRepo = ref.read(accountRepositoryProvider);
  final billRepo = ref.read(billRepositoryProvider);
  final goalRepo = ref.read(savingGoalRepositoryProvider);
  final debtRepo = ref.read(debtRepositoryProvider);
  final catRepo = ref.read(categoryRepositoryProvider);

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);

  final results = await Future.wait([
    txRepo.getAll(userId, startDate: startOfMonth, endDate: endOfMonth, limit: 100),
    txRepo.getTotalIncome(userId, startOfMonth, endOfMonth),
    txRepo.getTotalExpense(userId, startOfMonth, endOfMonth),
    accRepo.getAll(userId),
    billRepo.getAll(userId),
    goalRepo.getAll(userId),
    debtRepo.getAll(userId),
    catRepo.getAll(userId),
  ]);

  return DashboardData(
    recentTransactions: (results[0] as List<Transaction>).take(5).toList(),
    allTransactions: results[0] as List<Transaction>,
    monthlyIncome: results[1] as double,
    monthlyExpense: results[2] as double,
    accounts: results[3] as List<Account>,
    bills: results[4] as List<Bill>,
    savingGoals: results[5] as List<SavingGoal>,
    debts: results[6] as List<Debt>,
    categories: results[7] as List<Category>,
  );
});

class DashboardData {
  final List<Transaction> recentTransactions;
  final List<Transaction> allTransactions;
  final double monthlyIncome;
  final double monthlyExpense;
  final List<Account> accounts;
  final List<Bill> bills;
  final List<SavingGoal> savingGoals;
  final List<Debt> debts;
  final List<Category> categories;

  DashboardData({
    required this.recentTransactions,
    required this.allTransactions,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.accounts,
    required this.bills,
    required this.savingGoals,
    required this.debts,
    required this.categories,
  });

  double get balance => monthlyIncome - monthlyExpense;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(dashboardProvider);
    final wishlist = ref.watch(wishlistProvider);
    final isSimulationActive = ref.watch(wishlistSimulationActiveProvider);

    final simulatedDeduction = wishlist
        .where((item) => item.isEnabled)
        .fold<double>(0, (sum, item) => sum + item.price);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Halo, Selamat Datang!', 
                 style: theme.textTheme.titleMedium?.copyWith(
                     fontWeight: FontWeight.bold,
                     color: theme.colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, dd MMMM yyyy', 'id').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: wishlist.isNotEmpty,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: IconButton(
              icon: Icon(Icons.person, color: theme.colorScheme.primary),
              onPressed: () => context.go('/settings'),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          _updateWidgetData(d);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildBalanceCard(context, d, isSimulationActive, simulatedDeduction),
                const SizedBox(height: 20),
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transaksi Terbaru',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => context.go('/transactions'),
                    icon: const Icon(Icons.chevron_right, size: 16),
                    label: const Text('Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (d.recentTransactions.isEmpty)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Belum ada transaksi bulan ini',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                )
              else
                ...d.recentTransactions.map((tx) => TransactionTile(
                  transaction: tx,
                  onDeleteSuccess: () => ref.refresh(dashboardProvider.future),
                )),
              const SizedBox(height: 20),
              _buildAccountsRow(context, d, ref, isSimulationActive, simulatedDeduction),
              const SizedBox(height: 20),
              _buildMonthlyOverview(context, d),
              const SizedBox(height: 20),
              _buildTopSpendingCategories(context, d),
              const SizedBox(height: 24),
            ],
          ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, DashboardData d, bool isSimulated, double wishlistDeduction) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');
    final actualBalance = d.accounts.fold<double>(0, (sum, acc) => sum + acc.balance);
    final totalLoans = d.debts.where((debt) => debt.type == 'loan' && debt.status == 'unpaid').fold<double>(0, (sum, debt) => sum + debt.amount);
    final totalDebts = d.debts.where((debt) => debt.type == 'debt' && debt.status == 'unpaid').fold<double>(0, (sum, debt) => sum + debt.amount);
    final netWorth = actualBalance + totalLoans - totalDebts;
    final displayBalance = isSimulated ? (netWorth - wishlistDeduction) : netWorth;

    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF6366F1),
              Color(0xFF4F46E5),
              Color(0xFF3B82F6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      isSimulated ? 'Simulasi Kekayaan Bersih' : 'Kekayaan Bersih (Net Worth)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isSimulated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.animation, color: Colors.amberAccent, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'SIMULASI',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Rp${fmt.format(displayBalance.toInt())}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            if (isSimulated) ...[
              _buildNetWorthDetailRow('NW Asli', 'Rp${fmt.format(netWorth.toInt())}'),
              const SizedBox(height: 6),
              _buildNetWorthDetailRow('Potongan Wishlist', '-Rp${fmt.format(wishlistDeduction.toInt())}', color: Colors.amberAccent),
            ] else ...[
              _buildNetWorthDetailRow('Total Aset (Rekening)', 'Rp${fmt.format(actualBalance.toInt())}'),
              const SizedBox(height: 6),
              _buildNetWorthDetailRow('Hutang Saya', '-Rp${fmt.format(totalDebts.toInt())}', color: Colors.redAccent[100]),
              const SizedBox(height: 6),
              _buildNetWorthDetailRow('Piutang (Pinjaman)', '+Rp${fmt.format(totalLoans.toInt())}', color: Colors.greenAccent[100]),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      theme,
                      Icons.arrow_circle_up_rounded,
                      'Pemasukan',
                      'Rp${fmt.format(d.monthlyIncome.toInt())}',
                      const Color(0xFF4ADE80),
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _miniStat(
                      theme,
                      Icons.arrow_circle_down_rounded,
                      'Pengeluaran',
                      'Rp${fmt.format(d.monthlyExpense.toInt())}',
                      const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyOverview(BuildContext context, DashboardData d) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');
    final double expenseRatio = d.monthlyIncome > 0 ? (d.monthlyExpense / d.monthlyIncome) * 100 : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan Bulanan',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 130,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                  value: d.monthlyIncome > 0 ? d.monthlyIncome : 1,
                                  color: const Color(0xFF10B981), // Emerald Green
                                  title: '',
                                  radius: 20),
                              PieChartSectionData(
                                  value: d.monthlyExpense > 0 ? d.monthlyExpense : 1,
                                  color: const Color(0xFFEF4444), // Rose Red
                                  title: '',
                                  radius: 20),
                            ],
                            centerSpaceRadius: 36,
                            sectionsSpace: 3,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rasio',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${expenseRatio.toInt()}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendItem(const Color(0xFF10B981), 'Pemasukan', 'Rp${fmt.format(d.monthlyIncome.toInt())}'),
                        const SizedBox(height: 12),
                        _legendItem(const Color(0xFFEF4444), 'Pengeluaran', 'Rp${fmt.format(d.monthlyExpense.toInt())}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsRow(BuildContext context, DashboardData d, WidgetRef ref, bool isSimulated, double wishlistDeduction) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');

    final totalBalance = d.accounts.fold<double>(0, (sum, acc) => sum + acc.balance);
    final displayBalance = isSimulated ? (totalBalance - wishlistDeduction) : totalBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rekening Anda',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  isSimulated
                      ? 'Total Terkalkulasi: Rp${fmt.format(displayBalance.toInt())}'
                      : 'Total Saldo: Rp${fmt.format(totalBalance.toInt())}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSimulated ? Colors.amber[700] : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => context.go('/accounts'),
              icon: const Icon(Icons.chevron_right, size: 16),
              label: const Text('Kelola'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 105,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.accounts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              if (i == d.accounts.length) {
                return _addAccountCard(context, theme);
              }
              return _accountCard(context, d.accounts[i]);
            },
          ),
        ),
      ],
    );
  }

  Widget _accountCard(BuildContext context, Account acc) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');
    return SizedBox(
      width: 155,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(_accountIcon(acc.type), size: 12, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      acc.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Rp${fmt.format(acc.balance.toInt())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                _accountTypeName(acc.type),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addAccountCard(BuildContext context, ThemeData theme) {
    return SizedBox(
      width: 110,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        child: InkWell(
          onTap: () => context.go('/accounts/add'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                'Rekening Baru',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetWorthDetailRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _accountTypeName(String type) => switch (type) {
        'cash' => 'Tunai',
        'bank' => 'Bank',
        'ewallet' => 'E-Wallet',
        'savings' => 'Tabungan',
        _ => 'Lainnya',
      };

  IconData _accountIcon(String type) => switch (type) {
        'cash' => Icons.payments,
        'bank' => Icons.account_balance,
        'ewallet' => Icons.phone_android,
        'savings' => Icons.savings,
        _ => Icons.credit_card,
      };

  Future<void> _updateWidgetData(DashboardData d) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final actualBalance = d.accounts.fold<double>(0, (sum, acc) => sum + acc.balance);
      final totalLoans = d.debts.where((debt) => debt.type == 'loan' && debt.status == 'unpaid').fold<double>(0, (sum, debt) => sum + debt.amount);
      final totalDebts = d.debts.where((debt) => debt.type == 'debt' && debt.status == 'unpaid').fold<double>(0, (sum, debt) => sum + debt.amount);
      final netWorth = actualBalance + totalLoans - totalDebts;

      await prefs.setInt('net_worth', netWorth.toInt());
      await prefs.setInt('monthly_income', d.monthlyIncome.toInt());
      await prefs.setInt('monthly_expense', d.monthlyExpense.toInt());

      // Serialize recent transactions to JSON for the list widget
      final txListJson = d.recentTransactions.map((tx) {
        final category = d.categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => Category(id: '', name: 'Lainnya', type: '', createdAt: DateTime.now()),
        );
        return {
          'title': tx.note ?? tx.description ?? 'Transaksi',
          'amount': tx.amount.toInt(),
          'type': tx.type,
          'category': category.name,
        };
      }).toList();
      await prefs.setString('recent_transactions', jsonEncode(txListJson));

      // Invoke Android update via MethodChannel
      const MethodChannel('com.financier.app/widget').invokeMethod('updateWidget');
    } catch (_) {}
  }

  Widget _buildTopSpendingCategories(BuildContext context, DashboardData d) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');

    final expenseTxs = d.allTransactions.where((tx) => tx.type == 'expense').toList();
    if (expenseTxs.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, double> categorySums = {};
    for (final tx in expenseTxs) {
      if (tx.categoryId != null) {
        categorySums[tx.categoryId!] = (categorySums[tx.categoryId!] ?? 0) + tx.amount;
      }
    }

    if (categorySums.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoriesMap = {for (final c in d.categories) c.id: c};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengeluaran Terbesar',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sortedCategories.take(4).map((entry) {
              final cat = categoriesMap[entry.key];
              final catName = cat?.name ?? 'Lainnya';
              final catIcon = cat?.icon;
              final catColor = _categoryColor(cat?.color, catName);
              final amount = entry.value;
              final percentage = d.monthlyExpense > 0 ? (amount / d.monthlyExpense) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: catColor.withValues(alpha: 0.1),
                          child: Icon(_categoryIcon(catIcon), color: catColor, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            catName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Text(
                          'Rp${fmt.format(amount.toInt())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: Colors.grey[200],
                              color: catColor,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${(percentage * 100).toInt()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String? iconName) => switch (iconName) {
        'restaurant' => Icons.restaurant,
        'directions_car' => Icons.directions_car,
        'shopping_cart' => Icons.shopping_cart,
        'receipt' => Icons.receipt,
        'movie' => Icons.movie,
        'local_hospital' => Icons.local_hospital,
        'school' => Icons.school,
        'home' => Icons.home,
        'trending_up' => Icons.trending_up,
        'work' => Icons.work,
        'code' => Icons.code,
        'store' => Icons.store,
        'card_giftcard' => Icons.card_giftcard,
        _ => Icons.category,
      };

  Color _categoryColor(String? colorStr, String categoryName) {
    if (colorStr != null && colorStr.isNotEmpty) {
      try {
        final hex = colorStr.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    final name = categoryName.toLowerCase();
    if (name.contains('makanan') || name.contains('minuman') || name.contains('eat') || name.contains('food')) return Colors.orange;
    if (name.contains('transport')) return Colors.blue;
    if (name.contains('belanja') || name.contains('shop')) return Colors.pink;
    if (name.contains('tagihan') || name.contains('bill') || name.contains('utilitas')) return Colors.amber;
    if (name.contains('hiburan') || name.contains('movie') || name.contains('play')) return Colors.purple;
    if (name.contains('sehat') || name.contains('medical') || name.contains('health')) return Colors.red;
    if (name.contains('didik') || name.contains('school') || name.contains('educat')) return Colors.indigo;
    if (name.contains('rumah') || name.contains('home') || name.contains('tinggal')) return Colors.teal;
    if (name.contains('invest') || name.contains('saham')) return Colors.cyan;
    if (name.contains('gaji') || name.contains('salary')) return Colors.green;
    if (name.contains('freelance')) return Colors.lightGreen;
    if (name.contains('bisnis') || name.contains('store')) return Colors.deepPurple;
    if (name.contains('hadiah') || name.contains('gift')) return Colors.pinkAccent;
    return Colors.blueGrey;
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
