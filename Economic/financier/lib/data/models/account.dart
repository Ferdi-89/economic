import 'package:freezed_annotation/freezed_annotation.dart';
part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String userId,
    required String name,
    required String type, // cash, bank, ewallet, savings, investment
    required double balance,
    String? bankName,
    String? accountNumber,
    String? icon,
    String? color,
    @Default(false) bool isArchived,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);

  const Account._();

  bool get isBank => type == 'bank';
  bool get isCash => type == 'cash';
  bool get isEWallet => type == 'ewallet';
}
