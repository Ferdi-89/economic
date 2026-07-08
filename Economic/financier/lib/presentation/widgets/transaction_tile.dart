import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/transaction_repository.dart';

class TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback? onDeleteSuccess;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onDeleteSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');
    final color = transaction.isIncome
        ? AppColors.income
        : (transaction.isExpense ? AppColors.expense : AppColors.transfer);
    final sign = transaction.isIncome ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => context.go('/transactions/edit/${transaction.id}'),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(_icon, color: color, size: 20),
        ),
        title: Text(transaction.note ?? 'Transaksi',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
            DateFormat('dd MMM yyyy', 'id').format(transaction.date),
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$sign Rp${fmt.format(transaction.amount.toInt())}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                if (transaction.isTransfer)
                  Text('Transfer',
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurfaceVariant),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                if (value == 'edit') {
                  context.go('/transactions/edit/${transaction.id}');
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Transaksi'),
                      content: const Text('Apakah Anda yakin ingin menghapus transaksi ini? Saldo rekening Anda akan disesuaikan kembali.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(transactionRepositoryProvider).delete(transaction.id);
                      if (onDeleteSuccess != null) {
                        onDeleteSuccess!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaksi berhasil dihapus')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal menghapus: $e')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        minVerticalPadding: 12,
      ),
    );
  }

  IconData get _icon => transaction.isIncome
      ? Icons.arrow_downward
      : (transaction.isExpense ? Icons.arrow_upward : Icons.swap_horiz);
}
