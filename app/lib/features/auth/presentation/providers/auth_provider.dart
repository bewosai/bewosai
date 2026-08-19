import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/business_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart' show VerifyOtpResult;
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/usecases/business_usecases.dart';

/// App-wide auth state machine.
///
/// Splash.bootstrap()
///   no token              → loggedOut      → LoginScreen
///   token + business      → ready          → Dashboard
///   token, no business    → needsBusiness  → SelectBusinessScreen
///     (auto-select if exactly 1 business)
///
/// LoginScreen email → OTP
///   verifyOtp success
///     1 business  → selectBusiness → ready → Dashboard
///     0 or many   → needsBusiness → SelectBusinessScreen
///
/// Root Consumer watches [status] — screens must NOT push Dashboard.
///
/// FUTURE_PHONE: extend sendOtp/verifyOtp with phone identity when backend supports it.
enum AuthStatus { unknown, loggedOut, needsBusiness, ready }

class AuthProvider extends ChangeNotifier {
  final _authUseCases = AuthUseCases();
  final _businessUseCases = BusinessUseCases();
  final _storage = TokenStorage.instance;

  /// False when GOOGLE_WEB_CLIENT_ID wasn't provided at build time — the
  /// login screen hides the Google button rather than let it fail every tap.
  bool get googleSignInAvailable => AppConstants.googleWebClientId.isNotEmpty;

  // Built lazily, only once actually needed, and only when a client ID is
  // configured. google_sign_in_web's plugin initializes itself synchronously
  // from the constructor and throws immediately if no client ID is set —
  // building this eagerly as a field initializer crashed the app on launch
  // on Flutter Web whenever GOOGLE_WEB_CLIENT_ID wasn't provided.
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn? get _googleSignIn {
    if (!googleSignInAvailable) return null;
    return _googleSignInInstance ??= GoogleSignIn(
      scopes: const ['email'],
      serverClientId: AppConstants.googleWebClientId,
    );
  }

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  List<Business> businesses = [];
  Business? currentBusiness;

  bool isLoading = false;
  String? error;

  /// Held between send-otp and verify-otp.
  String pendingEmail = '';
  bool pendingUserExists = false;
  // FUTURE_PHONE: String pendingPhone = '';
  // FUTURE_PHONE: bool pendingIsPhone = false;

  // ── Bootstrap (once from SplashScreen) ────────────────────────────────────

  Future<void> bootstrap() async {
    final loggedIn = await _storage.isLoggedIn;
    if (!loggedIn) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }

    // Cache first so UI can paint.
    final cachedUser = await _storage.user;
    if (cachedUser != null) user = AppUser.fromJson(cachedUser);

    final cachedBusinesses = await _storage.businesses;
    businesses = cachedBusinesses
        .map((e) => Business.fromJson(e as Map<String, dynamic>))
        .toList();

    final cachedCurrent = await _storage.currentBusiness;
    if (cachedCurrent != null) {
      currentBusiness = Business.fromJson(cachedCurrent);
    }

    // Refresh user (best-effort).
    try {
      user = await _authUseCases.getMe();
      await _storage.saveUser(user!.toJson());
    } catch (_) {
      // Keep cache; interceptor logs out if token is dead.
    }

