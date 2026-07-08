import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/bill.dart';
import '../models/saving_goal.dart';
import '../models/debt.dart';

// --- Bill Repository ---
final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository(SupabaseConfig.client);
});

class BillRepository {
  final SupabaseClient _client;
  BillRepository(this._client);

  Future<List<Bill>> getAll(String userId) async {
    try {
      final res = await _client.from('bills').select().eq('user_id', userId).order('due_date');
      return (res as List).map((e) => Bill.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('bills').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('bills').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('bills').delete().eq('id', id);
  }
}

// --- SavingGoal Repository ---
final savingGoalRepositoryProvider = Provider<SavingGoalRepository>((ref) {
  return SavingGoalRepository(SupabaseConfig.client);
});

class SavingGoalRepository {
  final SupabaseClient _client;
  SavingGoalRepository(this._client);

  Future<List<SavingGoal>> getAll(String userId) async {
    try {
      final res = await _client.from('saving_goals').select().eq('user_id', userId).order('created_at');
      return (res as List).map((e) => SavingGoal.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('saving_goals').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('saving_goals').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('saving_goals').delete().eq('id', id);
  }
}

// --- Debt Repository ---
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(SupabaseConfig.client);
});

class DebtRepository {
  final SupabaseClient _client;
  DebtRepository(this._client);

  Future<List<Debt>> getAll(String userId) async {
    try {
      final res = await _client.from('debts').select().eq('user_id', userId).order('created_at');
      return (res as List).map((e) => Debt.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('debts').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('debts').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('debts').delete().eq('id', id);
  }
}
