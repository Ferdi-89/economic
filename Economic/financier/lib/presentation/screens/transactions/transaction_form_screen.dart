import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/models/category.dart';
import '../../../data/models/account.dart';
import '../dashboard/dashboard_screen.dart';
import 'transaction_list_screen.dart';
import '../reports/report_screen.dart';
import '../accounts/account_list_screen.dart';
import '../budgets/budget_list_screen.dart';

final _formProvider =
    ChangeNotifierProvider.autoDispose.family<TransactionFormNotifier, String?>((ref, id) {
  return TransactionFormNotifier(ref, id);
});

class TransactionFormNotifier extends ChangeNotifier {
  final Ref ref;
  final String? editingId;
  TransactionFormNotifier(this.ref, this.editingId) {
    _load();
  }

  String type = 'expense';
  String? accountId;
  String? categoryId;
  String? transferToAccountId;
  double amount = 0;
  DateTime date = DateTime.now();
  String note = '';
  bool loading = false;

  List<Account>? accounts;
  List<Category>? categories;

  Future<void> _load() async {
    final userId = ref.read(authRepositoryProvider).currentUser!.id;
    final results = await Future.wait([
      ref.read(accountRepositoryProvider).getAll(userId),
      ref.read(categoryRepositoryProvider).getAll(userId),
    ]);
    accounts = results[0] as List<Account>;
    categories = results[1] as List<Category>;

    if (editingId != null) {
      final tx = await ref.read(transactionRepositoryProvider).getById(editingId!);
      type = tx.type;
      accountId = tx.accountId;
      categoryId = tx.categoryId;
      transferToAccountId = tx.transferToAccountId;
      amount = tx.amount;
      date = tx.date;
      note = tx.note ?? '';
    }
    notifyListeners();
  }

  List<Category> get filteredCategories =>
      categories?.where((c) => c.type == type).toList() ?? [];

