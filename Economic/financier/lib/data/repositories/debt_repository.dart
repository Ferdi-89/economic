import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/debt.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(SupabaseConfig.client);
});

class DebtRepository {
  final SupabaseClient _client;
  DebtRepository(this._client);

  Future<List<Debt>> getAll(String userId) async {
    final res = await _client.from('debts').select().eq('user_id', userId).order('created_at');
    return (res as List).map((e) => Debt.fromJson(e)).toList();
  }

  Future<Debt> create(Map<String, dynamic> data) async {
    final res = await _client.from('debts').insert(data).select().single();
    return Debt.fromJson(res);
  }

  Future<Debt> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('debts').update(data).eq('id', id).select().single();
    return Debt.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('debts').delete().eq('id', id);
  }
}
