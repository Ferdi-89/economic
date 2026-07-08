import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/account.dart';
import '../../widgets/transaction_tile.dart';

final _txProvider =
    FutureProvider.autoDispose.family<List<Transaction>, String>((ref, userId) async {
  return ref.read(transactionRepositoryProvider).getAll(userId, limit: 200);
});

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.read(authRepositoryProvider).currentUser!.id;
    final txAsync = ref.watch(_txProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(_txProvider(userId).future),
        child: txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (txs) {
            if (txs.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Belum ada transaksi',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: () =>
                              context.go('/transactions/add'),
                          child: const Text('Tambah Transaksi')),
                    ]),
              );
            }
            final grouped = _groupByDate(txs);
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final date = grouped.keys.elementAt(i);
                final dayTxs = grouped[date]!;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Text(date,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme
                                      .colorScheme.onSurfaceVariant))),
                      ...dayTxs.map(
                          (tx) => TransactionTile(transaction: tx)),
                      const SizedBox(height: 8),
                    ]);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transactions/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> txs) {
    final map = <String, List<Transaction>>{};
    for (final tx in txs) {
      final key = DateFormat('dd MMMM yyyy', 'id').format(tx.date);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }
}
