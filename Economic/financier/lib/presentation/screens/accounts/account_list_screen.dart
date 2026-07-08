import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/models/account.dart';

final _accountListProvider =
    FutureProvider.autoDispose<List<Account>>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  return ref.read(accountRepositoryProvider).getAll(userId);
});

class AccountListScreen extends ConsumerWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(_accountListProvider);
    final fmt = NumberFormat('#,###', 'id_ID');
    final totalBalance =
        accounts.whenOrNull(data: (a) => a.fold<double>(0, (s, a) => s + a.balance)) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekening'),
        actions: [
          TextButton(
              onPressed: () => context.go('/accounts/add'),
              child: const Text('Tambah'))
        ],
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
          Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text('Total Saldo',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Rp${fmt.format(totalBalance.toInt())}',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ])),
          ),
          const SizedBox(height: 16),
          ...list.map((a) => _accountCard(context, a, fmt)),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => context.go('/accounts/add'),
          child: const Icon(Icons.add)),
    );
  }

  Widget _accountCard(BuildContext context, Account acc, NumberFormat fmt) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(_icon(acc.type), color: theme.colorScheme.primary),
        ),
        title:
            Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(acc.typeName),
        trailing: Text(
            'Rp${fmt.format(acc.balance.toInt())}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: acc.balance >= 0
                    ? AppColors.income
                    : AppColors.expense)),
        onTap: () => context.go('/accounts/edit/${acc.id}'),
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
        'cash' => Icons.money,
        'bank' => Icons.account_balance,
        'ewallet' => Icons.wallet,
        _ => Icons.account_balance_wallet,
      };
}

extension on Account {
  String get typeName => {
        'cash': 'Tunai',
        'bank': 'Bank',
        'ewallet': 'E-Wallet',
        'savings': 'Tabungan',
        'investment': 'Investasi'
      }[type] ?? type;
}
