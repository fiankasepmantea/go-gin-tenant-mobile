import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/validators.dart';
import '../../core/ui/widgets.dart';
import '../update/update_gate.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _submitting = false;
  bool _signingOut = false;
  Object? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_submitting) return;
    if (_error != null) {
      // Drop the server's field messages first (forceErrorText would make validate() fail again).
      setState(() => _error = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      // The server ended every session, this one included: sign in again with the new password.
      ref.read(sessionProvider.notifier).signedOut(notice: SessionNotice.passwordChanged);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      // Whatever happened on the network, this device is signed out.
      ref.read(sessionProvider.notifier).signedOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final v = Validators(s);
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    final info = ref.watch(updateProvider).valueOrNull;
    final version = ref.watch(packageInfoProvider).valueOrNull?.version;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('account.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(s.t('login.tenantLabel')),
                subtitle: Text(session.tenant.isEmpty ? '-' : session.tenant),
              ),
            ),
            if (info != null && info.updateAvailable && !info.forceUpdate) ...<Widget>[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.system_update),
                  title: Text(s.t('update.availableTitle')),
                  subtitle: Text(s.t('update.availableBody', <String, Object>{'version': info.latestVersion})),
                  trailing: TextButton(
                    onPressed: () async {
                      final opened = await openUpdate(ref, info);
                      if (!opened && context.mounted) showMessage(context, s.t('update.openFailed'));
                    },
                    child: Text(s.t('update.action')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(s.t('lang.label'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'id', label: Text(s.t('lang.id'))),
                ButtonSegment<String>(value: 'en', label: Text(s.t('lang.en'))),
              ],
              selected: <String>{locale.languageCode},
              onSelectionChanged: (Set<String> value) => ref.read(localeProvider.notifier).set(Locale(value.first)),
            ),
            const SizedBox(height: 24),
            Text(s.t('account.changeTitle'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(s.t('account.subtitle')),
            const SizedBox(height: 16),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    NoticeBanner(text: s.errorText(_error!), isError: true),
                    const SizedBox(height: 16),
                  ],
                  PasswordField(
                    controller: _current,
                    label: s.t('account.current'),
                    serverError: s.fieldError(_error, 'current_password'),
                    validator: v.required,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _new,
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
                    onSubmitted: (_) => _changePassword(),
                    validator: (String? value) => value == _new.text ? null : s.t('reset.mismatch'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _changePassword,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(s.t('account.submit')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: Text(s.t('nav.signOut')),
            ),
            if (version != null) ...<Widget>[
              const SizedBox(height: 16),
              Center(child: Text(s.t('account.version', <String, Object>{'version': version}))),
            ],
          ],
        ),
      ),
    );
  }
}
