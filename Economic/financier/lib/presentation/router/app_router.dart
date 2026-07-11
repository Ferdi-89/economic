import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/transactions/transaction_list_screen.dart';
import '../screens/transactions/transaction_form_screen.dart';
import '../screens/accounts/account_list_screen.dart';
import '../screens/accounts/account_form_screen.dart';
import '../screens/budgets/budget_list_screen.dart';
import '../screens/budgets/budget_detail_screen.dart';
import '../screens/reports/report_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/wishlist/wishlist_screen.dart';
import '../screens/bills/bill_list_screen.dart';
import '../screens/goals/goal_list_screen.dart';
import '../screens/debts/debt_list_screen.dart';
import '../../data/repositories/auth_repository.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final listenable = GoRouterRefreshStream(authRepo.authStateChanges);
  ref.onDispose(() => listenable.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: listenable,
    redirect: (context, state) {
      final isLoggedIn = authRepo.isAuthenticated;

      // Handle deep links from launcher widget
      if (state.uri.scheme == 'financier') {
        var path = state.uri.path;
        if (state.uri.host.isNotEmpty) {
          path = '/${state.uri.host}$path';
        }
        final query = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '$path$query';
      }

      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(
              path: '/accounts',
              builder: (_, __) => const AccountListScreen()),
          GoRoute(
              path: '/accounts/add',
              builder: (_, __) => const AccountFormScreen()),
          GoRoute(
              path: '/accounts/edit/:id',
              builder: (_, state) =>
                  AccountFormScreen(id: state.pathParameters['id'])),
          GoRoute(
              path: '/transactions',
              builder: (_, __) => const TransactionListScreen()),
          GoRoute(
              path: '/transactions/add',
              builder: (_, state) => TransactionFormScreen(
                    type: state.uri.queryParameters['type'],
                  )),
          GoRoute(
              path: '/transactions/edit/:id',
              builder: (_, state) =>
                  TransactionFormScreen(id: state.pathParameters['id'])),
          GoRoute(
              path: '/wishlist',
              builder: (_, __) => const WishlistScreen()),
          GoRoute(
              path: '/bills',
              builder: (_, __) => const BillListScreen()),
          GoRoute(
              path: '/goals',
              builder: (_, __) => const GoalListScreen()),
          GoRoute(
              path: '/debts',
              builder: (_, __) => const DebtListScreen()),
          GoRoute(
              path: '/budgets',
              builder: (_, __) => const BudgetListScreen()),
          GoRoute(
              path: '/budgets/:id',
              builder: (_, state) =>
                  BudgetDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/reports', builder: (_, __) => const ReportScreen()),
          GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final canPop = location == '/';

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _calculateIndex(context),
          onDestinationSelected: (i) => _onTap(i, context),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: 64,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, size: 22),
                selectedIcon: Icon(Icons.dashboard, size: 24),
                label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 22),
                selectedIcon: Icon(Icons.account_balance_wallet, size: 24),
                label: 'Rekening'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined, size: 22),
                selectedIcon: Icon(Icons.receipt_long, size: 24),
                label: 'Transaksi'),
            NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined, size: 22),
                selectedIcon: Icon(Icons.auto_awesome, size: 24),
                label: 'Wishlist'),
            NavigationDestination(
                icon: Icon(Icons.receipt_outlined, size: 22),
                selectedIcon: Icon(Icons.receipt, size: 24),
                label: 'Tagihan'),
            NavigationDestination(
                icon: Icon(Icons.savings_outlined, size: 22),
                selectedIcon: Icon(Icons.savings, size: 24),
                label: 'Tabungan'),
            NavigationDestination(
                icon: Icon(Icons.people_outline, size: 22),
                selectedIcon: Icon(Icons.people, size: 24),
                label: 'Hutang'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, size: 22),
                selectedIcon: Icon(Icons.bar_chart, size: 24),
                label: 'Laporan'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined, size: 22),
                selectedIcon: Icon(Icons.settings, size: 24),
                label: 'Settings'),
          ],
        ),
      ),
    );
  }

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/accounts')) return 1;
    if (location.startsWith('/transactions')) return 2;
    if (location.startsWith('/wishlist')) return 3;
    if (location.startsWith('/bills')) return 4;
    if (location.startsWith('/goals')) return 5;
    if (location.startsWith('/debts')) return 6;
    if (location.startsWith('/reports')) return 7;
    if (location.startsWith('/settings')) return 8;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/');
      case 1: context.go('/accounts');
      case 2: context.go('/transactions');
      case 3: context.go('/wishlist');
      case 4: context.go('/bills');
      case 5: context.go('/goals');
      case 6: context.go('/debts');
      case 7: context.go('/reports');
      case 8: context.go('/settings');
    }
  }
}
