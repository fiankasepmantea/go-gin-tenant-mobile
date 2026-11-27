import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/widgets.dart';
import 'group.dart';
import 'permissions.dart';

/// Which endpoints the users of a group may call. Same rules as the web console, including the lockout guard.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  List<EndpointInfo> _endpoints = const <EndpointInfo>[];
  Set<String> _selected = <String>{};
  bool _ownGroup = false;
  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  String? _lockoutMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// True when this is the group of the signed-in user. When that cannot be found out, assume it is: the guard
  /// only costs a warning, while a wrong "no" could lock the admin out.
  Future<bool> _isOwnGroup() async {
    try {
      final me = await ref.read(meProvider.future);
      final user = await ref.read(usersRepositoryProvider).get(me.userId);
      return user.groupId == widget.groupId;
    } catch (_) {
      return true;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final repository = ref.read(groupsRepositoryProvider);
    try {
      final endpoints = await repository.endpoints();
      final selected = await repository.permissions(widget.groupId);
      final own = await _isOwnGroup();
      if (!mounted) return;
      setState(() {
        _endpoints = endpoints;
        _selected = selected;
        _ownGroup = own;
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

  void _toggle(String id, bool value) {
    setState(() {
      _lockoutMessage = null;
      if (value) {
        _selected = <String>{..._selected, id};
      } else {
        _selected = <String>{..._selected}..remove(id);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final s = context.s;
    if (_ownGroup) {
      final missing = lockoutRisk(_endpoints, _selected);
      if (missing.isNotEmpty) {
        setState(() => _lockoutMessage = s.t('groups.permLockout', <String, Object>{'list': missing.join(', ')}));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(groupsRepositoryProvider).savePermissions(widget.groupId, _selected);
      if (!mounted) return;
      showMessage(context, s.t('form.saved'));
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, s.errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    var name = '';
    for (final group in groups) {
      if (group.id == widget.groupId) name = group.name;
    }
    final title = name.isEmpty ? s.t('groups.permissions') : s.t('groups.permTitle', <String, Object>{'name': name});

    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: ErrorView(error: _loadError!, onRetry: _load));
    }
    if (_endpoints.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: EmptyView(message: s.t('groups.permEmpty')));
    }

    final sections = groupByResource(_endpoints);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(s.t('groups.permHelp')),
          ),
          if (_ownGroup)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: NoticeBanner(text: s.t('groups.permOwnGroup')),
            ),
          if (_lockoutMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: NoticeBanner(text: _lockoutMessage!, isError: true),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    s.t('groups.permSelected', <String, Object>{'n': _selected.length, 'total': _endpoints.length}),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _lockoutMessage = null;
                    _selected = <String>{for (final e in _endpoints) e.id};
                  }),
                  child: Text(s.t('groups.permAll')),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _lockoutMessage = null;
                    _selected = <String>{};
                  }),
                  child: Text(s.t('groups.permNone')),
                ),
              ],
            ),
          ),
          for (final section in sections)
            ExpansionTile(
              key: PageStorageKey<String>('perm-${section.key}'),
              title: Text(section.key),
              subtitle: Text(
                '${section.value.where((EndpointInfo e) => _selected.contains(e.id)).length} / ${section.value.length}',
              ),
              children: <Widget>[
                for (final endpoint in section.value)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selected.contains(endpoint.id),
                    onChanged: (bool? value) => _toggle(endpoint.id, value ?? false),
                    title: Text(endpoint.method, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(endpoint.path),
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.t('form.save')),
          ),
        ),
      ),
    );
  }
}
