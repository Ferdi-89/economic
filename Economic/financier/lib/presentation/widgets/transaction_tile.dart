import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/transaction.dart';
import '../../core/theme/app_colors.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');
    final color = transaction.isIncome
        ? AppColors.income
        : (transaction.isExpense ? AppColors.expense : AppColors.transfer);
    final sign = transaction.isIncome ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
        trailing: Column(
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
            ]),
        minVerticalPadding: 12,
      ),
    );
  }

  IconData get _icon => transaction.isIncome
      ? Icons.arrow_downward
      : (transaction.isExpense ? Icons.arrow_upward : Icons.swap_horiz);
}
