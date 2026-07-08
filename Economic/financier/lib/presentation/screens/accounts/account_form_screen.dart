import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/account_repository.dart';

final _formNotifier =
    ChangeNotifierProvider.autoDispose.family<AccountFormNotifier, String?>((ref, id) => AccountFormNotifier(ref, id));

class AccountFormNotifier extends ChangeNotifier {
  final Ref ref;
  final String? editingId;
  AccountFormNotifier(this.ref, this.editingId) {
    if (editingId != null) {
      _load();
    }
  }

  String name = '';
  String type = 'cash';
  double balance = 0;
  String? bankName;
  String? accountNumber;
  bool loading = false;

  Future<void> _load() async {
    loading = true;
    notifyListeners();
    try {
      final acc = await ref.read(accountRepositoryProvider).getById(editingId!);
      name = acc.name;
      type = acc.type;
      balance = acc.balance;
      bankName = acc.bankName;
      accountNumber = acc.accountNumber;
    } catch (_) {
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> delete() async {
    if (editingId == null) return;
    loading = true;
    notifyListeners();
    try {
      await ref.read(accountRepositoryProvider).delete(editingId!);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> submit() async {
    if (name.isEmpty) return;
    loading = true;
    notifyListeners();
    try {
      final userId = ref.read(authRepositoryProvider).currentUser!.id;
      final data = {
        'user_id': userId,
        'name': name,
        'type': type,
        'balance': balance,
        if (bankName != null) 'bank_name': bankName,
        if (accountNumber != null) 'account_number': accountNumber,
      };
      if (editingId != null) {
        await ref.read(accountRepositoryProvider).update(editingId!, data);
      } else {
        await ref.read(accountRepositoryProvider).create(data);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class AccountFormScreen extends ConsumerWidget {
  final String? id;
  const AccountFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(_formNotifier(id));
    final theme = Theme.of(context);

    if (form.loading && id != null && form.name.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(id != null ? 'Edit Rekening' : 'Rekening Baru'),
        actions: [
          if (id != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => _showDeleteConfirmation(context, ref, form),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text('Tipe Rekening', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'cash',
                  label: Text('Tunai'),
                  icon: Icon(Icons.money)),
              ButtonSegment(
                  value: 'bank',
                  label: Text('Bank'),
                  icon: Icon(Icons.account_balance)),
              ButtonSegment(
                  value: 'ewallet',
                  label: Text('E-Wallet'),
                  icon: Icon(Icons.wallet)),
            ],
            selected: {form.type},
            onSelectionChanged: (v) {
              form.type = v.first;
              form.notifyListeners();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: form.name,
            decoration: const InputDecoration(
                labelText: 'Nama Rekening',
                prefixIcon: Icon(Icons.account_balance_wallet)),
            onChanged: (v) => form.name = v,
          ),
          if (form.type == 'bank') ...[
            const SizedBox(height: 16),
            TextFormField(
                initialValue: form.bankName,
                decoration: const InputDecoration(
                    labelText: 'Nama Bank',
                    prefixIcon: Icon(Icons.business)),
                onChanged: (v) => form.bankName = v),
            const SizedBox(height: 16),
            TextFormField(
                initialValue: form.accountNumber,
                decoration: const InputDecoration(
                    labelText: 'Nomor Rekening',
                    prefixIcon: Icon(Icons.numbers)),
                keyboardType: TextInputType.number,
                onChanged: (v) => form.accountNumber = v),
          ],
          const SizedBox(height: 16),
          TextFormField(
            initialValue: form.balance > 0 ? form.balance.toInt().toString() : '',
            decoration: const InputDecoration(
                labelText: 'Saldo Awal',
                prefixIcon: Icon(Icons.monetization_on),
                prefixText: 'Rp '),
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                form.balance = double.tryParse(v.replaceAll('.', '')) ?? 0,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: form.loading
                ? null
                : () async {
                    if (form.name.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama Rekening tidak boleh kosong')),
                      );
                      return;
                    }
                    await form.submit();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(id != null
                              ? 'Rekening berhasil diperbarui'
                              : 'Rekening berhasil ditambahkan'),
                        ),
                      );
                      context.go('/accounts');
                    }
                  },
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: form.loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Text(id != null ? 'Simpan' : 'Tambah Rekening',
                    style: const TextStyle(fontSize: 16)),
          ),
        ]),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, AccountFormNotifier form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Rekening'),
        content: const Text('Apakah Anda yakin ingin menghapus rekening ini? Semua transaksi terkait rekening ini juga akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(context);
              await form.delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rekening berhasil dihapus')),
                );
                context.go('/accounts');
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
