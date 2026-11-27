import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/validators.dart';
import '../../core/ui/widgets.dart';

/// Sets a new password with the token from the e-mail. [initialToken] comes from a link (`?token=`) when there is one.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _token;
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_error != null) {
      // Drop the server's field messages first (forceErrorText would make validate() fail again).
      setState(() => _error = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: _token.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ref.read(sessionProvider.notifier).showNotice(SessionNotice.passwordReset);
      context.go('/login');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(AppStrings s, Object error) {
    // A token that is wrong, used or expired is a bad request or "not found"; say what to do.
    if (error is ApiException && error.details.isEmpty && (error.status == 400 || error.status == 404)) {
      return s.t('reset.invalid');
    }
    return s.errorText(error);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final v = Validators(s);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('reset.title'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(s.t('reset.help')),
                    const SizedBox(height: 16),
                    if (_error != null) ...<Widget>[
                      NoticeBanner(text: _errorMessage(s, _error!), isError: true),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _token,
                      decoration: InputDecoration(labelText: s.t('reset.token')),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: v.required,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _password,
                      label: s.t('form.password'),
                      autofillHints: const <String>[AutofillHints.newPassword],
                      serverError: s.fieldError(_error, 'new_password'),
                      validator: v.password,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _confirm,
                      label: s.t('reset.confirm'),
                      autofillHints: const <String>[AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (String? value) => value == _password.text ? null : s.t('reset.mismatch'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(s.t('reset.submit')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
