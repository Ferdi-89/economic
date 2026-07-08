import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(SupabaseConfig.client);
});

class TransactionRepository {
  final SupabaseClient _client;
  TransactionRepository(this._client);

  Future<List<Transaction>> getAll(String userId, {String? type, String? categoryId, String? accountId, DateTime? startDate, DateTime? endDate, int limit = 50, int offset = 0}) async {
    var query = _client.from('transactions').select().eq('user_id', userId);

    if (type != null) query = query.eq('type', type);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (accountId != null) query = query.eq('account_id', accountId);
    if (startDate != null) query = query.gte('date', startDate.toIso8601String());
    if (endDate != null) query = query.lte('date', endDate.toIso8601String());

    final res = await query.order('date', ascending: false).range(offset, offset + limit - 1);
    return (res as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> getById(String id) async {
    final res = await _client.from('transactions').select().eq('id', id).single();
    return Transaction.fromJson(res);
  }

  Future<Transaction> create(Map<String, dynamic> data) async {
    final res = await _client.from('transactions').insert(data).select().single();
    final tx = Transaction.fromJson(res);

    // Apply new transaction balance effect
    final double amount = tx.amount;
    final String type = tx.type;
    final String accountId = tx.accountId;
    final String? toAccountId = tx.transferToAccountId;

    if (type == 'income') {
      await _adjustAccountBalance(accountId, amount);
    } else if (type == 'expense') {
      await _adjustAccountBalance(accountId, -amount);
    } else if (type == 'transfer' && toAccountId != null) {
      await _adjustAccountBalance(accountId, -amount);
      await _adjustAccountBalance(toAccountId, amount);
    }

    return tx;
  }

  Future<Transaction> update(String id, Map<String, dynamic> data) async {
    // 1. Get the old transaction details
    final oldTx = await getById(id);

    // 2. Revert old transaction balance effect
    if (oldTx.type == 'income') {
      await _adjustAccountBalance(oldTx.accountId, -oldTx.amount);
    } else if (oldTx.type == 'expense') {
      await _adjustAccountBalance(oldTx.accountId, oldTx.amount);
    } else if (oldTx.type == 'transfer' && oldTx.transferToAccountId != null) {
      await _adjustAccountBalance(oldTx.accountId, oldTx.amount);
      await _adjustAccountBalance(oldTx.transferToAccountId!, -oldTx.amount);
    }

    // 3. Update the transaction
    final res = await _client.from('transactions').update(data).eq('id', id).select().single();
    final tx = Transaction.fromJson(res);

    // 4. Apply new transaction balance effect
    final double amount = tx.amount;
    final String type = tx.type;
    final String accountId = tx.accountId;
    final String? toAccountId = tx.transferToAccountId;

    if (type == 'income') {
      await _adjustAccountBalance(accountId, amount);
    } else if (type == 'expense') {
      await _adjustAccountBalance(accountId, -amount);
    } else if (type == 'transfer' && toAccountId != null) {
      await _adjustAccountBalance(accountId, -amount);
      await _adjustAccountBalance(toAccountId, amount);
    }

    return tx;
  }

  Future<void> delete(String id) async {
    // 1. Get the transaction details
    final tx = await getById(id);

    // 2. Revert transaction balance effect
    if (tx.type == 'income') {
      await _adjustAccountBalance(tx.accountId, -tx.amount);
    } else if (tx.type == 'expense') {
      await _adjustAccountBalance(tx.accountId, tx.amount);
    } else if (tx.type == 'transfer' && tx.transferToAccountId != null) {
      await _adjustAccountBalance(tx.accountId, tx.amount);
      await _adjustAccountBalance(tx.transferToAccountId!, -tx.amount);
    }

    // 3. Delete the transaction
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<void> _adjustAccountBalance(String accountId, double delta) async {
    try {
      final acc = await _client.from('accounts').select().eq('id', accountId).single();
      final currentBalance = (acc['balance'] as num?)?.toDouble() ?? 0.0;
      await _client.from('accounts').update({
        'balance': currentBalance + delta,
      }).eq('id', accountId);
    } catch (_) {}
  }

  Future<double> getTotalIncome(String userId, DateTime start, DateTime end) async {
    final res = await _client.rpc('get_total_income', params: {
      'p_user_id': userId,
      'p_start': start.toIso8601String(),
      'p_end': end.toIso8601String(),
    });
    return (res as num).toDouble();
  }

  Future<double> getTotalExpense(String userId, DateTime start, DateTime end) async {
    final res = await _client.rpc('get_total_expense', params: {
      'p_user_id': userId,
      'p_start': start.toIso8601String(),
      'p_end': end.toIso8601String(),
    });
    return (res as num).toDouble();
  }
}
