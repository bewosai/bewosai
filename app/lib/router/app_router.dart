import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/select_business_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/banking/presentation/screens/banking_screen.dart';
import '../features/expenses/presentation/screens/expenses_screen.dart';
import '../features/parties/presentation/screens/party_ledger_screen.dart';
import '../features/recycle_bin/presentation/screens/recycle_bin_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/sales/data/models/sale_model.dart';
import '../features/sales/presentation/screens/invoice_detail_screen.dart';
import '../features/sales/presentation/screens/pos/quick_pos_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/shell/presentation/screens/main_shell.dart';
import '../features/staff/presentation/screens/staff_screen.dart';
import '../shared/widgets/feature_gate.dart';

GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final status = authProvider.status;
      final loc = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return loc == '/' ? null : '/';
      }
      if (status == AuthStatus.loggedOut) {
        return loc == '/login' ? null : '/login';
      }
      if (status == AuthStatus.needsBusiness) {
        return loc == '/select-business' ? null : '/select-business';
      }
      // ready
      if (loc == '/' || loc == '/login' || loc == '/select-business') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/select-business', builder: (context, state) => const SelectBusinessScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          final subtab = int.tryParse(state.uri.queryParameters['subtab'] ?? '') ?? 0;
          return MainShell(initialIndex: tab, initialSubTab: subtab, navToken: state.uri.queryParameters['t'] ?? '');
        },
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) {
          final editId = state.uri.queryParameters['edit'];
          return FeatureGate(
            feature: 'pos',
            child: QuickPosScreen(
              saleId: editId != null ? int.tryParse(editId) : null,
              pendingEdit: state.extra is Sale ? state.extra as Sale : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/invoice/:id',
        builder: (context, state) => FeatureGate(
          feature: 'pos',
          child: InvoiceDetailScreen(saleId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/party-ledger/:id',
        builder: (context, state) => FeatureGate(
          feature: 'parties',
          child: PartyLedgerScreen(partyId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(path: '/expenses', builder: (context, state) => const FeatureGate(feature: 'expenses', child: ExpensesScreen())),
      GoRoute(path: '/banking', builder: (context, state) => const FeatureGate(feature: 'banking', child: BankingScreen())),
      GoRoute(path: '/reports', builder: (context, state) => const FeatureGate(feature: 'reports', child: ReportsScreen())),
      GoRoute(path: '/staff', builder: (context, state) => const FeatureGate(feature: 'staff_management', child: StaffScreen())),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/recycle-bin', builder: (context, state) => const RecycleBinScreen()),
    ],
  );
}
