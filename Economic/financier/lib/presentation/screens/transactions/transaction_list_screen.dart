import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../widgets/transaction_tile.dart';

class TransactionFilter {
  final String? accountId;
  final String? categoryId;
  final DateTimeRange? dateRange;
  final String? type;

  TransactionFilter({
    this.accountId,
    this.categoryId,
    this.dateRange,
    this.type,
  });

  TransactionFilter copyWith({
    String? accountId,
    String? categoryId,
    DateTimeRange? dateRange,
    String? type,
    bool clearAccount = false,
    bool clearCategory = false,
    bool clearDateRange = false,
    bool clearType = false,
  }) {
    return TransactionFilter(
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      type: clearType ? null : (type ?? this.type),
    );
  }
}

final txFilterProvider = StateProvider<TransactionFilter>((ref) => TransactionFilter());

final filterMetadataProvider = FutureProvider.autoDispose<({List<Account> accounts, List<Category> categories})>((ref) async {
  final userId = ref.read(authRepositoryProvider).currentUser!.id;
  final accounts = await ref.read(accountRepositoryProvider).getAll(userId);
  final categories = await ref.read(categoryRepositoryProvider).getAll(userId);
  return (accounts: accounts, categories: categories);
});

final txListProvider =
    FutureProvider.autoDispose.family<List<Transaction>, String>((ref, userId) async {
  return ref.read(transactionRepositoryProvider).getAll(userId, limit: 200);
});

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.read(authRepositoryProvider).currentUser!.id;
    final txAsync = ref.watch(txListProvider(userId));
    final filter = ref.watch(txFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_off),
            onPressed: () {
              ref.read(txFilterProvider.notifier).update((s) => TransactionFilter());
            },
            tooltip: 'Reset Filter',
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context, ref, userId),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(txListProvider(userId));
                ref.invalidate(filterMetadataProvider);
              },
              child: txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (txs) {
                  // Apply filter logic
                  var filteredTxs = txs;
                  if (filter.type != null) {
                    filteredTxs = filteredTxs.where((tx) => tx.type == filter.type).toList();
                  }
                  if (filter.accountId != null) {
                    filteredTxs = filteredTxs.where((tx) => tx.accountId == filter.accountId || tx.transferToAccountId == filter.accountId).toList();
                  }
                  if (filter.categoryId != null) {
                    filteredTxs = filteredTxs.where((tx) => tx.categoryId == filter.categoryId).toList();
                  }
                  if (filter.dateRange != null) {
                    filteredTxs = filteredTxs.where((tx) =>
                        tx.date.isAfter(filter.dateRange!.start.subtract(const Duration(seconds: 1))) &&
                        tx.date.isBefore(filter.dateRange!.end.add(const Duration(days: 1)))).toList();
                  }

                  if (filteredTxs.isEmpty) {
                    return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(txs.isEmpty ? 'Belum ada transaksi' : 'Tidak ada transaksi cocok',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            if (txs.isEmpty)
                              FilledButton(
                                  onPressed: () => context.go('/transactions/add'),
                                  child: const Text('Tambah Transaksi'))
                            else
                              TextButton(
                                  onPressed: () {
                                    ref.read(txFilterProvider.notifier).update((s) => TransactionFilter());
                                  },
                                  child: const Text('Reset Filter')),
                          ]),
                    );
                  }
                  final grouped = _groupByDate(filteredTxs);
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.length,
                    itemBuilder: (_, i) {
                      final date = grouped.keys.elementAt(i);
                      final dayTxs = grouped[date]!;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(date,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant))),
                            ...dayTxs.map((tx) => TransactionTile(
                                  transaction: tx,
                                  onDeleteSuccess: () => ref.refresh(txListProvider(userId).future),
                                )),
                            const SizedBox(height: 8),
                          ]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transactions/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, String userId) {
    final filter = ref.watch(txFilterProvider);
    final metadataAsync = ref.watch(filterMetadataProvider);

    return metadataAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (data) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Type Filter Chip
              _filterChip<String>(
                context: context,
                label: filter.type == null
                    ? 'Tipe'
                    : filter.type == 'income'
                        ? 'Pemasukan'
                        : filter.type == 'expense'
                            ? 'Pengeluaran'
                            : 'Transfer',
                isSelected: filter.type != null,
                onSelected: () => _showTypeSelector(context, ref),
                onClear: () => ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearType: true)),
              ),
              const SizedBox(width: 8),
              // Account Filter Chip
              _filterChip<Account>(
                context: context,
                label: filter.accountId == null
                    ? 'Rekening'
                    : (data.accounts.any((a) => a.id == filter.accountId)
                        ? data.accounts.firstWhere((a) => a.id == filter.accountId).name
                        : 'Lainnya'),
                isSelected: filter.accountId != null,
                onSelected: () => _showAccountSelector(context, ref, data.accounts),
                onClear: () => ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearAccount: true)),
              ),
              const SizedBox(width: 8),
              // Category Filter Chip
              _filterChip<Category>(
                context: context,
                label: filter.categoryId == null
                    ? 'Kategori'
                    : (data.categories.any((c) => c.id == filter.categoryId)
                        ? data.categories.firstWhere((c) => c.id == filter.categoryId).name
                        : 'Lainnya'),
                isSelected: filter.categoryId != null,
                onSelected: () => _showCategorySelector(context, ref, data.categories),
                onClear: () => ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearCategory: true)),
              ),
              const SizedBox(width: 8),
              // Date Range Filter Chip
              _filterChip<DateTimeRange>(
                context: context,
                label: filter.dateRange == null
                    ? 'Jangka Waktu'
                    : '${DateFormat('dd MMM').format(filter.dateRange!.start)} - ${DateFormat('dd MMM').format(filter.dateRange!.end)}',
                isSelected: filter.dateRange != null,
                onSelected: () => _showDateRangePicker(context, ref),
                onClear: () => ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearDateRange: true)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip<T>({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    return RawChip(
      label: Text(label),
      selected: isSelected,
      onPressed: onSelected,
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
      ),
      onDeleted: isSelected ? onClear : null,
      deleteIconColor: theme.colorScheme.onPrimaryContainer,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
    );
  }

  void _showTypeSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Semua Jenis'),
                onTap: () {
                  ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearType: true));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Pemasukan'),
                onTap: () {
                  ref.read(txFilterProvider.notifier).update((s) => s.copyWith(type: 'income'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Pengeluaran'),
                onTap: () {
                  ref.read(txFilterProvider.notifier).update((s) => s.copyWith(type: 'expense'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Transfer'),
                onTap: () {
                  ref.read(txFilterProvider.notifier).update((s) => s.copyWith(type: 'transfer'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountSelector(BuildContext context, WidgetRef ref, List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Semua Rekening'),
                onTap: () {
                  ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearAccount: true));
                  Navigator.pop(context);
                },
              ),
              ...accounts.map((acc) => ListTile(
                    title: Text(acc.name),
                    onTap: () {
                      ref.read(txFilterProvider.notifier).update((s) => s.copyWith(accountId: acc.id));
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showCategorySelector(BuildContext context, WidgetRef ref, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Semua Kategori'),
                onTap: () {
                  ref.read(txFilterProvider.notifier).update((s) => s.copyWith(clearCategory: true));
                  Navigator.pop(context);
                },
              ),
              ...categories.map((cat) => ListTile(
                    title: Text(cat.name),
                    onTap: () {
                      ref.read(txFilterProvider.notifier).update((s) => s.copyWith(categoryId: cat.id));
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDateRangePicker(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: ref.read(txFilterProvider).dateRange,
    );
    if (picked != null) {
      ref.read(txFilterProvider.notifier).update((s) => s.copyWith(dateRange: picked));
    }
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> txs) {
    final map = <String, List<Transaction>>{};
    for (final tx in txs) {
      final key = DateFormat('dd MMMM yyyy', 'id').format(tx.date);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }
}
