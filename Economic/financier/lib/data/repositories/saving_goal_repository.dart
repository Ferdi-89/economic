import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/saving_goal.dart';

final savingGoalRepositoryProvider = Provider<SavingGoalRepository>((ref) {
  return SavingGoalRepository(SupabaseConfig.client);
});

class SavingGoalRepository {
  final SupabaseClient _client;
  SavingGoalRepository(this._client);

  Future<List<SavingGoal>> getAll(String userId) async {
    final res = await _client.from('saving_goals').select().eq('user_id', userId).order('created_at');
    return (res as List).map((e) => SavingGoal.fromJson(e)).toList();
  }

  Future<SavingGoal> create(Map<String, dynamic> data) async {
    final res = await _client.from('saving_goals').insert(data).select().single();
    return SavingGoal.fromJson(res);
  }

  Future<SavingGoal> update(String id, Map<String, dynamic> data) async {
    final res = await _client.from('saving_goals').update(data).eq('id', id).select().single();
    return SavingGoal.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _client.from('saving_goals').delete().eq('id', id);
  }
}
