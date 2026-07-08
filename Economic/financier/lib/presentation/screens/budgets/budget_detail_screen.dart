import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/models/budget.dart';

final _budgetDetailProvider =
    FutureProvider.autoDispose.family<Budget?, String>((ref, id) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  final budgets = await ref.read(budgetRepositoryProvider).getAll(userId);
  return budgets.where((b) => b.id == id).firstOrNull;
});

class BudgetDetailScreen extends ConsumerWidget {
  final String id;
  const BudgetDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budget = ref.watch(_budgetDetailProvider(id));
    final fmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Budget')),
      body: budget.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (b) {
          if (b == null) {
            return const Center(child: Text('Budget tidak ditemukan'));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Card(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Text(b.name,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('Rp${fmt.format(b.amount.toInt())}',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: b.percentage.clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            b.isOverBudget
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Terpakai Rp${fmt.format((b.spent ?? 0).toInt())} (${(b.percentage * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                      if (b.isOverBudget) ...[
                        const SizedBox(height: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius:
                                    BorderRadius.circular(8)),
                            child: Text(
                                '⚠️ Over Budget! ${(b.percentage * 100 - 100).toStringAsFixed(0)}% melebihi batas',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600))),
                      ],
                    ])),
              ),
              const SizedBox(height: 24),
              Text('Kategori dalam Budget ini',
                  style: theme.textTheme.titleMedium),
            ]),
          );
        },
      ),
    );
  }
}
