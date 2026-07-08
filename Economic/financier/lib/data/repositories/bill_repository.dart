import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/bill.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository(SupabaseConfig.client);
});

class BillRepository {
  final SupabaseClient _client;
  BillRepository(this._client);

  Future<List<Bill>> getAll(String userId) async {
    final res = await _client.from('bills').select().eq('user_id', userId).order('due_date');
    return (res as List).map((e) => Bill.fromJson(e)).toList();
  }

  Future<Bill> create(Map<String, dynamic> data) async {
    final res = await _client.from('bills').insert(data).select().single();
    return Bill.fromJson(res);
  }

  Future<Bill> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('bills').update(data).eq('id', id).select().single();
    return Bill.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('bills').delete().eq('id', id);
  }
}
