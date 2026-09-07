import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/controllers/auth_controller.dart';
import 'package:online_cource_app/theme/app_theme.dart';

/// Lets the reader change their display name and avatar URL.
///
/// The Edit Profile button used to be an empty callback.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthController _auth = Get.find<AuthController>();

  late final User? _user = FirebaseAuth.instance.currentUser;
  late final TextEditingController _name =
      TextEditingController(text: _user?.displayName ?? '');
  late final TextEditingController _photoUrl =
      TextEditingController(text: _user?.photoURL ?? '');

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final photo = _photoUrl.text.trim();
    final ok = await _auth.updateUserProfile(
      displayName: _name.text.trim(),
      photoURL: photo.isEmpty ? null : photo,
      additionalData: {'name': _name.text.trim()},
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile updated' : 'Could not update your profile'),
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _photoUrl.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      preview.isEmpty ? null : NetworkImage(preview),
                  onBackgroundImageError:
                      preview.isEmpty ? null : (_, __) {},
                  child: preview.isEmpty
                      ? Icon(Icons.person,
                          size: 44, color: theme.colorScheme.primary)
                      : null,
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter your name';
                  if (text.length < 2) return 'That name looks too short';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: _photoUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (optional)',
                  helperText: 'A direct link to an image',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final uri = Uri.tryParse(text);
                  if (uri == null || !uri.isAbsolute) {
                    return 'That does not look like a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                initialValue: _user?.email ?? '',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Your email cannot be changed here',
                ),
              ),
              const SizedBox(height: AppTheme.spaceXl),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
