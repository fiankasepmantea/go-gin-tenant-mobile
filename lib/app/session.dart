import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Why the login screen is shown, so it can say so once.
enum SessionNotice { none, expired, passwordChanged, passwordReset }

class SessionState {
  const SessionState({
    this.status = SessionStatus.loading,
    this.tenant = '',
    this.notice = SessionNotice.none,
  });

  final SessionStatus status;

  /// The tenant code of the account, also the one remembered for the next login.
  final String tenant;
  final SessionNotice notice;

  bool get isSignedIn => status == SessionStatus.signedIn;

  SessionState copyWith({SessionStatus? status, String? tenant, SessionNotice? notice}) {
    return SessionState(
      status: status ?? this.status,
      tenant: tenant ?? this.tenant,
      notice: notice ?? this.notice,
    );
  }
}

/// Who is signed in. The tokens themselves live in the [TokenStore]; this only tells the UI.
class SessionController extends Notifier<SessionState> {
  static const String tenantKey = 'tenant_code';

  bool _disposed = false;

  @override
  SessionState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_boot());
    return const SessionState();
  }

  Future<void> _boot() async {
    final tenant = ref.read(sharedPreferencesProvider).getString(tenantKey) ?? '';
    final tokens = await ref.read(tokenStoreProvider).read();
    if (_disposed) return;
    state = SessionState(
      status: tokens == null ? SessionStatus.signedOut : SessionStatus.signedIn,
      tenant: tenant,
    );
  }

  /// Called after a successful login. The tokens are already stored.
  Future<void> signedIn(String tenant) async {
    await ref.read(sharedPreferencesProvider).setString(tenantKey, tenant);
    state = SessionState(status: SessionStatus.signedIn, tenant: tenant);
  }

  /// Called after the user chose to sign out (tokens are already cleared).
  void signedOut({SessionNotice notice = SessionNotice.none}) {
    state = SessionState(status: SessionStatus.signedOut, tenant: state.tenant, notice: notice);
  }

  /// The refresh token was refused: the session is over.
  void expire() {
    if (state.status != SessionStatus.signedIn) return;
    signedOut(notice: SessionNotice.expired);
  }

  /// Shown once; the login screen calls this after displaying the notice.
  void clearNotice() {
    if (state.notice == SessionNotice.none) return;
    state = state.copyWith(notice: SessionNotice.none);
  }

  /// A notice for the login screen without changing who is signed in (password reset from the e-mail link).
  void showNotice(SessionNotice notice) {
    state = state.copyWith(notice: notice);
  }
}

final NotifierProvider<SessionController, SessionState> sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
