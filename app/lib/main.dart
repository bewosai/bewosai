import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/features/feature_provider.dart';
import 'core/licensing/license_provider.dart';
import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/offline/sync_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/billing/presentation/providers/billing_provider.dart';
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
import 'shared/widgets/license_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationService.instance.init();
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
  final _saleProvider = SaleProvider();
  final _partyProvider = PartyProvider();
  final _inventoryProvider = InventoryProvider();
  final _purchaseProvider = PurchaseProvider();
  final _expenseProvider = ExpenseProvider();
  final _bankingProvider = BankingProvider();
  final _licenseProvider = LicenseProvider();
  late final _router = buildAppRouter(_authProvider);

  @override
  void initState() {
    super.initState();
    // The sync drain covers Sales, Expenses, Purchases, Party payments,
    // Bank transactions, and Stock movements — every provider whose data
    // it can touch needs to refresh here, or a background sync can
    // complete successfully while that screen still shows the pre-sync
    // list until the user happens to manually reload it.
    SyncService.instance.onSynced = () {
      _saleProvider.load();
      _partyProvider.load();
      _inventoryProvider.load();
      _purchaseProvider.load();
      _expenseProvider.load();
      _bankingProvider.load();
    };
    SyncService.instance.init();
    // The backend blocks every business-scoped call with the same 403 once
    // a trial/license lapses — this is the only signal for a lapse that
    // happens mid-session, well after LicenseProvider's last explicit check.
    ApiClient.instance.onSubscriptionRequired = () => _licenseProvider.markBlocked();
    ApiClient.instance.onSessionExpired = _authProvider.sessionExpired;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _partyProvider),
        ChangeNotifierProvider.value(value: _inventoryProvider),
        ChangeNotifierProvider.value(value: _saleProvider),
        ChangeNotifierProvider.value(value: _purchaseProvider),
        ChangeNotifierProvider.value(value: _expenseProvider),
        ChangeNotifierProvider.value(value: _bankingProvider),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
        ChangeNotifierProvider(create: (_) => RecycleBinProvider()),
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProxyProvider<AuthProvider, FeatureProvider>(
          create: (_) => FeatureProvider(),
          update: (_, auth, featureProvider) {
            featureProvider!.syncBusiness(auth.currentBusiness?.id);
            return featureProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, LicenseProvider>(
          create: (_) => _licenseProvider,
          update: (_, auth, licenseProvider) {
            licenseProvider!.syncBusiness(auth.currentBusiness?.id);
            return licenseProvider;
          },
        ),
      ],
      // Consumer (not context.watch) because AppColors.isDark must be set
      // *before* AppTheme.light/.dark and the rest of the tree are built —
      // every screen reads AppColors.x directly, not just Theme.of(context).
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final mode = settings.settings.themeMode;
          AppColors.isDark = mode == AppThemeMode.dark;

          return MaterialApp.router(
            title: 'Bewosai',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode.materialThemeMode,
            // Nepali locale so Material's own widgets (date pickers, default
            // buttons) read/format in Nepali too, and so Android's IME has a
            // per-field language hint to suggest a Devanagari layout — the
            // OS keyboard's actual active language is still the user's own
            // choice (tap the globe key / add the Nepali keyboard in system
            // settings), which no app can force from here.
            locale: Locale(settings.settings.language),
            supportedLocales: const [Locale('en'), Locale('ne')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => LicenseGate(child: child!),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
