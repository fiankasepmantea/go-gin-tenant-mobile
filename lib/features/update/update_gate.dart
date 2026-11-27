import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_strings.dart';
import 'update_info.dart';

/// The address to open for an update: the package of the release when it has one, otherwise the store page.
/// Null when the release gives neither.
String? updateTarget(UpdateInfo info, String Function(String) resolve) {
  if (info.downloadUrl.trim().isNotEmpty) return resolve(info.downloadUrl);
  if (info.storeUrl.trim().isNotEmpty) return info.storeUrl.trim();
  return null;
}

Future<bool> openUpdate(WidgetRef ref, UpdateInfo info) async {
  final target = updateTarget(info, ref.read(appConfigProvider).resolve);
  if (target == null) return false;
  final uri = Uri.tryParse(target);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Shows [child] (the app) unless the backend says this version is too old to run. A failed check never blocks.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateProvider).valueOrNull;
    if (info != null && info.forceUpdate) return ForceUpdateScreen(info: info);
    return child ?? const SizedBox.shrink();
  }
}

class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key, required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final canOpen = updateTarget(info, ref.read(appConfigProvider).resolve) != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(Icons.system_update, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    s.t('update.requiredTitle'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.t('update.requiredBody', <String, Object>{'version': info.latestVersion}),
                    textAlign: TextAlign.center,
                  ),
                  if (info.releaseNotes.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(info.releaseNotes.trim(), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  if (canOpen)
                    FilledButton(
                      onPressed: () async {
                        final opened = await openUpdate(ref, info);
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('update.openFailed'))));
                        }
                      },
                      child: Text(s.t('update.action')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
