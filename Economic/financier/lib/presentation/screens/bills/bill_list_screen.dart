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
            final urgentCount = list.where((b) => !b.isPaid && b.dueDate.difference(DateTime.now()).inDays <= 3).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (urgentCount > 0) ...[
                  Card(
                    color: Colors.red[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.red, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Auto-Pengingat: Ada $urgentCount tagihan yang mendekati jatuh tempo (dalam <= 3 hari)!',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ...list.map((b) {
                  final overdue = !b.isPaid && b.dueDate.isBefore(DateTime.now());
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: b.isPaid,
                            onChanged: (_) => _toggleStatus(context, ref, b),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _toggleStatus(context, ref, b),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: b.isPaid
                                        ? AppColors.success.withValues(alpha: 0.1)
                                        : (overdue ? AppColors.error.withValues(alpha: 0.1) : theme.colorScheme.primaryContainer),
                                    child: Icon(
                                      b.isPaid ? Icons.check : Icons.schedule,
                                      color: b.isPaid ? AppColors.success : (overdue ? AppColors.error : theme.colorScheme.primary),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            decoration: b.isPaid ? TextDecoration.lineThrough : null,
                                            color: b.isPaid ? theme.colorScheme.onSurfaceVariant : null,
                                          ),
                                        ),
                                        Text(
                                          'Jatuh tempo: ${DateFormat('dd MMM yyyy', 'id').format(b.dueDate)}',
                                          style: TextStyle(
                                            color: overdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rp${fmt.format(b.amount.toInt())}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: b.isPaid ? AppColors.success : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (!b.isPaid)
                            IconButton(
                              icon: const Icon(Icons.snooze, size: 18),
                              tooltip: 'Tunda 7 Hari',
                              onPressed: () => _postponeBill(context, ref, b),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => _showEditDialog(context, ref, b),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 18),
                            tooltip: 'Hapus',
                            onPressed: () => _deleteBill(context, ref, b),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
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

  Future<void> _postponeBill(BuildContext context, WidgetRef ref, Bill bill) async {
    final nextDate = bill.dueDate.add(const Duration(days: 7));
    await ref.read(billRepositoryProvider).update(bill.id, {
      'due_date': nextDate.toIso8601String().split('T')[0],
    });
    ref.invalidate(_billListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tagihan "${bill.name}" ditunda 7 hari ke depan.')),
      );
    }
  }

  Future<void> _deleteBill(BuildContext context, WidgetRef ref, Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tagihan'),
        content: Text('Apakah Anda yakin ingin menghapus tagihan "${bill.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(billRepositoryProvider).delete(bill.id);
      ref.invalidate(_billListProvider);
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Bill bill) {
    final nameCtl = TextEditingController(text: bill.name);
    final amountCtl = TextEditingController(text: bill.amount.toInt().toString());
    DateTime date = bill.dueDate;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Tagihan'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Nama Tagihan')),
              const SizedBox(height: 12),
              TextField(controller: amountCtl, decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp '), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDate: date);
                  if (picked != null) setState(() => date = picked);
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
                  await ref.read(billRepositoryProvider).update(bill.id, {
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
          );
        }
      ),
    );
  }
}
