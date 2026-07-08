import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/models/budget.dart';

final _budgetListProvider =
    FutureProvider.autoDispose<List<Budget>>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  return ref.read(budgetRepositoryProvider).getAll(userId);
});

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgets = ref.watch(_budgetListProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Belum ada budget',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: () =>
                              _showAddDialog(context, ref),
                          child: const Text('Buat Budget')),
                    ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FilledButton.icon(
                        onPressed: () =>
                            _showAddDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Budget Baru'),
                      ),
                    );
                  }
                  final b = list[i - 1];
                  return Card(
                    child: InkWell(
                      onTap: () => context.go('/budgets/${b.id}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(b.name,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600)),
                                    Text(
                                        'Rp${fmt.format(b.amount.toInt())}',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold)),
                                  ]),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: b.percentage.clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: theme.colorScheme
                                      .surfaceContainerHighest,
                                  valueColor:
                                      AlwaysStoppedAnimation(
                                    b.isOverBudget
                                        ? Colors.red
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  'Terpakai Rp${fmt.format((b.spent ?? 0).toInt())} dari Rp${fmt.format(b.amount.toInt())}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme
                                          .onSurfaceVariant)),
                            ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtl = TextEditingController();
    final amountCtl = TextEditingController();

    showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
              title: const Text('Budget Baru'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameCtl,
                        decoration: const InputDecoration(
                            labelText: 'Nama Budget'),
                        textCapitalization:
                            TextCapitalization.words),
                    const SizedBox(height: 16),
                    TextField(
                        controller: amountCtl,
                        decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            prefixText: 'Rp '),
                        keyboardType: TextInputType.number),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountCtl.text.replaceAll('.', '')) ?? 0;
                      if (nameCtl.text.isEmpty || amount <= 0) return;
                      final userId = ref
                          .read(authRepositoryProvider)
                          .currentUser!
                          .id;
                      await ref.read(budgetRepositoryProvider).create({
                        'user_id': userId,
                        'name': nameCtl.text,
                        'amount': amount,
                        'period': 'monthly',
                      });
                      if (dCtx.mounted) Navigator.pop(dCtx);
                      ref.invalidate(_budgetListProvider);
                    },
                    child: const Text('Simpan')),
              ],
            ));
  }
}
