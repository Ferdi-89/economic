import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

/// Local storage wrapper using Hive for offline-first support.
/// Stores JSON-serialized data to be sync'd with Supabase.
class LocalStorageService {
  static const _boxName = 'financier_cache';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  // --- Cached data ---
  static Future<void> cacheJson(String key, dynamic data) async {
    await _box.put(key, jsonEncode(data));
  }

  static T? getCached<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static List<T> getCachedList<T>(
      String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  // --- Sync queue (offline mutations) ---
  static Future<void> enqueueMutation(Map<String, dynamic> mutation) async {
    final queue = _getMutationQueue();
    queue.add(mutation);
    await _box.put('sync_queue', jsonEncode(queue));
  }

  static List<Map<String, dynamic>> _getMutationQueue() {
    final raw = _box.get('sync_queue');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  static Future<void> clearMutationQueue() async {
    await _box.put('sync_queue', jsonEncode([]));
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }
}
