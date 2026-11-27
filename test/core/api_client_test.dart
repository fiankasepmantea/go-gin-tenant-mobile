import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_gin_tenant_mobile/core/api/api_client.dart';
import 'package:go_gin_tenant_mobile/core/api/api_exception.dart';
import 'package:go_gin_tenant_mobile/core/api/tokens.dart';
import 'package:go_gin_tenant_mobile/core/config/app_config.dart';

import '../support/fake_adapter.dart';
import '../support/memory_token_store.dart';

final DateTime _now = DateTime.utc(2026, 1, 1, 12);

Tokens _tokens(String access, String refresh, {bool expired = false}) => Tokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: expired ? _now.subtract(const Duration(minutes: 1)) : _now.add(const Duration(minutes: 15)),
    );

class _Setup {
  _Setup(FutureOr<ResponseBody> Function(RequestOptions) handler, Tokens? initial)
      : adapter = FakeAdapter(handler),
        store = MemoryTokenStore(initial) {
    const config = AppConfig(apiBaseUrl: 'http://test');
    final dio = Dio(BaseOptions(baseUrl: config.apiUrl))..httpClientAdapter = adapter;
    final refreshDio = Dio(BaseOptions(baseUrl: config.apiUrl))..httpClientAdapter = adapter;
    client = ApiClient(
      config: config,
      tokenStore: store,
      onSessionExpired: () => expired++,
      dio: dio,
      refreshDio: refreshDio,
      clock: () => _now,
    );
  }

  final FakeAdapter adapter;
  final MemoryTokenStore store;
  late final ApiClient client;
  int expired = 0;
}

void main() {
  group('errors', () {
    test('maps the error envelope with field details and the request id', () async {
      final setup = _Setup(
        (RequestOptions o) => jsonResponse(
          422,
          <String, Object?>{
            'success': false,
            'code': 422,
            'error': <String, Object?>{
              'code': 'validation_failed',
              'message': 'invalid',
              'details': <Object?>[
                <String, Object?>{'field': 'email', 'rule': 'email'},
              ],
            },
          },
          headers: <String, List<String>>{'x-request-id': <String>['req-1']},
        ),
        _tokens('a1', 'r1'),
      );
      await expectLater(
        setup.client.post('/users', data: <String, Object?>{}),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.status, 'status', 422)
              .having((ApiException e) => e.code, 'code', 'validation_failed')
              .having((ApiException e) => e.requestId, 'requestId', 'req-1')
              .having((ApiException e) => e.details.single.field, 'field', 'email')
              .having((ApiException e) => e.details.single.rule, 'rule', 'email'),
        ),
      );
    });

    test('reads Retry-After of a 429', () async {
      final setup = _Setup(
        (RequestOptions o) => jsonResponse(
          429,
          <String, Object?>{
            'success': false,
            'code': 429,
            'error': <String, Object?>{'code': 'rate_limited', 'message': 'slow down'},
          },
          headers: <String, List<String>>{'retry-after': <String>['12']},
        ),
        _tokens('a1', 'r1'),
      );
      await expectLater(
        setup.client.get('/users'),
        throwsA(isA<ApiException>().having((ApiException e) => e.retryAfter, 'retryAfter', 12)),
      );
    });

    test('a body without an envelope falls back to the code of the status', () async {
      final setup = _Setup((RequestOptions o) => jsonResponse(503, <String, Object?>{}), _tokens('a1', 'r1'));
      await expectLater(
        setup.client.get('/users'),
        throwsA(isA<ApiException>().having((ApiException e) => e.code, 'code', 'service_unavailable')),
      );
    });

    test('a connection failure becomes a network error', () async {
      final setup = _Setup(
        (RequestOptions o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'),
        _tokens('a1', 'r1'),
      );
      await expectLater(
        setup.client.get('/users'),
        throwsA(isA<ApiException>().having((ApiException e) => e.isNetwork, 'isNetwork', true)),
      );
    });
  });

  group('tokens', () {
    test('sends the bearer token, and none on public calls', () async {
      final setup = _Setup(
        (RequestOptions o) => jsonResponse(200, <String, Object?>{'success': true, 'code': 200, 'data': <Object?>[]}),
        _tokens('a1', 'r1'),
      );
      await setup.client.get('/users');
      await setup.client.get('/public/app-versions/check', authenticated: false);
      expect(setup.adapter.requests[0].headers['Authorization'], 'Bearer a1');
      expect(setup.adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    });

    test('a 401 refreshes once and repeats the call with the new token', () async {
      final setup = _Setup((RequestOptions o) {
        if (o.path == '/auth/refresh') return jsonResponse(200, tokenBody('a2', 'r2'));
        if (o.headers['Authorization'] == 'Bearer a2') {
          return jsonResponse(200, <String, Object?>{'success': true, 'code': 200, 'data': 'ok'});
        }
        return jsonResponse(401, <String, Object?>{
          'success': false,
          'code': 401,
          'error': <String, Object?>{'code': 'unauthorized', 'message': 'expired'},
        });
      }, _tokens('a1', 'r1'));

      final body = await setup.client.get('/users') as Map<String, dynamic>;
      expect(body['data'], 'ok');
      expect(setup.adapter.count('/auth/refresh'), 1);
      expect(setup.adapter.count('/users'), 2);
      expect((await setup.store.read())!.refreshToken, 'r2');
    });

    test('an expired access token is refreshed before the call, once for parallel calls', () async {
      final setup = _Setup((RequestOptions o) async {
        if (o.path == '/auth/refresh') {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse(200, tokenBody('a2', 'r2'));
        }
        return jsonResponse(200, <String, Object?>{'success': true, 'code': 200, 'data': o.headers['Authorization']});
      }, _tokens('a1', 'r1', expired: true));

      final answers = await Future.wait(<Future<dynamic>>[
        setup.client.get('/users'),
        setup.client.get('/groups'),
        setup.client.get('/rbac/endpoints'),
      ]);
      expect(setup.adapter.count('/auth/refresh'), 1);
      for (final answer in answers) {
        expect((answer as Map<String, dynamic>)['data'], 'Bearer a2');
      }
    });

    test('a refused refresh token ends the session', () async {
      final setup = _Setup((RequestOptions o) {
        return jsonResponse(401, <String, Object?>{
          'success': false,
          'code': 401,
          'error': <String, Object?>{'code': 'invalid_refresh_token', 'message': 'no'},
        });
      }, _tokens('a1', 'r1', expired: true));

      await expectLater(
        setup.client.get('/users'),
        throwsA(isA<ApiException>().having((ApiException e) => e.isUnauthorized, 'isUnauthorized', true)),
      );
      expect(setup.store.tokens, isNull);
      expect(setup.expired, 1);
      expect(setup.adapter.count('/users'), 0);
    });

    test('a server error during refresh keeps the session', () async {
      final setup = _Setup((RequestOptions o) => jsonResponse(500, <String, Object?>{}), _tokens('a1', 'r1', expired: true));

      await expectLater(
        setup.client.get('/users'),
        throwsA(isA<ApiException>().having((ApiException e) => e.status, 'status', 500)),
      );
      expect(setup.store.tokens, isNotNull);
      expect(setup.expired, 0);
    });

    test('a call without any stored token fails as unauthorized without touching the network', () async {
      final setup = _Setup((RequestOptions o) => jsonResponse(200, <String, Object?>{}), null);
      await expectLater(setup.client.get('/users'), throwsA(isA<ApiException>()));
      expect(setup.adapter.requests, isEmpty);
    });
  });
}
