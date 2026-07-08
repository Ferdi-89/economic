import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/account.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(SupabaseConfig.client);
});

class AccountRepository {
  final SupabaseClient _client;
  AccountRepository(this._client);

  Future<List<Account>> getAll(String userId) async {
    final res = await _client.from('accounts').select().eq('user_id', userId).eq('is_active', true).order('created_at');
    return (res as List).map((e) => Account.fromJson(e)).toList();
  }

  Future<Account> getById(String id) async {
    final res = await _client.from('accounts').select().eq('id', id).single();
    return Account.fromJson(res);
  }

  Future<Account> create(Map<String, dynamic> data) async {
    final res = await _client.from('accounts').insert(data).select().single();
    return Account.fromJson(res);
  }

  Future<Account> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('accounts').update(data).eq('id', id).select().single();
    return Account.fromJson(res);
  }

  Future<void> archive(String id) async {
    await _client.from('accounts').update({'is_active': false}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('accounts').delete().eq('id', id);
  }
}
