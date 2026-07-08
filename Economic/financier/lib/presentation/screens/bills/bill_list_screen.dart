import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/bill_repository.dart';
import '../../../data/models/bill.dart';

final _billListProvider =
    FutureProvider.autoDispose<List<Bill>>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  return ref.read(billRepositoryProvider).getAll(userId);
});

class BillListScreen extends ConsumerWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bills = ref.watch(_billListProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(_billListProvider.future),
        child: bills.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_outlined, size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Belum ada tagihan', style: theme.textTheme.titleMedium),
                    ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final b = list[i];
                final overdue = !b.isPaid && b.dueDate.isBefore(DateTime.now());
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _toggleStatus(context, ref, b),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Checkbox(value: b.isPaid, onChanged: (_) => _toggleStatus(context, ref, b)),
                        CircleAvatar(
                          backgroundColor: b.isPaid
                              ? AppColors.success.withValues(alpha: 0.1)
                              : (overdue ? AppColors.error.withValues(alpha: 0.1) : theme.colorScheme.primaryContainer),
                          child: Icon(
                            b.isPaid ? Icons.check : Icons.schedule,
                            color: b.isPaid ? AppColors.success : (overdue ? AppColors.error : theme.colorScheme.primary),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.name, style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: b.isPaid ? TextDecoration.lineThrough : null,
                            color: b.isPaid ? theme.colorScheme.onSurfaceVariant : null,
                          )),
                          Text('Jatuh tempo: ${DateFormat('dd MMM yyyy', 'id').format(b.dueDate)}',
                            style: TextStyle(color: overdue ? AppColors.error : theme.colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ])),
                        Text('Rp${fmt.format(b.amount.toInt())}', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: b.isPaid ? AppColors.success : theme.colorScheme.onSurface,
                        )),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Bill bill) async {
    final newStatus = bill.isPaid ? 'pending' : 'paid';
    await ref.read(billRepositoryProvider).update(bill.id, {'status': newStatus});
    ref.invalidate(_billListProvider);
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtl = TextEditingController();
    final amountCtl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Tambah Tagihan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Nama Tagihan')),
          const SizedBox(height: 12),
          TextField(controller: amountCtl, decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp '), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: date);
              if (picked != null && dCtx.mounted) date = picked;
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Jatuh Tempo', prefixIcon: Icon(Icons.calendar_today)),
              child: Text(DateFormat('dd MMM yyyy', 'id').format(date)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtl.text.replaceAll('.', '')) ?? 0;
              if (nameCtl.text.isEmpty || amount <= 0) return;
              final userId = ref.read(authRepositoryProvider).currentUser!.id;
              await ref.read(billRepositoryProvider).create({
                'user_id': userId,
                'name': nameCtl.text,
                'amount': amount,
                'due_date': date.toIso8601String().split('T')[0],
              });
              if (dCtx.mounted) Navigator.pop(dCtx);
              ref.invalidate(_billListProvider);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
