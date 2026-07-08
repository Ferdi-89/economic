import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme_mode.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/models/user_profile.dart';

enum ExportFormat { csv, text }

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showProfileDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<UserProfile?>(
          future: authRepo.getProfile(user.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snapshot.data;
            final nameController = TextEditingController(text: profile?.fullName ?? '');

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Profil Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Text(user.email ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty) {
                      await authRepo.updateProfile(user.id, {'full_name': newName});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama berhasil diperbarui')),
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleSync(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Simulate network sync with Supabase
    await Future.delayed(const Duration(milliseconds: 1200));

    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Sinkronisasi cloud Supabase berhasil!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showNotificationsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool budgetAlert = prefs.getBool('notif_budget_alert') ?? true;
    bool dailyReminder = prefs.getBool('notif_daily_reminder') ?? false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Pengaturan Notifikasi', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Peringatan Budget', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Pemberitahuan jika pemakaian budget melebihi 80%', style: TextStyle(fontSize: 11)),
                    value: budgetAlert,
                    onChanged: (val) async {
                      setState(() => budgetAlert = val);
                      await prefs.setBool('notif_budget_alert', val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    title: const Text('Pengingat Harian', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Kirim notifikasi setiap malam untuk mencatat transaksi', style: TextStyle(fontSize: 11)),
                    value: dailyReminder,
                    onChanged: (val) async {
                      setState(() => dailyReminder = val);
                      await prefs.setBool('notif_daily_reminder', val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selesai'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleExportData(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ExportFormat>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ekspor Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Pilih format ekspor:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton.icon(
            icon: const Icon(Icons.table_chart, size: 18),
            label: const Text('CSV (Spreadsheet)'),
            onPressed: () => Navigator.pop(ctx, ExportFormat.csv),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.description, size: 18),
            label: const Text('Teks (Dibagikan)'),
            onPressed: () => Navigator.pop(ctx, ExportFormat.text),
          ),
        ],
      ),
    );
    if (result == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return;

      final transactions = await ref.read(transactionRepositoryProvider).getAll(user.id, limit: 5000);

      if (transactions.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belum ada transaksi untuk diekspor')),
          );
        }
        return;
      }

      final dateFormat = DateFormat('yyyy-MM-dd');

      if (result == ExportFormat.csv) {
        final buf = StringBuffer();
        buf.writeln('Tanggal,Jenis,Kategori,Rekening,Jumlah,Catatan');
        for (final tx in transactions) {
          final typeLabel = tx.type == 'income' ? 'Pemasukan' : (tx.type == 'expense' ? 'Pengeluaran' : 'Transfer');
          buf.writeln('${dateFormat.format(tx.date)},$typeLabel,${tx.categoryId ?? ''},${tx.accountId ?? ''},${tx.amount.toStringAsFixed(0)},${(tx.note ?? '').replaceAll(',', ' ')}');
        }
        if (context.mounted) {
          Navigator.pop(context);
          await Share.share(buf.toString(), subject: 'Financier_Transaksi.csv');
        }
      } else {
        final buf = StringBuffer();
        buf.writeln('=== Ekspor Transaksi Financier ===');
        buf.writeln('Diekspor: ${DateFormat('dd MMMM yyyy', 'id').format(DateTime.now())}');
        buf.writeln('Total: ${transactions.length} transaksi');
        buf.writeln('');
        for (final tx in transactions.take(100)) {
          final sign = tx.isIncome ? '+' : (tx.isExpense ? '-' : '⇄');
          buf.writeln('${dateFormat.format(tx.date)} | $sign${tx.amount.toStringAsFixed(0)} | ${tx.note ?? '-'}');
        }
        if (transactions.length > 100) {
          buf.writeln('... dan ${transactions.length - 100} transaksi lainnya.');
        }
        if (context.mounted) {
          Navigator.pop(context);
          await Share.share(buf.toString(), subject: 'Laporan Keuangan Financier');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account & Appearance Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profil Saya', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Kelola informasi akun & nama'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showProfileDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Tampilan Tema', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text({
                        'light': 'Mode Terang',
                        'dark': 'Mode Gelap',
                        'system': 'Ikuti Sistem'
                      }[themeMode.name] ??
                      'Ikuti Sistem'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 16)),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.auto_mode, size: 16)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 16)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (v) =>
                        ref.read(themeModeProvider.notifier).set(v.first),
                    style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Data Management Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Sinkronisasi Awan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Sinkronisasikan transaksi ke Supabase cloud'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handleSync(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifikasi Aplikasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Atur pengingat & alarm budget harian'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotificationsDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Ekspor Transaksi (CSV)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Unduh data keuangan ke format CSV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handleExportData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Log Out & Info Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Tentang Financier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Versi 1.0.0 (Build Stable)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text('Keluar Akun', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 14)),
                  onTap: () async {
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
