import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/licensing/license_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/license_required_screen.dart';

/// Wraps the whole app (via MaterialApp.router's `builder:`) so a trial or
/// license that lapses mid-session — not just at login — is caught the
/// moment ApiClient.onSubscriptionRequired fires, without needing every
/// route to know about license status individually. Mirrors React's
/// ProtectedRoute redirect-to-/license-required behavior, including the
/// platform-admin exemption (Super Admin must never be locked out of the
/// one panel that can generate a license in the first place).
///
/// This sits above go_router's Router (it replaces its `child` outright
/// rather than being a route), so it can't use context.go() to leave —
/// instead it *latches*: once blocked it keeps showing
/// LicenseRequiredScreen, including its own post-activation success view,
/// until that screen calls onContinue. Reacting to hasActiveSubscription
/// directly would have swapped back to `child` mid-activation (activate()
/// flips it true internally right after the request succeeds) and the user
/// would never see the "Activated Successfully" confirmation.
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  bool _showingGate = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final license = context.watch<LicenseProvider>();

    final blocked = auth.status == AuthStatus.ready &&
        auth.user?.isPlatformAdmin != true &&
        license.loaded &&
        !license.hasActiveSubscription;

    if (blocked && !_showingGate) {
      _showingGate = true;
    }

    if (_showingGate) {
      return LicenseRequiredScreen(onContinue: () => setState(() => _showingGate = false));
    }
    return widget.child;
  }
}
