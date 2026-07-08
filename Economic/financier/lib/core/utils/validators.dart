class Validators {
  static String? required(String? value, [String field = 'Field']) {
    if (value == null || value.trim().isEmpty) return '$field tidak boleh kosong';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email tidak boleh kosong';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
    final amount = double.tryParse(value.replaceAll('.', '').replaceAll(',', '.'));
    if (amount == null || amount <= 0) return 'Jumlah harus lebih dari 0';
    return null;
  }

  static String? number(String? value) {
    if (value == null || value.isEmpty) return null;
    final num = double.tryParse(value);
    if (num == null) return 'Harus berupa angka';
    return null;
  }
}
