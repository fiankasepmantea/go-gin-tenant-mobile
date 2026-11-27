import 'package:flutter/widgets.dart';

import '../api/api_exception.dart';
import 'strings_en.dart';
import 'strings_id.dart';

/// UI texts in Indonesian and English. The Indonesian map defines the keys and the English map must have exactly
/// the same keys (test/core/app_strings_test.dart checks it). Use `{name}` in a text for values.
class AppStrings {
  AppStrings(this.locale) : _messages = locale.languageCode == 'en' ? stringsEn : stringsId;

  static const List<Locale> supportedLocales = <Locale>[Locale('id'), Locale('en')];

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  final Locale locale;
  final Map<String, String> _messages;

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    assert(strings != null, 'AppStrings.delegate is not registered in the app.');
    return strings!;
  }

  /// A text by key; a missing key shows the key itself, which is easy to spot.
  String t(String key, [Map<String, Object> vars = const <String, Object>{}]) {
    var text = _messages[key] ?? key;
    vars.forEach((String name, Object value) {
      text = text.replaceAll('{$name}', value.toString());
    });
    return text;
  }

  bool has(String key) => _messages.containsKey(key);

  /// A readable text for any failure. API errors map by their stable `code`.
  String errorText(Object error) {
    if (error is! ApiException) return t('error.generic');
    if (error.code == ApiException.networkCode) return t('error.network');
    if (error.code == ApiException.timeoutCode) return t('error.timeout');
    if (error.code == 'rate_limited') {
      return t('error.rate_limited', <String, Object>{'seconds': error.retryAfter ?? 60});
    }
    final key = 'error.${error.code}';
    return has(key) ? t(key) : t('error.generic');
  }

  /// The text of a validation rule from the API (`required`, `min`, ...); unknown rules are shown as they are.
  String ruleText(String rule) {
    final key = 'rule.$rule';
    return has(key) ? t(key) : rule;
  }

  /// The first validation problem of [field] in [error], or null when the API did not complain about it.
  String? fieldError(Object? error, String field) {
    if (error is! ApiException) return null;
    for (final detail in error.details) {
      if (detail.field == field) return ruleText(detail.rule);
    }
    return null;
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'id' || locale.languageCode == 'en';
  }

  @override
  Future<AppStrings> load(Locale locale) => Future<AppStrings>.value(AppStrings(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

extension AppStringsContext on BuildContext {
  AppStrings get s => AppStrings.of(this);
}
