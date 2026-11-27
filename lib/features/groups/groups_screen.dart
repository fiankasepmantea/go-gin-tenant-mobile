import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/widgets.dart';
import 'group.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Group group) async {
    final s = context.s;
    final repository = ref.read(groupsRepositoryProvider);
    try {
      // The API refuses to delete a group that still has users (409). Look first so the message can say how many.
      final users = await repository.countUsers(group.id);
      if (!context.mounted) return;
      if (users > 0) {
        await infoDialog(
          context,
          title: s.t('groups.deleteBlockedTitle'),
          body: s.t('groups.deleteBlockedBody', <String, Object>{'n': users, 'name': group.name}),
        );
        return;
      }
      final ok = await confirmDialog(
        context,
        title: s.t('groups.deleteTitle'),
        body: s.t('groups.deleteBody', <String, Object>{'name': group.name}),
        confirmLabel: s.t('groups.delete'),
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      await repository.delete(group.id);
      ref.invalidate(groupsProvider);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      if (error.status == 409) {
        await infoDialog(
          context,
          title: s.t('groups.deleteBlockedTitle'),
          body: s.t('groups.deleteBlockedGeneric', <String, Object>{'name': group.name}),
        );
      } else {
        showMessage(context, s.errorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final groups = ref.watch(groupsProvider);

    final Widget body = groups.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) => ErrorView(error: error, onRetry: () => ref.invalidate(groupsProvider)),
      data: (List<Group> items) {
        if (items.isEmpty) {
          return EmptyView(message: s.t('groups.empty'), icon: Icons.group_outlined);
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(groupsProvider);
            try {
              await ref.read(groupsProvider.future);
            } catch (_) {
              // The list shows the error itself.
            }
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length + 1,
            separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(s.t('groups.count', <String, Object>{'n': items.length})),
                );
              }
              final group = items[index - 1];
              return ListTile(
                onTap: () => context.push('/groups/${group.id}/permissions'),
                leading: const CircleAvatar(child: Icon(Icons.group_outlined)),
                title: Text(group.name),
                subtitle: group.description.isEmpty
                    ? null
                    : Text(group.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: PopupMenuButton<String>(
                  tooltip: s.t('groups.actions'),
                  onSelected: (String value) {
                    switch (value) {
                      case 'permissions':
                        context.push('/groups/${group.id}/permissions');
                      case 'edit':
                        context.push('/groups/edit/${group.id}');
                      case 'delete':
                        _delete(context, ref, group);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'permissions', child: Text(s.t('groups.permissions'))),
                    PopupMenuItem<String>(value: 'edit', child: Text(s.t('groups.edit'))),
                    PopupMenuItem<String>(value: 'delete', child: Text(s.t('groups.delete'))),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('groups.title'))),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/new'),
        icon: const Icon(Icons.add),
        label: Text(s.t('groups.add')),
      ),
    );
  }
}
