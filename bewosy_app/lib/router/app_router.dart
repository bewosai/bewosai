import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/splash_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/select_business_screen.dart';
import '../presentation/screens/main/main_shell.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';
import '../presentation/screens/sales/sales_screen.dart';
import '../presentation/screens/purchases/purchases_screen.dart';
import '../presentation/screens/expenses/expenses_screen.dart';
import '../presentation/screens/inventory/inventory_screen.dart';
import '../presentation/screens/parties/parties_screen.dart';
import '../presentation/screens/reports/reports_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/staff/staff_screen.dart';
import '../presentation/screens/payments/payments_screen.dart';
import '../presentation/screens/recycle_bin/recycle_bin_screen.dart';
import '../presentation/screens/banking/banking_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      // Splash handles its own navigation — never redirect away from it
      if (path == '/splash') return null;

      final loggedIn = auth.isLoggedIn;
      final publicPaths = ['/login', '/create-business', '/select-business'];
      final isPublic = publicPaths.any((p) => path.startsWith(p));

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && path == '/login') {
        return auth.user?.accountType == 'personal'
            ? '/personal-dashboard'
            : '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/select-business',
        builder: (_, __) => const SelectBusinessScreen(),
      ),
      GoRoute(
        path: '/create-business',
        builder: (_, __) => const SelectBusinessScreen(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (_, __) => const SalesScreen(),
          ),
          GoRoute(
            path: '/purchases',
            builder: (_, __) => const PurchasesScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/parties',
            builder: (_, __) => const PartiesScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, __) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/payments',
            builder: (_, __) => const PaymentsScreen(),
          ),
          GoRoute(
            path: '/banking',
            builder: (_, __) => const BankingScreen(),
          ),
          GoRoute(
            path: '/personal-dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
        ],
      ),

      // Screens outside the shell (full screen, with back button)
      GoRoute(
        path: '/staff',
        builder: (_, __) => const StaffScreen(),
      ),
      GoRoute(
        path: '/recycle-bin',
        builder: (_, __) => const RecycleBinScreen(),
      ),
    ],
  );
}

