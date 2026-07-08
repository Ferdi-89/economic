import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dashboard/wishlist_provider.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/account.dart';
import '../../../data/repositories/category_repository.dart';


final wishlistAccountsProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  return ref.read(accountRepositoryProvider).getAll(userId);
});

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka link')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format link tidak valid')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wishlist = ref.watch(wishlistProvider);
    final isActive = ref.watch(wishlistSimulationActiveProvider);
    final accountsAsync = ref.watch(wishlistAccountsProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    final totalSimulated = wishlist
        .where((item) => item.isEnabled)
        .fold<double>(0, (sum, item) => sum + item.price);

    final actualBalance = accountsAsync.value?.fold<double>(0, (sum, acc) => sum + acc.balance) ?? 0.0;
    final simulatedRemaining = actualBalance - totalSimulated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulasi Wishlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddWishlistDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(wishlistAccountsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Simulation Summary Card
            Card(
              elevation: 4,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              color: isActive ? Colors.amber[700] : theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Simulasi Finansial',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: isActive,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (v) {
                            ref.read(wishlistProvider.notifier).setSimulationActive(v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aktifkan simulasi untuk melihat dampak pembelian wishlist terhadap total saldo Anda.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: 24),
                    
                    // Detailed calculation breakdown
                    _buildCalculationRow(
                      context,
                      'Total Saldo Asli',
                      'Rp${fmt.format(actualBalance.toInt())}',
                      theme.colorScheme.primary,
                      isBold: false,
                    ),
                    const SizedBox(height: 8),
                    _buildCalculationRow(
                      context,
                      'Potongan Wishlist Terpilih',
                      '- Rp${fmt.format(totalSimulated.toInt())}',
                      Colors.red[700]!,
                      isBold: false,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(thickness: 1),
                    ),
                    _buildCalculationRow(
                      context,
                      isActive ? 'Estimasi Sisa Saldo (Simulasi)' : 'Total Saldo',
                      'Rp${fmt.format((isActive ? simulatedRemaining : actualBalance).toInt())}',
                      isActive ? Colors.amber[800]! : theme.colorScheme.onSurface,
                      isBold: true,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Wishlist (${wishlist.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddWishlistDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (wishlist.isEmpty)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada barang di wishlist simulasi',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: wishlist.length,
                itemBuilder: (context, index) {
                  final item = wishlist[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.isEnabled && isActive 
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.isEnabled,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (v) {
                            ref.read(wishlistProvider.notifier).toggleEnabled(item.id);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: !item.isEnabled ? TextDecoration.lineThrough : null,
                                  color: !item.isEnabled ? theme.colorScheme.onSurfaceVariant : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rp${fmt.format(item.price.toInt())}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: item.isEnabled && isActive 
                                      ? theme.colorScheme.primary 
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.url != null) ...[
                          IconButton(
                            icon: Icon(Icons.link, color: theme.colorScheme.primary, size: 20),
                            tooltip: 'Buka Link Barang',
                            onPressed: () => _launchUrl(context, item.url!),
                          ),
                        ],
                        IconButton(
                          icon: Icon(Icons.shopping_cart_checkout, color: Colors.green[700], size: 20),
                          tooltip: 'Beli Barang',
                          onPressed: () => _showPurchaseDialog(context, ref, item),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.secondary, size: 20),
                          tooltip: 'Edit Barang',
                          onPressed: () => _showEditWishlistDialog(context, ref, item),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                          onPressed: () {
                            ref.read(wishlistProvider.notifier).remove(item.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(BuildContext context, String label, String value, Color valueColor, {required bool isBold, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: fontSize + 1,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddWishlistDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tambah Barang Wishlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Barang',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nama barang harus diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Harga harus diisi';
                      final parsed = double.tryParse(v.replaceAll('.', ''));
                      if (parsed == null || parsed <= 0) return 'Harga harus lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Link Barang (opsional)',
                      prefixIcon: Icon(Icons.link_outlined),
                      hintText: 'https://...',
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) return 'Link tidak valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final price = double.parse(priceController.text.replaceAll('.', ''));
                  final url = urlController.text.trim();
                  ref.read(wishlistProvider.notifier).add(name, price, url.isNotEmpty ? url : null);
                  ref.invalidate(wishlistAccountsProvider); // Refresh balance
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showPurchaseDialog(BuildContext context, WidgetRef ref, WishlistItem item) async {
    final accounts = ref.read(wishlistAccountsProvider).value ?? [];
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda belum memiliki rekening')),
      );
      return;
    }

    final userId = ref.read(authRepositoryProvider).currentUser!.id;
    final categories = await ref.read(categoryRepositoryProvider).getAll(userId, type: 'expense');

    String? selectedAccountId = accounts.first.id;
    String? selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Beli: ${item.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Sumber Rekening'),
                    items: accounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedAccountId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Kategori Pengeluaran'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedCategoryId = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
                FilledButton(
                  onPressed: () async {
                    if (selectedAccountId == null || selectedCategoryId == null) return;
                    await ref.read(wishlistProvider.notifier).purchase(
                          item.id,
                          selectedAccountId!,
                          selectedCategoryId!,
                        );
                    ref.invalidate(wishlistAccountsProvider); // Refresh balances
                    if (dCtx.mounted) Navigator.pop(dCtx);
                  },
                  child: const Text('Beli'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditWishlistDialog(BuildContext context, WidgetRef ref, WishlistItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toInt().toString());
    final urlController = TextEditingController(text: item.url ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Barang Wishlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Barang',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nama barang harus diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Harga harus diisi';
                      final parsed = double.tryParse(v.replaceAll('.', ''));
                      if (parsed == null || parsed <= 0) return 'Harga harus lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Link Barang (opsional)',
                      prefixIcon: Icon(Icons.link_outlined),
                      hintText: 'https://...',
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) return 'Link tidak valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final price = double.parse(priceController.text.replaceAll('.', ''));
                  final url = urlController.text.trim();
                  ref.read(wishlistProvider.notifier).updateItem(item.id, name, price, url.isNotEmpty ? url : null);
                  ref.invalidate(wishlistAccountsProvider); // Refresh balance
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}
