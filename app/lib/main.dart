import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/banking/presentation/providers/banking_provider.dart';
import 'features/expenses/presentation/providers/expense_provider.dart';
import 'features/inventory/presentation/providers/inventory_provider.dart';
import 'features/parties/presentation/providers/party_provider.dart';
import 'features/purchases/presentation/providers/purchase_provider.dart';
import 'features/recycle_bin/presentation/providers/recycle_bin_provider.dart';
import 'features/reports/presentation/providers/report_provider.dart';
import 'features/sales/presentation/providers/sale_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/settings/settings_dependencies.dart';
import 'features/staff/presentation/providers/staff_provider.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const BewosaiApp());
}

class BewosaiApp extends StatefulWidget {
  const BewosaiApp({super.key});

  @override
  State<BewosaiApp> createState() => _BewosaiAppState();
}

class _BewosaiAppState extends State<BewosaiApp> {
  final _authProvider = AuthProvider();
  final _settingsProvider = createSettingsProvider()..load();
  late final _router = buildAppRouter(_authProvider);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => PartyProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BankingProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => RecycleBinProvider()),
        ChangeNotifierProvider.value(value: _settingsProvider),
      ],
      // Consumer (not context.watch) because AppColors.isDark must be set
      // *before* AppTheme.light/.dark and the rest of the tree are built —
      // every screen reads AppColors.x directly, not just Theme.of(context).
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final mode = settings.settings.themeMode;
          final resolvedDark = mode == AppThemeMode.system
              ? WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
              : mode == AppThemeMode.dark;
          AppColors.isDark = resolvedDark;

          return MaterialApp.router(
            title: 'Bewosai',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode.materialThemeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
