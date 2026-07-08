import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

class WishlistNotifier extends StateNotifier<List<WishlistItem>> {
  WishlistNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('wishlist_items');
    if (data != null) {
      try {
        final List decoded = jsonDecode(data);
        state = decoded.map((e) => WishlistItem.fromJson(e)).toList();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'wishlist_items', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void add(String name, double price, [String? url]) {
    final newItem = WishlistItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      price: price,
      url: url != null && url.trim().isNotEmpty ? url.trim() : null,
    );
    state = [...state, newItem];
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
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<WishlistItem>>((ref) {
  return WishlistNotifier();
});

final wishlistSimulationActiveProvider = StateProvider<bool>((ref) => false);
