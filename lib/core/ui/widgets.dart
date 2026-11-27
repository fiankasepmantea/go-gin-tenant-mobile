import 'package:material_ui/material_ui.dart';

import '../i18n/app_strings.dart';

/// A password input with a show/hide button. [serverError] is a problem the API reported for this field.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.serverError,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const <String>[AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? serverError;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      forceErrorText: widget.serverError,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _visible ? s.t('form.hidePassword') : s.t('form.showPassword'),
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

/// A failed load with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(s.errorText(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(s.t('common.retry'))),
          ],
        ),
      ),
    );
  }
}

/// An empty list with a short explanation and, optionally, the action that fills it.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...<Widget>[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// A short message above a form: success (default) or problem.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError ? scheme.errorContainer : scheme.secondaryContainer;
    final foreground = isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: foreground))),
        ],
      ),
    );
  }
}

/// Asks the user to confirm. Returns true only when the confirm button was pressed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final s = context.s;
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('form.cancel')),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel ?? s.t('form.confirm')),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// A message that tells the user only that something happened or failed.
void showMessage(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// A dialog with one message and one close button.
Future<void> infoDialog(BuildContext context, {required String title, required String body}) {
  final s = context.s;
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(s.t('form.close'))),
      ],
    ),
  );
}

/// A labelled drop-down. Built from DropdownButton so it works the same on every Flutter 3.x version.
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