  void updateNote(String value) {
    note = value;
    if (type != 'transfer') {
      final rules = [
        { 'keywords': ['makan', 'minum', 'kopi', 'starbucks', 'warung', 'restoran', 'gojek', 'grab', 'gofood', 'grabfood', 'kuliner', 'food'], 'cat': 'Makanan & Minuman' },
        { 'keywords': ['bensin', 'parkir', 'tol', 'gojek', 'grab', 'mrt', 'lrt', 'krl', 'ojek', 'transport', 'taxi', 'taksi'], 'cat': 'Transportasi' },
        { 'keywords': ['nonton', 'netflix', 'spotify', 'bioskop', 'game', 'gaming', 'steam', 'hiburan', 'liburan', 'travel', 'tiket'], 'cat': 'Hiburan' },
        { 'keywords': ['skincare', 'sabun', 'shampoo', 'dokter', 'obat', 'apotek', 'sakit', 'klinik', 'kesehatan', 'gigi'], 'cat': 'Kesehatan & Perawatan' },
        { 'keywords': ['listrik', 'air', 'pdam', 'internet', 'wifi', 'pulsa', 'kuota', 'tagihan', 'bpjs'], 'cat': 'Tagihan & Utilitas' },
        { 'keywords': ['gaji', 'bonus', 'sampingan', 'deviden', 'investasi', 'bunga', 'income'], 'cat': 'Gaji' },
        { 'keywords': ['belanja', 'tokopedia', 'shopee', 'lazada', 'baju', 'kaos', 'sepatu', 'mall', 'supermarket'], 'cat': 'Belanja' }
      ];
      final noteLower = value.toLowerCase();
      for (final rule in rules) {
        final keywords = rule['keywords'] as List<String>;
        final catName = rule['cat'] as String;
        if (keywords.any((kw) => noteLower.contains(kw))) {
          final matched = filteredCategories.where(
            (c) => c.name.toLowerCase().contains(catName.toLowerCase()) || catName.toLowerCase().contains(c.name.toLowerCase()),
          ).firstOrNull;
          if (matched != null) {
            categoryId = matched.id;
            break;
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> submit() async {
    if (accountId == null || (type != 'transfer' && categoryId == null) || (type == 'transfer' && transferToAccountId == null) || amount <= 0) return;
    loading = true;
    notifyListeners();
    try {
      final userId = ref.read(authRepositoryProvider).currentUser!.id;
      final data = {
        'user_id': userId,
        'account_id': accountId,
        'category_id': categoryId,
        'type': type,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        if (type == 'transfer') 'transfer_to_account_id': transferToAccountId,
      };
      if (editingId != null) {
        await ref.read(transactionRepositoryProvider).update(editingId!, data);
      } else {
        await ref.read(transactionRepositoryProvider).create(data);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class TransactionFormScreen extends ConsumerWidget {
  final String? id;
  final String? type;
  const TransactionFormScreen({super.key, this.id, this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(_formProvider(id));

    // Set initial type if provided and we are creating a new transaction (id is null)
    if (id == null && type != null && form.type != type) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        form.type = type!;
        form.categoryId = null; // Reset category
        form.notifyListeners();
      });
    }

    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');

    final selectedAccount = form.accounts?.where((a) => a.id == form.accountId).firstOrNull;
    final selectedTransferAccount = form.accounts?.where((a) => a.id == form.transferToAccountId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(id != null ? 'Edit Transaksi' : 'Transaksi Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 'expense',
                    label: Icon(Icons.arrow_upward, size: 20)),
                ButtonSegment(
                    value: 'income',
                    label: Icon(Icons.arrow_downward, size: 20)),
                ButtonSegment(
                    value: 'transfer',
                    label: Icon(Icons.swap_horiz, size: 20)),
              ],
              selected: {form.type},
              onSelectionChanged: (v) {
                form.type = v.first;
                form.categoryId = null; // Reset selected category to prevent dropdown crash on type change
                form.notifyListeners();
              },
            ),
            const SizedBox(height: 24),
            Text('Jumlah', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey(form.editingId != null ? 'edit_amount_${form.amount}' : 'new_amount'),
              initialValue: form.amount > 0 ? form.amount.toInt().toString() : '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                prefixStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
              onChanged: (v) {
                form.amount = double.tryParse(v.replaceAll('.', '')) ?? 0;
              },
            ),
            const SizedBox(height: 20),
            
            // Rich Account Selection Tile (instead of Dropdown)
            _buildAccountSelectorTile(
              context: context,
              label: 'Rekening',
              selectedAccount: selectedAccount,
              accounts: form.accounts ?? [],
              onSelected: (acc) {
                form.accountId = acc.id;
                form.notifyListeners();
              },
              theme: theme,
              fmt: fmt,
            ),
            
            if (form.type == 'transfer') ...[
              const SizedBox(height: 20),
              _buildAccountSelectorTile(
                context: context,
                label: 'Ke Rekening',
                selectedAccount: selectedTransferAccount,
                accounts: form.accounts?.where((a) => a.id != form.accountId).toList() ?? [],
                onSelected: (acc) {
                  form.transferToAccountId = acc.id;
                  form.notifyListeners();
                },
                theme: theme,
                fmt: fmt,
              ),
            ],
            if (form.type != 'transfer') ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: form.categoryId,
                decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category)),
                items: form.filteredCategories
                    .map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) {
                  form.categoryId = v;
                  form.notifyListeners();
                },
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              key: ValueKey(form.editingId != null ? 'edit_note_${form.note}' : 'new_note'),
              initialValue: form.note,
              decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.notes)),
              maxLines: 2,
              onChanged: (v) => form.updateNote(v),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDate: form.date);
                if (picked != null) {
                  form.date = picked;
                  form.notifyListeners();
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    prefixIcon: Icon(Icons.calendar_today)),
                child: Text(
                    DateFormat('dd MMMM yyyy', 'id').format(form.date)),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: form.loading
                  ? null
                  : () async {
                      if (form.accountId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih Rekening terlebih dahulu')),
                        );
                        return;
                      }
                      if (form.type == 'transfer' && form.transferToAccountId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih Rekening tujuan transfer')),
                        );
                        return;
                      }
                      if (form.categoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih Kategori terlebih dahulu')),
                        );
                        return;
                      }
                      if (form.amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Jumlah transaksi harus lebih dari 0')),
                        );
                        return;
                      }
                       await form.submit();
                       ref.invalidate(txListProvider);
                       ref.invalidate(dashboardProvider);
                       ref.invalidate(reportProvider);
                       ref.invalidate(accountListProvider);
                       ref.invalidate(budgetListProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(id != null
                                ? 'Transaksi berhasil diperbarui'
                                : 'Transaksi berhasil ditambahkan'),
                          ),
                        );
                        context.pop();
                      }
                    },
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: form.loading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Text(id != null ? 'Simpan' : 'Tambah Transaksi',
                      style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelectorTile({
    required BuildContext context,
    required String label,
    required Account? selectedAccount,
    required List<Account> accounts,
    required Function(Account) onSelected,
    required ThemeData theme,
    required NumberFormat fmt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final Account? result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AccountSelectorPage(
                  accounts: accounts,
                  selectedAccountId: selectedAccount?.id,
                  title: 'Pilih $label',
                ),
              ),
            );
            if (result != null) {
              onSelected(result);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
            ),
            child: selectedAccount == null
                ? Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ketuk untuk memilih rekening...',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_right),
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(_accountIcon(selectedAccount.type), color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAccount.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _accountTypeName(selectedAccount.type) +
                                  (selectedAccount.bankName != null && selectedAccount.bankName!.isNotEmpty
                                      ? ' - ${selectedAccount.bankName}'
                                      : ''),
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rp${fmt.format(selectedAccount.balance.toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_arrow_right),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  IconData _accountIcon(String type) => switch (type) {
        'cash' => Icons.payments,
        'bank' => Icons.account_balance,
        'ewallet' => Icons.phone_android,
        'savings' => Icons.savings,
        _ => Icons.credit_card,
      };

  String _accountTypeName(String type) => switch (type) {
        'cash' => 'Tunai',
        'bank' => 'Bank',
        'ewallet' => 'E-Wallet',
        'savings' => 'Tabungan',
        _ => 'Lainnya',
      };
}

class AccountSelectorPage extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedAccountId;
  final String title;

  const AccountSelectorPage({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    this.title = 'Pilih Rekening',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: accounts.isEmpty
          ? Center(
              child: Text(
                'Belum ada rekening',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final acc = accounts[index];
                final isSelected = acc.id == selectedAccountId;

                return Card(
                  elevation: isSelected ? 2 : 0,
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                      : theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      child: Icon(
                        _accountIcon(acc.type),
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      acc.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _accountTypeName(acc.type) +
                              (acc.bankName != null && acc.bankName!.isNotEmpty
                                  ? ' - ${acc.bankName}'
                                  : ''),
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                        if (acc.accountNumber != null && acc.accountNumber!.isNotEmpty)
                          Text(
                            'No. Rek: ${acc.accountNumber}',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rp${fmt.format(acc.balance.toInt())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.pop(context, acc),
                  ),
                );
              },
            ),
    );
  }

  IconData _accountIcon(String type) => switch (type) {
        'cash' => Icons.payments,
        'bank' => Icons.account_balance,
        'ewallet' => Icons.phone_android,
        'savings' => Icons.savings,
        _ => Icons.credit_card,
      };

  String _accountTypeName(String type) => switch (type) {
        'cash' => 'Tunai',
        'bank' => 'Bank',
        'ewallet' => 'E-Wallet',
        'savings' => 'Tabungan',
        _ => 'Lainnya',
      };
}
