import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Max retries for connection / timeout errors
  static const int _maxRetries = 2;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.keyAccessToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final bid = await _storage.read(key: AppConstants.keyBusinessId);
        if (bid != null) {
          options.headers['X-Business-ID'] = bid;
          options.queryParameters['business'] = bid;
        }
        // Track retry count in extra
        options.extra['retryCount'] ??= 0;
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Retry on connection / timeout errors
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

        // Refresh token on 401
        if (e.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: AppConstants.keyAccessToken);
            final opts = e.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (_) {}
          }
        }

        return handler.next(e);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: AppConstants.keyRefreshToken);
      if (refresh == null) return false;
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      )).post(
        '${AppConstants.baseUrl}/auth/refresh/',
        data: {'refresh': refresh},
      );
      await _storage.write(
          key: AppConstants.keyAccessToken, value: res.data['access']);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Human-readable error message from a DioException
  static String errorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timed out. Make sure the server is running and reachable.';
        case DioExceptionType.sendTimeout:
          return 'Request timed out while sending data.';
        case DioExceptionType.receiveTimeout:
          return 'Server took too long to respond.';
        case DioExceptionType.connectionError:
          return 'Cannot reach the server. Check your network connection.';
        case DioExceptionType.badResponse:
          final msg = error.response?.data?['error'] ??
              error.response?.data?['detail'] ??
              'Server error (${error.response?.statusCode})';
          return msg.toString();
        default:
          return error.message ?? 'An unexpected error occurred.';
      }
    }
    return error.toString();
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}