    if (currentBusiness != null) {
      status = AuthStatus.ready;
    } else {
      if (businesses.isEmpty) {
        try {
          businesses = await _businessUseCases.listMyBusinesses();
          await _storage.saveBusinesses(
            businesses.map((e) => e.toRawJson()).toList(),
          );
        } catch (_) {}
      }
      // Exactly one → go straight to dashboard.
      if (businesses.length == 1) {
        await selectBusiness(businesses.first);
      } else {
        status = AuthStatus.needsBusiness;
      }
    }
    notifyListeners();
  }

  // ── OTP auth ──────────────────────────────────────────────────────────────

  Future<bool> sendOtp(String email, {bool isSignup = false}) => _guard(() async {
        final result = await _authUseCases.sendOtp(email, isSignup: isSignup);
        pendingEmail = email;
        pendingUserExists = result.userExists;
        return true;
      });

  /// On success always ends in [AuthStatus.ready] or [AuthStatus.needsBusiness].
  Future<bool> verifyOtp(
    String code, {
    bool remember = false,
    String name = '',
  }) =>
      _guard(() async {
        final result = await _authUseCases.verifyOtp(
          pendingEmail,
          code,
          remember: remember,
          name: name,
        );
        await _finishLogin(result);
        return true;
      });

  /// Native Google sign-in → exchanges the ID token with the backend for our
  /// own JWT pair via the same finalization path as OTP login. Returns false
  /// (with no [error] set) if the user cancels the Google account picker.
  Future<bool> signInWithGoogle({bool remember = true}) => _guard(() async {
        final googleSignIn = _googleSignIn;
        if (googleSignIn == null) {
          throw ApiException('Google Sign-In is not configured.');
        }
        final account = await googleSignIn.signIn();
        if (account == null) return false;

        final googleAuth = await account.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null) {
          throw ApiException("Google didn't return a sign-in token. Please try again.");
        }

        final result = await _authUseCases.googleLogin(idToken, remember: remember);
        await _finishLogin(result);
        return true;
      });

  Future<void> _finishLogin(VerifyOtpResult result) async {
    await _storage.saveTokens(access: result.access, refresh: result.refresh);
    await _storage.saveUser(result.user.toJson());
    user = result.user;
    businesses = result.businesses;
    await _storage.saveBusinesses(
      businesses.map((e) => e.toRawJson()).toList(),
    );

    if (result.isNewUser || (user?.accountType.isEmpty ?? true)) {
      try {
        await _authUseCases.setAccountType('business');
      } catch (_) {}
    }

    if (businesses.length == 1) {
      await selectBusiness(businesses.first);
    } else {
      currentBusiness = null;
      status = AuthStatus.needsBusiness;
    }
  }

  // ── Business selection / CRUD ─────────────────────────────────────────────

  Future<bool> createBusiness(Business business) => _guard(() async {
        final created = await _businessUseCases.createBusiness(business);
        businesses = [...businesses, created];
        await _storage.saveBusinesses(
          businesses.map((e) => e.toRawJson()).toList(),
        );
        await selectBusiness(created); // → ready → Dashboard
        return true;
      });

  Future<void> selectBusiness(Business business) async {
    currentBusiness = business;
    await _storage.saveCurrentBusiness(business.toRawJson());
    status = AuthStatus.ready;
    notifyListeners();
  }

  /// Set right before a voluntary switch, so the Select Business screen can
  /// offer a back button that cancels back to it. Left null (no back button)
  /// when there's nothing to cancel back to — e.g. the mandatory picker
  /// shown right after login with no business chosen yet.
  Business? _preSwitchBusiness;
  bool get canCancelSwitchBusiness => _preSwitchBusiness != null;

  Future<void> switchBusiness() async {
    _preSwitchBusiness = currentBusiness;
    await _storage.clearBusinessSelection();
    currentBusiness = null;
    status = AuthStatus.needsBusiness;
    notifyListeners();
  }

  Future<void> cancelSwitchBusiness() async {
    final previous = _preSwitchBusiness;
    if (previous == null) return;
    await selectBusiness(previous);
  }

  Future<void> refreshBusinesses() async {
    try {
      businesses = await _businessUseCases.listMyBusinesses();
      await _storage.saveBusinesses(
        businesses.map((e) => e.toRawJson()).toList(),
      );
      if (currentBusiness != null) {
        final match = businesses.where((b) => b.id == currentBusiness!.id);
        if (match.isNotEmpty) {
          currentBusiness = match.first;
          await _storage.saveCurrentBusiness(currentBusiness!.toRawJson());
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updateCurrentBusiness(Map<String, dynamic> fields, {File? logo}) =>
      _guard(() async {
        if (currentBusiness == null) return false;
        final updated =
            await _businessUseCases.updateBusiness(currentBusiness!.id, fields, logo: logo);
        currentBusiness = updated;
        await _storage.saveCurrentBusiness(updated.toRawJson());
        businesses =
            businesses.map((b) => b.id == updated.id ? updated : b).toList();
        await _storage.saveBusinesses(
          businesses.map((e) => e.toRawJson()).toList(),
        );
        return true;
      });

  Future<bool> deleteCurrentBusiness() => _guard(() async {
        if (currentBusiness == null) return false;
        final deletedId = currentBusiness!.id;
        await _businessUseCases.deleteBusiness(deletedId);
        businesses = businesses.where((b) => b.id != deletedId).toList();
        await _storage.saveBusinesses(
          businesses.map((e) => e.toRawJson()).toList(),
        );
        await _storage.clearBusinessSelection();
        currentBusiness = null;
        if (businesses.isNotEmpty) {
          await selectBusiness(businesses.first);
        } else {
          status = AuthStatus.needsBusiness;
        }
        return true;
      });

  Future<bool> closeFiscalYear() => _guard(() async {
        if (currentBusiness == null) return false;
        final archivedId = currentBusiness!.id;
        final newBusiness = await _businessUseCases.closeFiscalYear(archivedId);
        businesses = [
          for (final b in businesses)
            if (b.id == archivedId)
              Business(
                id: b.id,
                name: b.name,
                businessType: b.businessType,
                address: b.address,
                phone: b.phone,
                email: b.email,
                logo: b.logo,
                panNumber: b.panNumber,
                vatNumber: b.vatNumber,
                currency: b.currency,
                fiscalYearStart: b.fiscalYearStart,
                defaultTaxRate: b.defaultTaxRate,
                plan: b.plan,
                status: 'ARCHIVED',
                owner: b.owner,
                ownerName: b.ownerName,
                staffCount: b.staffCount,
              )
            else
              b,
          newBusiness,
        ];
        await _storage.saveBusinesses(
          businesses.map((e) => e.toRawJson()).toList(),
        );
        await selectBusiness(newBusiness);
        return true;
      });

  Future<bool> updateProfile({String? name, String? phone}) => _guard(() async {
        user = await _authUseCases.updateProfile(name: name, phone: phone);
        await _storage.saveUser(user!.toJson());
        return true;
      });

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    await _authUseCases.logout(refresh);
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}
    await _storage.clear();
    user = null;
    businesses = [];
    currentBusiness = null;
    pendingEmail = '';
    pendingUserExists = false;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  Future<bool> _guard(Future<bool> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}