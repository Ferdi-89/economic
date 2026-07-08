import 'package:freezed_annotation/freezed_annotation.dart';
part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    String? fullName,
    String? avatarUrl,
    String? defaultCurrency,
    @Default('id_ID') String locale,
    String? theme,
    @Default(false) bool emailNotifications,
    @Default(false) bool pushNotifications,
    @Default(0) int monthlyBudgetAlert,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}
