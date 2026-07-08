import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(SupabaseConfig.client);
});

class CategoryRepository {
  final SupabaseClient _client;
  CategoryRepository(this._client);

  Future<List<Category>> getAll(String userId, {String? type}) async {
    var query = _client.from('categories').select().or('user_id.eq.$userId,is_default.eq.true').eq('is_active', true);
    if (type != null) query = query.eq('type', type);
    final res = await query.order('sort_order');
    return (res as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<List<Category>> getDefaults(String type) async {
    final res = await _client.from('categories').select().eq('is_default', true).eq('type', type).order('sort_order');
    return (res as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<Category> create(Map<String, dynamic> data) async {
    final res = await _client.from('categories').insert(data).select().single();
    return Category.fromJson(res);
  }

  Future<Category> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('categories').update(data).eq('id', id).select().single();
    return Category.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
