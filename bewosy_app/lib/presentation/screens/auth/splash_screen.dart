import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _opacity = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _scale = Tween(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65, curve: Curves.elasticOut)));
    _taglineOpacity = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.55, 1.0, curve: Curves.easeIn));

    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNav());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _initNav() async {
    final auth = context.read<AuthProvider>();

    // Parallel: wait for animation + auth storage load (min 1.8 s splash)
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      _awaitInit(auth),
    ]);
    if (!mounted) return;
    _navigate(auth);
  }

  Future<void> _awaitInit(AuthProvider auth) async {
    if (auth.isInitialized) return;
    final completer = Completer<void>();
    void listener() {
      if (auth.isInitialized && !completer.isCompleted) {
        auth.removeListener(listener);
        completer.complete();
      }
    }
    auth.addListener(listener);
    return completer.future;
  }

  void _navigate(AuthProvider auth) {
    if (!mounted) return;
    if (auth.isLoggedIn) {
      context.go(auth.user?.accountType == 'personal'
          ? '/personal-dashboard'
          : '/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy900, Color(0xFF1a3a60), Color(0xFF0D3B6E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 60,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // App Name
                FadeTransition(
                  opacity: _opacity,
                  child: const Text(
                    'Bewosy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: const Text(
                    'Smart Business Manager',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 80),

                // Loading dots
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: const _PulsingDots(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final delay = i * 0.2;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = ((_ctrl.value - delay).clamp(0.0, 1.0));
            final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
