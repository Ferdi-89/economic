import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';

final _regEmailProvider = StateProvider<String>((ref) => '');
final _regPasswordProvider = StateProvider<String>((ref) => '');
final _regNameProvider = StateProvider<String>((ref) => '');
final _regLoadingProvider = StateProvider<bool>((ref) => false);

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(_regLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outline)),
                onChanged: (v) =>
                    ref.read(_regNameProvider.notifier).state = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) =>
                    ref.read(_regEmailProvider.notifier).state = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outlined)),
                obscureText: true,
                onChanged: (v) =>
                    ref.read(_regPasswordProvider.notifier).state = v,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : () => _register(context, ref),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Daftar', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sudah punya akun? Masuk')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final email = ref.read(_regEmailProvider);
    final password = ref.read(_regPasswordProvider);
    final name = ref.read(_regNameProvider);

    final emailError = Validators.email(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emailError)));
      return;
    }

    final passwordError = Validators.password(password);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(passwordError)));
      return;
    }

    ref.read(_regLoadingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signUp(email, password,
          fullName: name.isEmpty ? null : name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Akun berhasil dibuat. Cek email untuk verifikasi.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (context.mounted) {
        ref.read(_regLoadingProvider.notifier).state = false;
      }
    }
  }
}
