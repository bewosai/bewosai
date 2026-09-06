import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/country_codes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';

/// Login / OTP screen.
///
/// Flow (no Navigator.push from this screen):
/// 1. Step 0 — email or phone → AuthProvider.sendOtp (phone only works for
///    an existing account — signing up still needs an email. A Nepal
///    (+977) phone is delivered via Sparrow SMS; any other country code
///    falls back to emailing the code to that account's address on file.)
/// 2. Step 1 — 6-digit OTP (+ name if new user) → AuthProvider.verifyOtp
/// 3. On success AuthProvider sets:
///      • AuthStatus.ready         → root shows Dashboard
///      • AuthStatus.needsBusiness → root shows SelectBusinessScreen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpFocus = FocusNode();

  /// 0 = email, 1 = OTP
  int _step = 0;
  bool _phoneMode = false;
  String _countryCode = kCountryCodes.first.code;
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

  // The free-tier backend can take 30-60s to wake from sleep on the first
  // request of a session — with no feedback that looks identical to being
  // stuck, so testers give up before the response ever arrives. Surface a
  // hint once loading runs past a few seconds instead of staying silent.
  bool _showWakingHint = false;
  Timer? _wakingHintTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _wakingHintTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _otpFocus.dispose();
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
    final identifier = _phoneMode
        ? '$_countryCode${_phoneController.text.trim()}'
        : _emailController.text.trim();

    _startWakingHint();
    final ok = await auth.sendOtp(identifier, isSignup: isSignup);
    _stopWakingHint();
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

  Future<void> _signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle(remember: _remember);
    if (!mounted) return;
    if (!ok && auth.error != null) {
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
    _startWakingHint();
    final ok = await auth.verifyOtp(
      _otpController.text.trim(),
      remember: _remember,
      name: _nameController.text.trim(),
    );
    _stopWakingHint();
    _verifying = false;
    if (!mounted) return;

    // Success: AuthProvider sets ready | needsBusiness → root rebuilds.
    // Failure: show error only.
    if (!ok && auth.error != null) {
      showAppSnackBar(context, auth.error!, isError: true);
    }
  }

  void _startWakingHint() {
    _wakingHintTimer?.cancel();
    setState(() => _showWakingHint = false);
    _wakingHintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showWakingHint = true);
    });
  }

  void _stopWakingHint() {
    _wakingHintTimer?.cancel();
    if (mounted) setState(() => _showWakingHint = false);
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
                            : 'Verify your code',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _step == 0
                            ? (_phoneMode
                                ? 'Sign in with your phone number'
                                : 'Sign in or create an account with your email')
                            : (auth.pendingOtpMessage ??
                                (_phoneMode
                                    ? 'We sent a 6-digit code to your phone.'
                                    : 'We sent a 6-digit code to ${_emailController.text.trim()}')),
                        style: TextStyle(
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

  Widget _modeTab(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.orange : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep(AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.navy50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: _modeTab('Email', Icons.mail_outline, !_phoneMode, () => setState(() => _phoneMode = false))),
                Expanded(child: _modeTab('Phone', Icons.phone_outlined, _phoneMode, () => setState(() => _phoneMode = true))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_phoneMode) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _countryCode,
                      items: kCountryCodes
                          .map((c) => DropdownMenuItem(
                                value: c.code,
                                child: Text('${c.flag} ${c.code}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _countryCode = v ?? _countryCode),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '9812345678',
                    ),
                    validator: (v) {
                      final digits = v?.trim() ?? '';
                      if (digits.length < 7 || digits.length > 15) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!auth.isLoading) _sendOtp();
                    },
                  ),
                ),
              ],
            ),
            if (_countryCode != '+977') ...[
              const SizedBox(height: 8),
              Text(
                "SMS delivery is only available for Nepal numbers — for other countries we'll email the code to this account's address on file instead.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ] else
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
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
          if (auth.isLoading && _showWakingHint) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Waking up the server — this can take up to a minute on the first try.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
          if (!_phoneMode) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: auth.isLoading ? null : () => _sendOtp(isSignup: true),
                child: const Text('New here? Create an account'),
              ),
            ),
          ],
          if (auth.googleSignInAvailable) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.textSecondary.withValues(alpha: 0.25))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppColors.textSecondary.withValues(alpha: 0.25))),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: auth.isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 26),
              label: const Text('Continue with Google'),
            ),
          ],
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
          if (auth.isLoading && _showWakingHint) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Waking up the server — this can take up to a minute on the first try.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: auth.isLoading ? null : _goBackToEmail,
                child: Text(_phoneMode ? 'Change number' : 'Change email'),
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