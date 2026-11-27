import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'tokens.dart';

/// Called once when the session cannot continue (the refresh token was refused).
typedef SessionExpiredCallback = void Function();

/// The only place that talks HTTP to the API.
///
/// * Adds `Authorization: Bearer <access token>` to calls that need it.
/// * Refreshes an expired access token before the call, and once after a 401. Refresh tokens are single use
///   (the server rotates them), so concurrent refreshes share one request.
/// * Turns every failure into an [ApiException].
class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    required SessionExpiredCallback onSessionExpired,
    Dio? dio,
    Dio? refreshDio,
    DateTime Function()? clock,
  })  : _tokenStore = tokenStore,
        _onSessionExpired = onSessionExpired,
        _clock = clock ?? DateTime.now,
        _dio = dio ?? Dio(_options(config)),
        _refreshDio = refreshDio ?? Dio(_options(config)) {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const String _authKey = 'tc_authenticated';
  static const String _retriedKey = 'tc_retried';

  final TokenStore _tokenStore;
  final SessionExpiredCallback _onSessionExpired;
  final DateTime Function() _clock;
  final Dio _dio;

  /// Refresh calls use their own Dio, without the interceptor, so a refresh can never trigger a refresh.
  final Dio _refreshDio;

  Future<Tokens?>? _inflightRefresh;

  static BaseOptions _options(AppConfig config) {
    return BaseOptions(
      baseUrl: config.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: <String, dynamic>{'Accept': 'application/json'},
    );
  }

  /// Sends a request and returns the decoded JSON body (`null` for 204). Paths start with `/`.
  Future<dynamic> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool authenticated = true,
  }) async {
    final normalized = path.startsWith('/') ? path : '/$path';
    try {
      final response = await _dio.request<dynamic>(
        normalized,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: headers,
          extra: <String, dynamic>{_authKey: authenticated},
        ),
      );
      final body = response.data;
      if (body is String && body.isEmpty) return null;
      return body;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool authenticated = true}) =>
      request('GET', path, query: query, authenticated: authenticated);

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, String>? headers,
    bool authenticated = true,
  }) =>
      request('POST', path, data: data, headers: headers, authenticated: authenticated);

  Future<dynamic> patch(String path, {Object? data}) => request('PATCH', path, data: data);

  Future<dynamic> put(String path, {Object? data}) => request('PUT', path, data: data);

  Future<dynamic> delete(String path) => request('DELETE', path);

  // --- interceptors -------------------------------------------------------------------------------------------

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_authKey] == false) {
      handler.next(options);
      return;
    }
    try {
      var tokens = await _tokenStore.read();
      if (tokens == null) {
        handler.reject(_failure(options, const ApiException(status: 401, code: 'unauthorized', message: 'Authentication is required.')));
        return;
      }
      if (!tokens.accessUsable(_clock())) {
        final fresh = await _refresh(tokens.refreshToken);
        if (fresh == null) {
          handler.reject(_failure(options, const ApiException(status: 401, code: 'unauthorized', message: 'Your session ended.')));
          return;
        }
        tokens = fresh;
      }
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      handler.next(options);
    } on ApiException catch (e) {
      handler.reject(_failure(options, e));
    }
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final options = error.requestOptions;
    final unauthorized = error.response?.statusCode == 401;
    if (!unauthorized || options.extra[_authKey] == false || options.extra[_retriedKey] == true) {
      handler.next(error);
      return;
    }
    try {
      final current = await _tokenStore.read();
      if (current == null) {
        handler.next(error);
        return;
      }
      final fresh = await _refresh(current.refreshToken);
      if (fresh == null) {
        handler.next(error);
        return;
      }
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${fresh.accessToken}';
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } on ApiException catch (e) {
      handler.next(_failure(options, e));
    }
  }

  // --- refresh ------------------------------------------------------------------------------------------------

  /// One refresh at a time: callers that arrive while it runs wait for the same answer.
  Future<Tokens?> _refresh(String refreshToken) {
    final running = _inflightRefresh;
    if (running != null) return running;
    final started = _doRefresh(refreshToken).whenComplete(() => _inflightRefresh = null);
    _inflightRefresh = started;
    return started;
  }

  /// Returns the new tokens, or `null` when the session is over (the refresh token was refused: the store is
  /// cleared and the callback runs). Network and server errors are thrown and keep the session, so a flaky
  /// connection never signs anybody out.
  Future<Tokens?> _doRefresh(String refreshToken) async {
    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh_token': refreshToken},
      );
      final tokens = Tokens.fromResponse(response.data, _clock());
      await _tokenStore.write(tokens);
      return tokens;
    } on DioException catch (e) {
      final api = _toApiException(e);
      final refused = api.status >= 400 && api.status < 500 && api.status != 408 && api.status != 429;
      if (refused) {
        await _tokenStore.clear();
        _onSessionExpired();
        return null;
      }
      throw api;
    }
  }

  // --- errors -------------------------------------------------------------------------------------------------

  DioException _failure(RequestOptions options, ApiException error) {
    return DioException(requestOptions: options, error: error, type: DioExceptionType.unknown);
  }

  ApiException _toApiException(DioException e) {
    final inner = e.error;
    if (inner is ApiException) return inner;
    // An if-chain, not a switch: newer Dio versions add DioExceptionType values (for example transformTimeout)
    // and an exhaustive switch would stop compiling.
    final type = e.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return const ApiException.timeout();
    }
    if (type == DioExceptionType.connectionError || type == DioExceptionType.badCertificate) {
      return const ApiException.network();
    }
    if (type == DioExceptionType.badResponse) return _fromResponse(e.response);
    if (type == DioExceptionType.cancel) {
      return const ApiException(status: 0, code: 'cancelled', message: 'The request was cancelled.');
    }
    if (inner is SocketException || inner is HandshakeException) return const ApiException.network();
    return const ApiException(status: 0, code: 'unknown', message: 'Something went wrong.');
  }

  ApiException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    var code = _codeForStatus(status);
    var message = 'Request failed ($status).';
    var details = const <FieldDetail>[];
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final c = error['code'];
        final m = error['message'];
        if (c is String && c.isNotEmpty) code = c;
        if (m is String && m.isNotEmpty) message = m;
        final d = error['details'];
        if (d is List<dynamic>) {
          details = <FieldDetail>[
            for (final item in d)
              if (item is Map<String, dynamic>)
                FieldDetail('${item['field'] ?? ''}', '${item['rule'] ?? ''}'),
          ];
        }
      }
    }
    final retry = int.tryParse(response?.headers.value('retry-after') ?? '');
    return ApiException(
      status: status,
      code: code,
      message: message,
      details: details,
      requestId: response?.headers.value('x-request-id'),
      retryAfter: retry != null && retry > 0 ? retry : null,
    );
  }

  static String _codeForStatus(int status) {
    switch (status) {
      case 400:
        return 'invalid_request';
      case 401:
        return 'unauthorized';
      case 403:
        return 'forbidden';
      case 404:
        return 'not_found';
      case 409:
        return 'conflict';
      case 413:
        return 'payload_too_large';
      case 422:
        return 'validation_failed';
      case 429:
        return 'rate_limited';
      case 503:
        return 'service_unavailable';
      default:
        return 'internal_error';
    }
  }
}
