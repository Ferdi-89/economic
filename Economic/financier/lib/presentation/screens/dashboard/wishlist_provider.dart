import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/supabase_config.dart';
import '../../../data/repositories/auth_repository.dart';
import 'package:uuid/uuid.dart';

class WishlistItem {
  final String id;
  final String name;
  final double price;
  final bool isEnabled;
  final String? url;

  WishlistItem({
    required this.id,
    required this.name,
    required this.price,
    this.isEnabled = true,
    this.url,
  });

  WishlistItem copyWith({
    String? id,
    String? name,
    double? price,
    bool? isEnabled,
    String? url,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isEnabled: isEnabled ?? this.isEnabled,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'isEnabled': isEnabled,
        if (url != null) 'url': url,
      };

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        isEnabled: json['isEnabled'] as bool? ?? true,
        url: json['url'] as String?,
      );

  factory WishlistItem.fromDbJson(Map<String, dynamic> json) => WishlistItem(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        isEnabled: json['is_enabled'] as bool? ?? true,
        url: json['url'] as String?,
      );
}

class WishlistNotifier extends StateNotifier<List<WishlistItem>> {
  final Ref _ref;
  bool _useDatabaseTable = false;

  WishlistNotifier(this._ref) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load local items first (offline-first)
    final localData = prefs.getString('wishlist_items');
    if (localData != null) {
      try {
        final List decoded = jsonDecode(localData);
        state = decoded.map((e) => WishlistItem.fromJson(e)).toList();
      } catch (_) {}
    }

    final isSimActive = prefs.getBool('wishlist_simulation_active') ?? false;
    _ref.read(wishlistSimulationActiveProvider.notifier).state = isSimActive;

    final authRepo = _ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) return;

    // Check storage strategy
    try {
      final res = await SupabaseConfig.client
          .from('wishlist')
          .select()
          .eq('user_id', user.id);
      
      _useDatabaseTable = true;
      final List items = res;
      state = items.map((e) => WishlistItem.fromDbJson(e)).toList();
      
      await prefs.setString(
          'wishlist_items', jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {
      _useDatabaseTable = false;
      try {
        final profile = await authRepo.getProfile(user.id);
        if (profile != null && profile.avatarUrl != null && profile.avatarUrl!.startsWith('{')) {
          final Map<String, dynamic> parsed = jsonDecode(profile.avatarUrl!);
          if (parsed.containsKey('items')) {
            final List decoded = parsed['items'];
            state = decoded.map((e) => WishlistItem.fromJson(e)).toList();
            await prefs.setString(
                'wishlist_items', jsonEncode(state.map((e) => e.toJson()).toList()));
          }
          if (parsed.containsKey('is_active')) {
            final active = parsed['is_active'] as bool;
            _ref.read(wishlistSimulationActiveProvider.notifier).state = active;
            await prefs.setBool('wishlist_simulation_active', active);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'wishlist_items', jsonEncode(state.map((e) => e.toJson()).toList()));

    final authRepo = _ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) return;

    if (_useDatabaseTable) {
      try {
        final dbList = state.map((item) => {
          'id': item.id,
          'user_id': user.id,
          'name': item.name,
          'price': item.price,
          'is_enabled': item.isEnabled,
          'url': item.url,
        }).toList();

        await SupabaseConfig.client
            .from('wishlist')
            .delete()
            .eq('user_id', user.id);

        if (dbList.isNotEmpty) {
          await SupabaseConfig.client
              .from('wishlist')
              .insert(dbList);
        }
      } catch (_) {
        _saveToProfileFallback(user.id);
      }
    } else {
      _saveToProfileFallback(user.id);
    }
  }

  Future<void> _saveToProfileFallback(String userId) async {
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final jsonString = jsonEncode({
        'is_active': _ref.read(wishlistSimulationActiveProvider),
        'items': state.map((e) => e.toJson()).toList(),
      });
      await authRepo.updateProfile(userId, {'avatar_url': jsonString});
    } catch (_) {}
  }

  void add(String name, double price, [String? url]) {
    final newItem = WishlistItem(
      id: const Uuid().v4(),
      name: name,
      price: price,
      url: url != null && url.trim().isNotEmpty ? url.trim() : null,
    );
    state = [...state, newItem];
    _save();
  }

  void updateItem(String id, String name, double price, String? url) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(
          name: name,
          price: price,
          url: url != null && url.trim().isNotEmpty ? url.trim() : null,
        );
      }
      return item;
    }).toList();
    _save();
  }

  Future<void> purchase(String itemId, String accountId, String categoryId) async {
    final item = state.firstWhere((e) => e.id == itemId);
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    try {
      // 1. Insert transaction
      final txData = {
        'user_id': user.id,
        'account_id': accountId,
        'category_id': categoryId,
        'type': 'expense',
        'amount': item.price,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'note': 'Beli Wishlist: ${item.name}',
        'status': 'completed',
      };
      await SupabaseConfig.client.from('transactions').insert(txData);

      // 2. Deduct balance
      final accRes = await SupabaseConfig.client
          .from('accounts')
          .select('balance')
          .eq('id', accountId)
          .single();
      final double currentBalance = (accRes['balance'] as num).toDouble();
      await SupabaseConfig.client
          .from('accounts')
          .update({'balance': currentBalance - item.price})
          .eq('id', accountId);

      // 3. Delete wishlist item
      await SupabaseConfig.client.from('wishlist').delete().eq('id', itemId);
    } catch (_) {
      // Offline fallback: delete local item anyway
    }

    state = state.where((item) => item.id != itemId).toList();
    _save();
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
    _save();
  }

  void toggleEnabled(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isEnabled: !item.isEnabled);
      }
      return item;
    }).toList();
    _save();
  }

  Future<void> setSimulationActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wishlist_simulation_active', active);
    _ref.read(wishlistSimulationActiveProvider.notifier).state = active;
    
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      if (!_useDatabaseTable) {
        _saveToProfileFallback(user.id);
      }
    }
  }
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<WishlistItem>>((ref) {
  return WishlistNotifier(ref);
});

final wishlistSimulationActiveProvider = StateProvider<bool>((ref) => false);
