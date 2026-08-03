import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/banking/presentation/providers/banking_provider.dart';
import 'features/expenses/presentation/providers/expense_provider.dart';
import 'features/inventory/presentation/providers/inventory_provider.dart';
import 'features/parties/presentation/providers/party_provider.dart';
import 'features/purchases/presentation/providers/purchase_provider.dart';
import 'features/recycle_bin/presentation/providers/recycle_bin_provider.dart';
import 'features/reports/presentation/providers/report_provider.dart';
import 'features/sales/presentation/providers/sale_provider.dart';
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
  runApp(const BewosyApp());
}

class BewosyApp extends StatefulWidget {
  const BewosyApp({super.key});

  @override
  State<BewosyApp> createState() => _BewosyAppState();
}

class _BewosyAppState extends State<BewosyApp> {
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
      child: MaterialApp.router(
        title: 'Bewosy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
