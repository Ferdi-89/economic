import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/saving_goal_repository.dart';
import '../../../data/models/saving_goal.dart';

final _goalListProvider =
    FutureProvider.autoDispose<List<SavingGoal>>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  return ref.read(savingGoalRepositoryProvider).getAll(userId);
});

class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goals = ref.watch(_goalListProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Target Tabungan')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(_goalListProvider.future),
        child: goals.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.savings_outlined, size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Belum ada target tabungan', style: theme.textTheme.titleMedium),
                    ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final g = list[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text('${(g.percentage * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: g.percentage,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            g.isCompleted ? Colors.green : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Rp${fmt.format(g.currentAmount.toInt())} dari Rp${fmt.format(g.targetAmount.toInt())}',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                      if (g.targetDate != null) ...[
                        const SizedBox(height: 4),
                        Text('Target: ${DateFormat('dd MMM yyyy', 'id').format(g.targetDate!)}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Isi Tabungan'),
                          onPressed: () => _addMoney(context, ref, g),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () => _delete(context, ref, g),
                        ),
                      ]),
                    ]),
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

  Future<void> _addMoney(BuildContext context, WidgetRef ref, SavingGoal goal) async {
    final ctl = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Isi Tabungan: ${goal.name}'),
        content: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          FilledButton(onPressed: () {
            final amount = double.tryParse(ctl.text.replaceAll('.', '')) ?? 0;
            if (amount > 0) Navigator.pop(dCtx, amount);
          }, child: const Text('Tambah')),
        ],
      ),
    );
    if (result != null && result > 0) {
      await ref.read(savingGoalRepositoryProvider).update(goal.id, {
        'current_amount': goal.currentAmount + result,
      });
      ref.invalidate(_goalListProvider);
    }
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtl = TextEditingController();
    final targetCtl = TextEditingController();
    final currentCtl = TextEditingController();
    DateTime? targetDate;

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Target Tabungan Baru'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Nama Target')),
          const SizedBox(height: 12),
          TextField(controller: targetCtl, decoration: const InputDecoration(labelText: 'Target Jumlah', prefixText: 'Rp '), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: currentCtl, decoration: const InputDecoration(labelText: 'Sudah Terkumpul (opsional)', prefixText: 'Rp '), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030));
              if (picked != null) targetDate = picked;
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Target Tanggal (opsional)', prefixIcon: Icon(Icons.calendar_today)),
              child: Text(targetDate != null ? DateFormat('dd MMM yyyy', 'id').format(targetDate!) : 'Pilih tanggal'),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final target = double.tryParse(targetCtl.text.replaceAll('.', '')) ?? 0;
              if (nameCtl.text.isEmpty || target <= 0) return;
              final userId = ref.read(authRepositoryProvider).currentUser!.id;
              await ref.read(savingGoalRepositoryProvider).create({
                'user_id': userId,
                'name': nameCtl.text,
                'target_amount': target,
                'current_amount': double.tryParse(currentCtl.text.replaceAll('.', '')) ?? 0,
                'target_date': targetDate?.toIso8601String().split('T')[0],
              });
              if (dCtx.mounted) Navigator.pop(dCtx);
              ref.invalidate(_goalListProvider);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavingGoal goal) async {
    final confirmed = await showDialog<bool?>(context: context, builder: (dCtx) => AlertDialog(
      title: const Text('Hapus Target'),
      content: Text('Hapus target "${goal.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Hapus')),
      ],
    ));
    if (confirmed != true) return;
    await ref.read(savingGoalRepositoryProvider).delete(goal.id);
    ref.invalidate(_goalListProvider);
  }
}
