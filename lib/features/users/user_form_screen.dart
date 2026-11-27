import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/validators.dart';
import '../../core/ui/widgets.dart';
import '../groups/group.dart';
import 'user.dart';
import 'users_controller.dart';

/// Creates a user, or edits one when [userId] is given.
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool get _editing => widget.userId != null;

  User? _loaded;
  Object? _loadError;
  bool _loading = false;
  bool _submitting = false;
  Object? _error;
  String? _groupId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await ref.read(usersRepositoryProvider).get(widget.userId!);
      if (!mounted) return;
      setState(() {
        _loaded = user;
        _name.text = user.name;
        _username.text = user.username;
        _email.text = user.email;
        _groupId = user.groupId;
        _isActive = user.isActive;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
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
    final repository = ref.read(usersRepositoryProvider);
    final isMe = _editing && ref.read(meProvider).valueOrNull?.userId == widget.userId;
    try {
      if (_editing) {
        await repository.update(
          widget.userId!,
          name: _name.text.trim(),
          email: _email.text.trim(),
          groupId: _groupId,
          // Nobody can deactivate their own account, so the status is not sent for them.
          isActive: isMe ? null : _isActive,
        );
      } else {
        await repository.create(
          name: _name.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          isActive: _isActive,
          groupId: _groupId,
        );
      }
      if (!mounted) return;
      await ref.read(usersControllerProvider.notifier).refresh(silent: true);
      if (!mounted) return;
      showMessage(context, context.s.t('form.saved'));
      context.pop();
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
    final title = _editing ? s.t('users.editTitle') : s.t('users.addTitle');

    if (_editing && _loading) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator()));
    }
    if (_editing && _loaded == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorView(error: _loadError ?? const ApiException.unexpected(), onRetry: _load),
      );
    }

    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final selectable = groups.any((Group g) => g.id == _groupId) ? _groupId : null;
    final isMe = _editing && ref.watch(meProvider).valueOrNull?.userId == widget.userId;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_error != null) ...<Widget>[
                      NoticeBanner(text: s.errorText(_error!), isError: true),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(labelText: s.t('users.name')),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      forceErrorText: s.fieldError(_error, 'name'),
                      validator: v.name,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _username,
                      readOnly: _editing,
                      decoration: InputDecoration(labelText: s.t('form.username')),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      forceErrorText: s.fieldError(_error, 'username'),
                      validator: _editing ? null : v.username,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(labelText: s.t('users.email')),
                      textInputAction: _editing ? TextInputAction.done : TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      forceErrorText: s.fieldError(_error, 'email'),
                      validator: v.email,
                    ),
                    if (!_editing) ...<Widget>[
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _password,
                        label: s.t('form.password'),
                        autofillHints: const <String>[AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        serverError: s.fieldError(_error, 'password'),
                        validator: v.password,
                      ),
                    ],
                    const SizedBox(height: 16),
                    LabeledDropdown<String?>(
                      label: s.t('form.group'),
                      value: selectable,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(value: null, child: Text(s.t('users.noGroup'))),
                        for (final group in groups)
                          DropdownMenuItem<String?>(
                            value: group.id,
                            child: Text(group.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (String? value) => setState(() => _groupId = value),
                    ),
                    if (!isMe) ...<Widget>[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.t('form.isActive')),
                        value: _isActive,
                        onChanged: (bool value) => setState(() => _isActive = value),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(s.t('form.save')),
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
