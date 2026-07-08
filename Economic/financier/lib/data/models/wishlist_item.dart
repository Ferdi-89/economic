import 'package:freezed_annotation/freezed_annotation.dart';
part 'wishlist_item.freezed.dart';
part 'wishlist_item.g.dart';

@freezed
class WishlistItem with _$WishlistItem {
  const factory WishlistItem({
    required String id,
    required String userId,
    required String name,
    required double price,
    String? url,
    @Default(true) bool isEnabled,
    required DateTime createdAt,
  }) = _WishlistItem;

  factory WishlistItem.fromJson(Map<String, dynamic> json) => _$WishlistItemFromJson(json);
}
