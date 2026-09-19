import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/business_model.dart';
import '../../data/models/fiscal_year_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart' show VerifyOtpResult;
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/usecases/business_usecases.dart';

/// App-wide auth state machine.
///
/// Splash.bootstrap() / LoginScreen email → OTP verifyOtp success both end up
/// at [_autoSelectOrPrompt]:
///   exactly 1 business                        → selectBusiness → ready → Dashboard
///   several, one matches the last-used ID     → selectBusiness → ready → Dashboard
///     (TokenStorage.lastBusinessId — survives logout, like the website's
///     localStorage `last_business_id` — so a returning user with more than
///     one business lands straight on the one they were last in, not a
///     picker, every single time they log in)
///   0, or several with no match (new device)  → needsBusiness  → SelectBusinessScreen
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

  /// Held between send-otp and verify-otp — an email or (for an existing
  /// account with a phone on file) a phone number.
  String pendingIdentifier = '';
  bool pendingUserExists = false;
  /// The backend's own message for how the code was actually delivered —
  /// e.g. "sent to j***@example.com instead" when [pendingIdentifier] was a
  /// phone number resolved to that account's email (no SMS provider yet).
  String? pendingOtpMessage;

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
      await _autoSelectOrPrompt();
    }
    notifyListeners();
  }

  /// Picks a business without asking, when there's an obvious one to pick:
  /// exactly one, or — with several — whichever this device last had
  /// selected (survives logout; see TokenStorage.lastBusinessId). Only
  /// shows the picker when neither applies, e.g. a new device or a business
  /// that's no longer accessible.
  Future<void> _autoSelectOrPrompt() async {
    if (businesses.length == 1) {
      await selectBusiness(businesses.first);
      return;
    }
    final lastId = await _storage.lastBusinessId;
    if (lastId != null) {
      final match = businesses.where((b) => b.id == lastId);
      if (match.isNotEmpty) {
        await selectBusiness(match.first);
        return;
      }
    }
    currentBusiness = null;
    status = AuthStatus.needsBusiness;
  }

  // ── OTP auth ──────────────────────────────────────────────────────────────

  Future<bool> sendOtp(String identifier, {bool isSignup = false}) => _guard(() async {
        final result = await _authUseCases.sendOtp(identifier, isSignup: isSignup);
        pendingIdentifier = identifier;
        pendingUserExists = result.userExists;
        pendingOtpMessage = result.message;
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
          pendingIdentifier,
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

    await _autoSelectOrPrompt();
  }

  // ── Business selection / CRUD ─────────────────────────────────────────────

  Future<bool> createBusiness(Business business, {String? referralCode}) => _guard(() async {
        final created = await _businessUseCases.createBusiness(business, referralCode: referralCode);
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
    await _storage.saveLastBusinessId(business.id);
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

  /// Closes the current fiscal year in place — the business (and every
  /// record in it) stays exactly as-is; the server just marks that date
  /// range read-only. Nothing about `businesses`/`currentBusiness` changes,
  /// so there's nothing to patch or re-select here.
  Future<bool> closeFiscalYear() => _guard(() async {
        if (currentBusiness == null) return false;
        await _businessUseCases.closeFiscalYear(currentBusiness!.id);
        return true;
      });

  /// Past closed fiscal years for the current business — read-only list
  /// shown in Settings alongside the Close Fiscal Year action.
  Future<List<FiscalYear>> fiscalYears() async {
    if (currentBusiness == null) return [];
    try {
      return await _businessUseCases.fiscalYears(currentBusiness!.id);
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateProfile({String? name, String? phone}) => _guard(() async {
        user = await _authUseCases.updateProfile(name: name, phone: phone);
        await _storage.saveUser(user!.toJson());
        return true;
      });

  /// The server rejected our refresh token (ApiClient already wiped the
  /// stored tokens) — drop back to the sign-in screen rather than leaving
  /// the user on a page where every request fails.
  void sessionExpired() {
    if (status == AuthStatus.loggedOut) return;
    user = null;
    businesses = [];
    currentBusiness = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

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
    pendingIdentifier = '';
    pendingUserExists = false;
    pendingOtpMessage = null;
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