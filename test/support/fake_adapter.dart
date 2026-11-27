import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers every request with [handler] and records what was sent. No network is involved.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  int count(String path) => requests.where((RequestOptions r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Object? body, {Map<String, List<String>> headers = const <String, List<String>>{}}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      ...headers,
    },
  );
}

/// What the API sends after a login or a refresh (the raw OAuth shape, not wrapped in an envelope).
Map<String, Object?> tokenBody(String access, String refresh) => <String, Object?>{
      'access_token': access,
      'token_type': 'Bearer',
      'expires_in': 900,
      'refresh_token': refresh,
    };
