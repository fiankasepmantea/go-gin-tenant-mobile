import '../i18n/app_strings.dart';

/// Client-side checks that save a round trip. The API stays the authority and its answers are shown as well.
class Validators {
  const Validators(this.s);

  final AppStrings s;

  static const int minPassword = 10;

  /// Tenant codes are lowercase letters, digits and hyphens, 2 to 63 characters, not starting with a hyphen.
  static final RegExp tenantPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,62}$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// What the user typed, ready to send.
  static String normalizeTenant(String raw) => raw.trim().toLowerCase();

  String? required(String? value) {
    return value == null || value.trim().isEmpty ? s.t('rule.required') : null;
  }

  String? tenant(String? value) {
    final text = normalizeTenant(value ?? '');
    if (text.isEmpty) return s.t('rule.required');
    return tenantPattern.hasMatch(text) ? null : s.t('login.tenantInvalid');
  }

  String? password(String? value) {
    if (value == null || value.isEmpty) return s.t('rule.required');
    return value.length < minPassword ? s.t('form.passwordShort') : null;
  }

  String? username(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return s.t('rule.required');
    return text.length < 3 || text.length > 64 ? s.t('form.usernameLength') : null;
  }

  String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return s.t('rule.required');
    return text.length > 254 || !_emailPattern.hasMatch(text) ? s.t('rule.email') : null;
  }

  String? name(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return s.t('rule.required');
    return text.length > 100 ? s.t('rule.max') : null;
  }
}
