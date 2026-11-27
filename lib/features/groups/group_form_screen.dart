import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/validators.dart';
import '../../core/ui/widgets.dart';
import 'group.dart';

/// Creates a group, or edits one when [groupId] is given.
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();

  bool get _editing => widget.groupId != null;

  bool _filled = false;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
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
    setState(() => _submitting = true);
    final repository = ref.read(groupsRepositoryProvider);
    try {
      if (_editing) {
        await repository.update(widget.groupId!, name: _name.text.trim(), description: _description.text.trim());
      } else {
        await repository.create(name: _name.text.trim(), description: _description.text.trim());
      }
      ref.invalidate(groupsProvider);
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
    final title = _editing ? s.t('groups.editTitle') : s.t('groups.addTitle');

    if (_editing && !_filled) {
      final groups = ref.watch(groupsProvider);
      return groups.when(
        loading: () => Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator())),
        error: (Object error, StackTrace stack) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ErrorView(error: error, onRetry: () => ref.invalidate(groupsProvider)),
        ),
        data: (List<Group> items) {
          Group? found;
          for (final group in items) {
            if (group.id == widget.groupId) found = group;
          }
          if (found == null) {
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: EmptyView(message: s.t('error.not_found'), icon: Icons.group_off_outlined),
            );
          }
          // Fill the fields once; later rebuilds keep what the user typed.
          _name.text = found.name;
          _description.text = found.description;
          _filled = true;
          return _buildForm(context, title);
        },
      );
    }
    return _buildForm(context, title);
  }

  Widget _buildForm(BuildContext context, String title) {
    final s = context.s;
    final v = Validators(s);
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
                      decoration: InputDecoration(labelText: s.t('groups.name')),
                      textInputAction: TextInputAction.next,
                      forceErrorText: s.fieldError(_error, 'name'),
                      validator: v.name,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      decoration: InputDecoration(labelText: s.t('groups.description')),
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      forceErrorText: s.fieldError(_error, 'description'),
                    ),
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
