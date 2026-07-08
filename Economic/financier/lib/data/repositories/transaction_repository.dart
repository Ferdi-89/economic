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
    return Transaction.fromJson(res);
  }

  Future<Transaction> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('transactions').update(data).eq('id', id).select().single();
    return Transaction.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
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
