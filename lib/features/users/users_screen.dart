import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/widgets.dart';
import '../groups/group.dart';
import 'user.dart';
import 'users_controller.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 300) {
      ref.read(usersControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(usersControllerProvider).filters;
    final groups = ref.read(groupsProvider).valueOrNull ?? const <Group>[];
    final result = await showModalBottomSheet<UsersFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _FiltersSheet(initial: current, groups: groups),
    );
    if (result != null) {
      await ref.read(usersControllerProvider.notifier).setFilters(result);
    }
  }

  Future<void> _toggleActive(User user) async {
    final s = context.s;
    final activate = !user.isActive;
    if (!activate) {
      final ok = await confirmDialog(
        context,
        title: s.t('users.deactivateTitle'),
        body: s.t('users.deactivateBody', <String, Object>{'name': user.displayName, 'username': user.username}),
        confirmLabel: s.t('users.deactivate'),
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    try {
      await ref.read(usersControllerProvider.notifier).setActive(user, active: activate);
    } catch (error) {
      if (mounted) showMessage(context, context.s.errorText(error));
    }
  }

  Future<void> _delete(User user) async {
    final s = context.s;
    final ok = await confirmDialog(
      context,
      title: s.t('users.deleteTitle'),
      body: s.t('users.deleteBody', <String, Object>{'name': user.displayName, 'username': user.username}),
      confirmLabel: s.t('users.delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(usersControllerProvider.notifier).remove(user);
    } catch (error) {
      if (mounted) showMessage(context, context.s.errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final state = ref.watch(usersControllerProvider);
    final myId = ref.watch(meProvider).valueOrNull?.userId;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final groupNames = <String, String>{for (final g in groups) g.id: g.name};
    final controller = ref.read(usersControllerProvider.notifier);

    Widget body;
    if (state.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorView(error: state.error!, onRetry: controller.refresh);
    } else if (state.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => controller.refresh(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            EmptyView(message: s.t('users.empty')),
          ],
        ),
      );
    } else {
      final extra = (state.loadingMore || state.loadMoreError != null) ? 1 : 0;
      body = RefreshIndicator(
        onRefresh: () => controller.refresh(silent: true),
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.items.length + 1 + extra,
          separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(s.t('users.count', <String, Object>{'n': state.total})),
              );
            }
            final position = index - 1;
            if (position >= state.items.length) {
              if (state.loadMoreError != null) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: TextButton(onPressed: controller.loadMore, child: Text(s.t('common.retry'))),
                  ),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final user = state.items[position];
            return _UserTile(
              user: user,
              groupName: user.groupId == null ? null : groupNames[user.groupId],
              isMe: user.id == myId,
              onEdit: () => context.push('/users/edit/${user.id}'),
              onToggleActive: () => _toggleActive(user),
              onDelete: () => _delete(user),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('users.title')),
        actions: <Widget>[
          IconButton(
            tooltip: s.t('users.filters'),
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: !state.filters.isEmpty,
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/users/new'),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(s.t('users.add')),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.groupName,
    required this.isMe,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final User user;
  final String? groupName;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = Theme.of(context).colorScheme;
    final initial = user.displayName.isEmpty ? '?' : user.displayName.substring(0, 1).toUpperCase();
    final subtitle = <String>[
      user.username,
      groupName ?? s.t('users.noGroup'),
      if (!user.isActive) s.t('users.inactive'),
    ].join('  •  ');
    return ListTile(
      onTap: onEdit,
      leading: CircleAvatar(
        backgroundColor: user.isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        foregroundColor: user.isActive ? scheme.onPrimaryContainer : scheme.outline,
        child: Text(initial),
      ),
      title: Text(isMe ? '${user.displayName} (${s.t('users.you')})' : user.displayName),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        tooltip: s.t('users.actions'),
        onSelected: (String value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'toggle':
              onToggleActive();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'edit', child: Text(s.t('users.edit'))),
          // A user cannot deactivate or delete their own account (the API answers 403).
          if (!isMe)
            PopupMenuItem<String>(
              value: 'toggle',
              child: Text(user.isActive ? s.t('users.deactivate') : s.t('users.activate')),
            ),
          if (!isMe) PopupMenuItem<String>(value: 'delete', child: Text(s.t('users.delete'))),
        ],
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial, required this.groups});

  final UsersFilters initial;
  final List<Group> groups;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final TextEditingController _username;
  String? _groupId;
  bool? _isActive;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.initial.username);
    final known = widget.groups.any((Group g) => g.id == widget.initial.groupId);
    _groupId = known ? widget.initial.groupId : null;
    _isActive = widget.initial.isActive;
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: s.t('users.filterUsername')),
            ),
            const SizedBox(height: 16),
            LabeledDropdown<String?>(
              label: s.t('users.group'),
              value: _groupId,
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(value: null, child: Text(s.t('users.allGroups'))),
                for (final group in widget.groups)
                  DropdownMenuItem<String?>(value: group.id, child: Text(group.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (String? value) => setState(() => _groupId = value),
            ),
            const SizedBox(height: 16),
            LabeledDropdown<bool?>(
              label: s.t('users.status'),
              value: _isActive,
              items: <DropdownMenuItem<bool?>>[
                DropdownMenuItem<bool?>(value: null, child: Text(s.t('users.allStatus'))),
                DropdownMenuItem<bool?>(value: true, child: Text(s.t('users.active'))),
                DropdownMenuItem<bool?>(value: false, child: Text(s.t('users.inactive'))),
              ],
              onChanged: (bool? value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const UsersFilters()),
                    child: Text(s.t('users.filterClear')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      UsersFilters(username: _username.text.trim(), groupId: _groupId, isActive: _isActive),
                    ),
                    child: Text(s.t('users.filterApply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

