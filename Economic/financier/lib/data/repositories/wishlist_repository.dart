import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/wishlist_item.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(SupabaseConfig.client);
});

class WishlistRepository {
  final SupabaseClient _client;
  WishlistRepository(this._client);

  Future<List<WishlistItem>> getAll(String userId) async {
    final res = await _client.from('wishlist').select().eq('user_id', userId).order('created_at');
    return (res as List).map((e) => WishlistItem.fromJson(e)).toList();
  }

  Future<WishlistItem> create(Map<String, dynamic> data) async {
    final res = await _client.from('wishlist').insert(data).select().single();
    return WishlistItem.fromJson(res);
  }

  Future<WishlistItem> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('wishlist').update(data).eq('id', id).select().single();
    return WishlistItem.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('wishlist').delete().eq('id', id);
  }
}
