import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/validators.dart';
import '../../core/ui/widgets.dart';

/// Asks the backend to e-mail a reset link. The answer is the same whether or not the account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _tenant;
  final TextEditingController _identifier = TextEditingController();

  bool _submitting = false;
  bool _sent = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tenant = TextEditingController(text: ref.read(sessionProvider).tenant);
  }

  @override
  void dispose() {
    _tenant.dispose();
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
      _sent = false;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(
            tenantCode: Validators.normalizeTenant(_tenant.text),
            identifier: _identifier.text.trim(),
          );
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final v = Validators(s);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('forgot.title'))),
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
                    Text(s.t('forgot.help')),
                    const SizedBox(height: 16),
                    if (_sent) ...<Widget>[
                      NoticeBanner(text: s.t('forgot.sent')),
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
                      controller: _identifier,
                      decoration: InputDecoration(labelText: s.t('forgot.identifier')),
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      onFieldSubmitted: (_) => _submit(),
                      validator: v.required,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(s.t('forgot.submit')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/reset-password'),
                      child: Text(s.t('forgot.haveToken')),
                    ),
                    TextButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                      child: Text(s.t('forgot.back')),
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
