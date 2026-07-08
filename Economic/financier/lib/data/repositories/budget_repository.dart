import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(SupabaseConfig.client);
});

class BudgetRepository {
  final SupabaseClient _client;
  BudgetRepository(this._client);

  Future<List<Budget>> getAll(String userId) async {
    final res = await _client.rpc('get_budgets_with_spent', params: {'p_user_id': userId});
    return (res as List).map((e) => Budget.fromJson(e)).toList();
  }

  Future<Budget> create(Map<String, dynamic> data) async {
    final res = await _client.from('budgets').insert(data).select().single();
    return Budget.fromJson(res);
  }

  Future<Budget> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('budgets').update(data).eq('id', id).select().single();
    return Budget.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }
}
