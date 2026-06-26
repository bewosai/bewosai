import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_settings.dart';
import 'data/services/api_service.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/business_repository_impl.dart';
import 'domain/repositories/business_repository.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/business_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const BewosyApp());
}

class BewosyApp extends StatelessWidget {
  const BewosyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core settings (presentation concern)
        ChangeNotifierProvider(
          create: (_) => AppSettings()..loadFromPrefs(),
        ),
        // Data layer: API service (only data layer uses this directly)
        Provider<ApiService>(create: (_) => ApiService()),
        // Data layer: Auth repository implementation
        ProxyProvider<ApiService, AuthRepositoryImpl>(
          create: (ctx) => AuthRepositoryImpl(ctx.read<ApiService>()),
          update: (_, api, __) => AuthRepositoryImpl(api),
        ),
        // Data layer: Business repository implementation (exposed as domain interface)
        ProxyProvider<ApiService, BusinessRepository>(
          create: (ctx) => BusinessRepositoryImpl(ctx.read<ApiService>()),
          update: (_, api, __) => BusinessRepositoryImpl(api),
        ),
        // Presentation layer: Auth state, uses domain use cases via repository
        ChangeNotifierProxyProvider<AuthRepositoryImpl, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthRepositoryImpl>())..loadFromStorage(),
          update: (_, repo, prev) => prev ?? AuthProvider(repo),
        ),
        // Presentation layer: Business operations via domain use cases
        ProxyProvider<BusinessRepository, BusinessProvider>(
          create: (ctx) => BusinessProvider(ctx.read<BusinessRepository>()),
          update: (_, repo, __) => BusinessProvider(repo),
        ),
      ],
      child: Consumer2<AppSettings, AuthProvider>(
        builder: (context, settings, auth, _) {
          final router = createRouter(auth);
          return MaterialApp.router(
            title: 'Bewosy',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
