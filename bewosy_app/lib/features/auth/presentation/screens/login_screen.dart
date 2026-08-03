import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';

/// Login / email-OTP screen.
///
/// Flow (no Navigator.push from this screen):
/// 1. Step 0 — email → AuthProvider.sendOtp
/// 2. Step 1 — 6-digit OTP (+ name if new user) → AuthProvider.verifyOtp
/// 3. On success AuthProvider sets:
///      • AuthStatus.ready         → root shows Dashboard
///      • AuthStatus.needsBusiness → root shows SelectBusinessScreen
///
/// FUTURE_PHONE: search this file for FUTURE_PHONE when adding phone OTP.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpFocus = FocusNode();

  /// 0 = email, 1 = OTP
  int _step = 0;
  bool _remember = true;
  bool _isNewUserFlow = false;
  int _cooldown = 0;

  // The OTP field can trigger _verifyOtp() from two places (auto-submit at
  // 6 digits, and the keyboard's "Done" action) that can both fire before
  // AuthProvider.isLoading has a chance to propagate back — sending the
  // same one-time code twice. The backend consumes it atomically, so the
  // second, redundant request always comes back "Incorrect code" even
  // though the first one just succeeded. This flag is checked and set
  // synchronously, so only the first call ever gets through.
  bool _verifying = false;
  Timer? _timer;

  // FUTURE_PHONE: bool _usePhone = false;
  // FUTURE_PHONE: final _phoneController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _otpFocus.dispose();
    // FUTURE_PHONE: _phoneController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp({bool isSignup = false}) async {
    // On resend (step 1) email was already validated — skip email form check.
    if (_step == 0 && !(_emailFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final auth = context.read<AuthProvider>();
    // FUTURE_PHONE: final identity = _usePhone ? _phoneController.text.trim() : _emailController.text.trim();
    final email = _emailController.text.trim();

    final ok = await auth.sendOtp(email, isSignup: isSignup);
    if (!mounted) return;

    if (ok) {
      _isNewUserFlow = !auth.pendingUserExists;
      _otpController.clear();
      setState(() => _step = 1);
      _startCooldown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
      });
    } else if (auth.error != null) {
      showAppSnackBar(context, auth.error!, isError: true);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verifying) return;
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;

    if (_isNewUserFlow && _nameController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Please enter your name', isError: true);
      return;
    }

    _verifying = true;
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(
      _otpController.text.trim(),
      remember: _remember,
      name: _nameController.text.trim(),
    );
    _verifying = false;
    if (!mounted) return;

    // Success: AuthProvider sets ready | needsBusiness → root rebuilds.
    // Failure: show error only.
    if (!ok && auth.error != null) {
      showAppSnackBar(context, auth.error!, isError: true);
    }
  }

  void _goBackToEmail() {
    _timer?.cancel();
    _cooldown = 0;
    _otpController.clear();
    setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orangeLight.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy50,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppColors.orangeGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orange.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _step == 0
                            ? 'Welcome to ${AppConstants.appName}'
                            : 'Verify your email',
                        // FUTURE_PHONE: _usePhone ? 'Verify your phone' : 'Verify your email'
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _step == 0
                            ? 'Sign in or create an account with your email'
                            : 'We sent a 6-digit code to ${_emailController.text.trim()}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _step == 0
                            ? KeyedSubtree(
                                key: const ValueKey('email'),
                                child: _buildEmailStep(auth),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('otp'),
                                child: _buildOtpStep(auth),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStep(AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // FUTURE_PHONE: Email | Phone toggle above this field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            // FUTURE_PHONE: phone → TextInputType.phone, digitsOnly, Validators.phone
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: Validators.email,
            onFieldSubmitted: (_) {
              if (!auth.isLoading) _sendOtp();
            },
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Continue',
            isLoading: auth.isLoading,
            onPressed: auth.isLoading ? null : () => _sendOtp(),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: auth.isLoading ? null : () => _sendOtp(isSignup: true),
              child: const Text('New here? Create an account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(AuthProvider auth) {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isNewUserFlow) ...[
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (_isNewUserFlow && (v == null || v.trim().isEmpty)) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _otpController,
            focusNode: _otpFocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
            ),
            validator: Validators.otp,
            onChanged: (value) {
              if (value.length == 6) _verifyOtp();
            },
            onFieldSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: 4),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _cooldown > 0
                  ? Container(
                      key: const ValueKey('countdown'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 15,
                            color: AppColors.orangeDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '0:${_cooldown.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.orangeDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(key: ValueKey('none'), height: 0),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: _remember,
                activeColor: AppColors.orange,
                onChanged: auth.isLoading
                    ? null
                    : (v) => setState(() => _remember = v ?? true),
              ),
              const Expanded(
                child: Text(
                  'Keep me signed in for 30 days',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Verify & Continue',
            isLoading: auth.isLoading,
            onPressed: auth.isLoading ? null : _verifyOtp,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: auth.isLoading ? null : _goBackToEmail,
                child: const Text('Change email'),
              ),
              TextButton(
                onPressed: _cooldown > 0 || auth.isLoading
                    ? null
                    : () => _sendOtp(isSignup: _isNewUserFlow),
                child: Text(
                  _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}