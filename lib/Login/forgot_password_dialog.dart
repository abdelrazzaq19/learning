import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/controllers/auth_controller.dart';
import 'package:online_cource_app/theme/app_theme.dart';

/// Sends a password reset email.
///
/// The controller already had `resetPassword`; the button that should have
/// called it was an empty callback.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);

  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    final ok = await Get.find<AuthController>().resetPassword(
      _email.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
      _error = ok ? null : 'We could not send the email. Check the address.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_sent) {
      return AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined,
            color: AppTheme.successColor, size: 40),
        title: const Text('Check your inbox'),
        content: Text(
          'We sent a password reset link to ${_email.text.trim()}.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Reset your password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email and we will send you a reset link.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Enter your email';
                if (!GetUtils.isEmail(text)) return 'Enter a valid email';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.errorColor)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}
