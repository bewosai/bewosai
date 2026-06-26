import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _step = 1; // 1=email, 2=otp, 3=profile
  final _emailCtrl = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocuses = List.generate(6, (_) => FocusNode());
  bool _remember = false;
  bool _userExists = false;
  String? _devOtp;
  String? _error;
  String? _info;
  int _resendTimer = 0;
  String _selectedProfile = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocuses) f.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendTimer = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(
          () => _resendTimer = _resendTimer > 0 ? _resendTimer - 1 : 0);
      return _resendTimer > 0;
    });
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _error = 'Enter a valid email address.';
        _info = null;
      });
      return;
    }
    final auth = context.read<AuthProvider>();
    final res = await auth.sendOtp(email);
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() {
        _error = null;
        _userExists = res['user_exists'] ?? false;
        _devOtp = res['otp'];
        _info = _userExists
            ? 'Welcome back! OTP sent to $email'
            : 'OTP sent to $email';
        _step = 2;
      });
      _startResendTimer();
    } else {
      setState(() {
        _error = res['error'];
        _info = null;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpValue.length < 6) {
      setState(() {
        _error = 'Enter the complete 6-digit OTP.';
      });
      return;
    }
    final auth = context.read<AuthProvider>();
    final res = await auth.verifyOtp(
      _emailCtrl.text.trim().toLowerCase(),
      _otpValue,
      remember: _remember,
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      if (res['needs_profile'] == true) {
        setState(() {
          _step = 3;
          _error = null;
          _info = null;
        });
      } else {
        _navigate(res['account_type'], res['businesses']);
      }
    } else {
      setState(() {
        _error = res['error'];
        _info = null;
      });
      for (final c in _otpControllers) c.clear();
      _otpFocuses[0].requestFocus();
    }
  }

  Future<void> _setProfile() async {
    if (_selectedProfile.isEmpty) {
      setState(() => _error = 'Please choose your account type.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final res = await auth.setAccountType(_selectedProfile);
    if (!mounted) return;
    if (res['ok'] == true) {
      if (_selectedProfile == 'personal') {
        Navigator.pushReplacementNamed(context, '/personal-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/create-business');
      }
    } else {
      setState(() => _error = res['error']);
    }
  }

  void _navigate(String? accountType, List? businesses) {
    if (accountType == 'personal') {
      Navigator.pushReplacementNamed(context, '/personal-dashboard');
    } else if (businesses == null || businesses.isEmpty) {
      Navigator.pushReplacementNamed(context, '/create-business');
    } else if (businesses.length > 1) {
      Navigator.pushReplacementNamed(context, '/select-business');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo
                Column(
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.store_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bewosy',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart Business Suite',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Step indicators
                _buildSteps(),
                const SizedBox(height: 24),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        _buildBanner(
                            _error!, AppColors.errorLight, AppColors.error),
                      if (_info != null && _error == null)
                        _buildBanner(
                            _info!, AppColors.successLight, AppColors.success),
                      if (_devOtp != null)
                        _buildBanner('Dev OTP: $_devOtp',
                            AppColors.warningLight, AppColors.warning),
                      if (_step == 1) _buildEmailStep(auth),
                      if (_step == 2) _buildOtpStep(auth),
                      if (_step == 3) _buildProfileStep(auth),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "By continuing you agree to Bewosy's Terms of Service",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSteps() {
    final steps =
        _step == 3 ? ['Email', 'Verify', 'Profile'] : ['Email', 'Verify'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepDot(
            number: i + 1,
            label: steps[i],
            current: _step,
            total: steps.length,
          ),
          if (i < steps.length - 1)
            Container(
              width: 24,
              height: 1.5,
              color:
                  (i + 1) < _step ? AppColors.success : AppColors.navy300,
            ),
        ],
      ],
    );
  }

  Widget _buildBanner(String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(text, style: TextStyle(fontSize: 13, color: fg))),
        ]),
      );

  Widget _buildEmailStep(AuthProvider auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Bewosy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your email to sign in or create an account',
            style: TextStyle(fontSize: 13, color: AppColors.navy500),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onSubmitted: (_) => _sendOtp(),
            decoration: const InputDecoration(
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'One email = one account. No duplicates.',
            style: TextStyle(fontSize: 11, color: AppColors.navy500),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Send OTP',
            onPressed: _sendOtp,
            loading: auth.loading,
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Everything you need:',
            style: TextStyle(fontSize: 12, color: AppColors.navy500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                (Icons.receipt_long, 'Sales'),
                (Icons.inventory_2, 'Inventory'),
                (Icons.people, 'Staff'),
                (Icons.bar_chart, 'Reports'),
              ])
                Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.$1, size: 14, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text(item.$2),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _buildOtpStep(AuthProvider auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _step = 1;
              _error = null;
              _info = null;
              _devOtp = null;
            }),
            child: const Row(children: [
              Icon(Icons.arrow_back_rounded, size: 18),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Check your email',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: AppColors.navy500),
              children: [
                const TextSpan(text: '6-digit code sent to '),
                TextSpan(
                  text: _emailCtrl.text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (i) => Container(
                width: 46,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocuses[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _otpControllers[i].text.isNotEmpty
                            ? AppColors.orange
                            : AppColors.lightBorder,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.orange, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      _otpFocuses[i + 1].requestFocus();
                    }
                    if (v.isEmpty && i > 0) {
                      _otpFocuses[i - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _remember = !_remember),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lightBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _remember
                        ? AppColors.orange
                        : Colors.transparent,
                    border: Border.all(
                      color: _remember
                          ? AppColors.orange
                          : AppColors.navy400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _remember
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep me signed in for 30 days',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        'Skip OTP on this device',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.navy500),
                      ),
                    ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Verify & Continue',
            onPressed: _verifyOtp,
            loading: auth.loading,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed:
                  _resendTimer > 0 || auth.loading ? null : () async {
                final res = await context
                    .read<AuthProvider>()
                    .sendOtp(_emailCtrl.text.trim());
                if (mounted && res['ok'] == true) {
                  setState(() => _devOtp = res['otp']);
                  _startResendTimer();
                }
              },
              icon: Icon(
                _resendTimer > 0
                    ? Icons.timer_outlined
                    : Icons.refresh_rounded,
                size: 16,
              ),
              label: Text(_resendTimer > 0
                  ? 'Resend in ${_resendTimer}s'
                  : 'Resend OTP'),
            ),
          ),
        ],
      );

  Widget _buildProfileStep(AuthProvider auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select once â€” this sets up your workspace',
            style: TextStyle(fontSize: 13, color: AppColors.navy500),
          ),
          const SizedBox(height: 20),
          for (final item in [
            (
              'business',
              Icons.store_rounded,
              'Business',
              'Complete business management for shops & companies',
              ['Sales & Invoices', 'Inventory', 'Staff', 'Reports', 'Purchases'],
            ),
            (
              'personal',
              Icons.person_rounded,
              'Personal Finance',
              'Track personal income, expenses & budgets',
              ['Income', 'Expenses', 'Budget', 'Reports'],
            ),
          ])
            GestureDetector(
              onTap: () => setState(() => _selectedProfile = item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedProfile == item.$1
                      ? AppColors.orange.withOpacity(0.06)
                      : Colors.transparent,
                  border: Border.all(
                    color: _selectedProfile == item.$1
                        ? AppColors.orange
                        : AppColors.lightBorder,
                    width: _selectedProfile == item.$1 ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.$1 == 'business'
                          ? AppColors.orange.withOpacity(0.15)
                          : AppColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.$2,
                      color: item.$1 == 'business'
                          ? AppColors.orange
                          : AppColors.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            item.$3,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                          const Spacer(),
                          if (_selectedProfile == item.$1)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  size: 12, color: Colors.white),
                            ),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          item.$4,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.navy500),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final f in item.$5)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.navy50,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  f,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.navy500),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Get Started',
            onPressed: _setProfile,
            loading: auth.loading,
            icon: Icons.rocket_launch_rounded,
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'You can add more workspaces later',
              style: TextStyle(fontSize: 11, color: AppColors.navy500),
            ),
          ),
        ],
      );
}

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final int current;
  final int total;
  const _StepDot({
    required this.number,
    required this.label,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final done = number < current;
    final active = number == current;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          color: done
              ? AppColors.success
              : (active ? AppColors.orange : AppColors.navy300),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active || done
                        ? Colors.white
                        : AppColors.navy600,
                  ),
                ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? AppColors.navy800 : AppColors.navy500,
        ),
      ),
    ]);
  }
}


