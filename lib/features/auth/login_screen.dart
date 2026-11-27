import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/validators.dart';
import '../../core/ui/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _tenant;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  SessionNotice _notice = SessionNotice.none;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _tenant = TextEditingController(text: session.tenant);
    _notice = session.notice;
    if (_notice != SessionNotice.none) {
      // Say it once: the next visit of this screen starts clean.
      Future<void>.microtask(() {
        if (mounted) ref.read(sessionProvider.notifier).clearNotice();
      });
    }
  }

  @override
  void dispose() {
    _tenant.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    final tenant = Validators.normalizeTenant(_tenant.text);
    setState(() {
      _submitting = true;
      _error = null;
      _notice = SessionNotice.none;
    });
    try {
      await ref.read(authRepositoryProvider).login(
            tenantCode: tenant,
            username: _username.text.trim(),
            password: _password.text,
          );
      await ref.read(sessionProvider.notifier).signedIn(tenant);
      // The router sends a signed-in user to the app; nothing else to do here.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _noticeText(AppStrings s) {
    switch (_notice) {
      case SessionNotice.expired:
        return s.t('error.unauthorized');
      case SessionNotice.passwordChanged:
        return s.t('login.noticeChanged');
      case SessionNotice.passwordReset:
        return s.t('login.noticeReset');
      case SessionNotice.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final v = Validators(s);
    final noticeText = _noticeText(s);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(s.t('login.title'), style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(s.t('login.subtitle')),
                      const SizedBox(height: 24),
                      if (noticeText != null) ...<Widget>[
                        NoticeBanner(text: noticeText),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null) ...<Widget>[
                        NoticeBanner(text: s.errorText(_error!), isError: true),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _tenant,
                        decoration: InputDecoration(labelText: s.t('login.tenant')),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.url,
                        validator: v.tenant,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _username,
                        decoration: InputDecoration(labelText: s.t('login.username')),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const <String>[AutofillHints.username],
                        validator: v.required,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _password,
                        label: s.t('login.password'),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: v.required,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(s.t('login.submit')),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _submitting ? null : () => context.push('/forgot-password'),
                        child: Text(s.t('login.forgot')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
