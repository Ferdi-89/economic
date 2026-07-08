import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/models/debt.dart';

final _debtListProvider =
    FutureProvider.autoDispose<List<Debt>>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  return ref.read(debtRepositoryProvider).getAll(userId);
});

class DebtListScreen extends ConsumerWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final debts = ref.watch(_debtListProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    final totalDebt = debts.whenOrNull(
      data: (l) => l.where((d) => d.isDebt && !d.isPaid).fold<double>(0, (s, d) => s + d.amount),
    ) ?? 0;
    final totalLoan = debts.whenOrNull(
      data: (l) => l.where((d) => d.isLoan && !d.isPaid).fold<double>(0, (s, d) => s + d.amount),
    ) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Hutang & Piutang')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(_debtListProvider.future),
        child: debts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) => ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Column(children: [
                    Text('Hutang', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('Rp${fmt.format(totalDebt.toInt())}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense, fontSize: 18)),
                  ])),
                  Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                  Expanded(child: Column(children: [
                    Text('Piutang', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('Rp${fmt.format(totalLoan.toInt())}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.income, fontSize: 18)),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.people_outline, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('Belum ada catatan hutang/piutang', style: theme.textTheme.bodyMedium),
                  ]),
                ),
              )
            else
              ...list.map((d) => Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _toggleStatus(context, ref, d),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      Checkbox(value: d.isPaid, onChanged: (_) => _toggleStatus(context, ref, d)),
                      CircleAvatar(
                        backgroundColor: d.isDebt ? AppColors.expense.withValues(alpha: 0.1) : AppColors.income.withValues(alpha: 0.1),
                        child: Icon(
                          d.isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                          color: d.isDebt ? AppColors.expense : AppColors.income,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: d.isDebt ? AppColors.expense.withValues(alpha: 0.1) : AppColors.income.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            d.isDebt ? 'HUTANG' : 'PIUTANG',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: d.isDebt ? AppColors.expense : AppColors.income),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.contactName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (d.dueDate != null)
                          Text('Tempo: ${DateFormat('dd MMM yyyy', 'id').format(d.dueDate!)}', style: const TextStyle(fontSize: 12)),
                      ])),
                      Text('Rp${fmt.format(d.amount.toInt())}', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: d.isPaid ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                        decoration: d.isPaid ? TextDecoration.lineThrough : null,
                      )),
                    ]),
                  ),
                ),
              )),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Debt debt) async {
    final newStatus = debt.isPaid ? 'unpaid' : 'paid';
    await ref.read(debtRepositoryProvider).update(debt.id, {'status': newStatus});
    ref.invalidate(_debtListProvider);
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final contactCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String type = 'debt';
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Hutang/Piutang'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'debt', label: Text('Hutang'), icon: Icon(Icons.arrow_upward, size: 16)),
                ButtonSegment(value: 'loan', label: Text('Piutang'), icon: Icon(Icons.arrow_downward, size: 16)),
              ],
              selected: {type},
              onSelectionChanged: (v) => setState(() => type = v.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: contactCtl, decoration: const InputDecoration(labelText: 'Nama Kontak')),
            const SizedBox(height: 12),
            TextField(controller: amountCtl, decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp '), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (picked != null) setState(() => dueDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Jatuh Tempo (opsional)', prefixIcon: Icon(Icons.calendar_today)),
                child: Text(dueDate != null ? DateFormat('dd MMM yyyy', 'id').format(dueDate!) : 'Pilih tanggal'),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtl.text.replaceAll('.', '')) ?? 0;
                if (contactCtl.text.isEmpty || amount <= 0) return;
                final userId = ref.read(authRepositoryProvider).currentUser!.id;
                await ref.read(debtRepositoryProvider).create({
                  'user_id': userId,
                  'contact_name': contactCtl.text,
                  'amount': amount,
                  'type': type,
                  'due_date': dueDate?.toIso8601String().split('T')[0],
                });
                if (dCtx.mounted) Navigator.pop(dCtx);
                ref.invalidate(_debtListProvider);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
