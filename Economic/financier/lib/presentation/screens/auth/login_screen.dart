import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';

final _emailProvider = StateProvider<String>((ref) => '');
final _passwordProvider = StateProvider<String>((ref) => '');
final _loadingProvider = StateProvider<bool>((ref) => false);

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(_loadingProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: size.height * 0.08),
              Icon(Icons.account_balance_wallet_rounded,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Financier',
                  style: theme.textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Kelola keuanganmu dengan cerdas',
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              SizedBox(height: size.height * 0.06),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) =>
                    ref.read(_emailProvider.notifier).state = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                obscureText: true,
                onChanged: (v) =>
                    ref.read(_passwordProvider.notifier).state = v,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () {}, child: const Text('Lupa Password?')),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : () => _login(context, ref),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Masuk', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Catatan: Jika baru mendaftar, pastikan Anda memverifikasi akun melalui link konfirmasi yang dikirim ke email Anda sebelum masuk.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('atau',
                        style:
                            TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: loading ? null : () => _loginGoogle(context, ref),
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Lanjutkan dengan Google'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Belum punya akun? Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    final email = ref.read(_emailProvider);
    final password = ref.read(_passwordProvider);

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

    ref.read(_loadingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(email, password);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (context.mounted) {
        ref.read(_loadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _loginGoogle(BuildContext context, WidgetRef ref) async {
    ref.read(_loadingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (context.mounted) {
        ref.read(_loadingProvider.notifier).state = false;
      }
    }
  }
}
