import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_gin_tenant_mobile/core/api/api_exception.dart';
import 'package:go_gin_tenant_mobile/core/i18n/app_strings.dart';
import 'package:go_gin_tenant_mobile/core/i18n/strings_en.dart';
import 'package:go_gin_tenant_mobile/core/i18n/strings_id.dart';

Set<String> _placeholders(String text) => RegExp(r'\{(\w+)\}').allMatches(text).map((Match m) => m.group(1)!).toSet();

void main() {
  test('Indonesian and English have exactly the same keys', () {
    expect(stringsEn.keys.toSet(), stringsId.keys.toSet());
  });

  test('both languages use the same placeholders in every text', () {
    for (final key in stringsId.keys) {
      expect(_placeholders(stringsEn[key]!), _placeholders(stringsId[key]!), reason: key);
    }
  });

  test('no text is empty', () {
    for (final entry in <MapEntry<String, String>>[...stringsId.entries, ...stringsEn.entries]) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('every key used in lib/ exists in the dictionaries', () {
    final used = <String>{};
    final pattern = RegExp(r"\bt\('([A-Za-z0-9_.]+)'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      used.addAll(pattern.allMatches(entity.readAsStringSync()).map((Match m) => m.group(1)!));
    }
    expect(used, isNotEmpty);
    for (final key in used) {
      expect(stringsId.containsKey(key), isTrue, reason: 'missing in strings_id.dart: $key');
    }
  });

  test('every error code of the API has a text', () {
    const codes = <String>[
      'invalid_request',
      'unauthorized',
      'invalid_credentials',
      'invalid_refresh_token',
      'forbidden',
      'not_found',
      'conflict',
      'payload_too_large',
      'validation_failed',
      'rate_limited',
      'service_unavailable',
      'internal_error',
    ];
    for (final code in codes) {
      expect(stringsId.containsKey('error.$code'), isTrue, reason: code);
    }
  });

  group('AppStrings', () {
    final en = AppStrings(const Locale('en'));
    final id = AppStrings(const Locale('id'));

    test('fills placeholders', () {
      expect(en.t('users.count', <String, Object>{'n': 3}), '3 users in this tenant.');
      expect(id.t('users.count', <String, Object>{'n': 3}), '3 pengguna di tenant ini.');
    });

    test('a missing key shows the key', () {
      expect(en.t('no.such.key'), 'no.such.key');
    });

    test('errorText maps by code, not by message', () {
      const notFound = ApiException(status: 404, code: 'not_found', message: 'anything');
      expect(en.errorText(notFound), 'Not found.');
      expect(en.errorText(const ApiException.network()), stringsEn['error.network']);
      expect(en.errorText(StateError('x')), 'Something went wrong.');
      expect(
        en.errorText(const ApiException(status: 429, code: 'rate_limited', message: '', retryAfter: 7)),
        'Too many attempts. Try again in 7 seconds.',
      );
      expect(en.errorText(const ApiException(status: 418, code: 'teapot', message: '')), 'Something went wrong.');
    });

    test('fieldError finds the rule of a field', () {
      const error = ApiException(
        status: 422,
        code: 'validation_failed',
        message: '',
        details: <FieldDetail>[FieldDetail('email', 'email'), FieldDetail('name', 'weird_rule')],
      );
      expect(en.fieldError(error, 'email'), 'invalid email');
      expect(en.fieldError(error, 'name'), 'weird_rule');
      expect(en.fieldError(error, 'username'), isNull);
      expect(en.fieldError(null, 'email'), isNull);
    });
  });
}
