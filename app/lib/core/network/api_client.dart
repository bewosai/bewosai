import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Singleton Dio client: attaches the JWT + active business ID to every
/// request, retries transient network errors, and transparently refreshes
/// an expired access token once on a 401 before giving up.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      // Render's free tier spins the backend down after ~15 min idle and can
      // take up to a minute to wake on the next request — generous timeouts
      // avoid spurious "connection timed out" errors on that first request.
      connectTimeout: const Duration(seconds: 75),
      receiveTimeout: const Duration(seconds: 75),
      sendTimeout: const Duration(seconds: 75),
      // X-Platform tells the backend's feature-flag enforcement this is the
      // Flutter app, so Super Admin's per-platform toggles apply correctly —
      // see backend bewosai/permissions.py::get_platform. React sends "web".
      headers: {'Content-Type': 'application/json', 'X-Platform': 'mobile'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.instance.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final business = await TokenStorage.instance.currentBusiness;
        final businessId = business?['id'];
        if (businessId != null) {
          options.headers['X-Business-ID'] = '$businessId';
          options.queryParameters['business'] = '$businessId';
        }
        options.extra['retryCount'] ??= 0;
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        final retryCount = (e.requestOptions.extra['retryCount'] as int?) ?? 0;
        final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isNetworkError && retryCount < _maxRetries) {
          e.requestOptions.extra['retryCount'] = retryCount + 1;
          try {
            final response = await _dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (_) {
            // fall through to next handler
          }
        }

        if (e.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await TokenStorage.instance.accessToken;
            final opts = e.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (_) {}
          } else {
            await TokenStorage.instance.clear();
          }
        }

        return handler.next(e);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  Dio get dio => _dio;

  static const int _maxRetries = 2;

  Future<bool> _refreshToken() async {
    try {
      final refresh = await TokenStorage.instance.refreshToken;
      if (refresh == null) return false;
      final res = await Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 75),
        receiveTimeout: const Duration(seconds: 75),
      )).post('/auth/refresh/', data: {'refresh': refresh});
      await TokenStorage.instance.saveAccessToken(res.data['access'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Converts any error thrown by [dio] into a human-readable [ApiException].
  static ApiException toApiException(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return ApiException('Connection timed out. Make sure the server is running and reachable.');
        case DioExceptionType.sendTimeout:
          return ApiException('Request timed out while sending data.');
        case DioExceptionType.receiveTimeout:
          return ApiException('Server took too long to respond.');
        case DioExceptionType.connectionError:
          return ApiException('Cannot reach the server. Check your network connection.');
        case DioExceptionType.badResponse:
          final data = error.response?.data;
          // Most apps return {"error": "..."}; accounts/auth endpoints
          // (send-otp, verify-otp, me, ...) return {"message": "..."} via
          // api_response() — check every shape so real backend messages
          // ("Incorrect code", "This code has expired", ...) always surface
          // instead of falling back to a generic status-code string.
          final msg = (data is Map ? (data['error'] ?? data['message'] ?? data['detail']) : null) ??
              'Server error (${error.response?.statusCode})';
          return ApiException(msg.toString());
        default:
          return ApiException(error.message ?? 'An unexpected error occurred.');
      }
    }
    return ApiException(error.toString());
  }
}
