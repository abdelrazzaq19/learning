import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/controllers/auth_controller.dart';
import 'package:online_cource_app/Login/login_page.dart';
import 'package:online_cource_app/Utils/toast_messages.dart';
import 'package:online_cource_app/About/about_screen.dart';
import 'package:online_cource_app/About/certificates_screen.dart';
import 'package:online_cource_app/About/edit_profile_screen.dart';
import 'package:online_cource_app/Exam/exam_history.dart';
import 'package:online_cource_app/Login/forgot_password_dialog.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/data/exam_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/theme/theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final user = authController.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () =>
                Get.to(() => const EditProfileScreen())?.then((_) {
              if (mounted) setState(() {});
            }),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh user data
          await authController.fetchUserData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Center(
                child: Column(
                  children: [
                    // Profile image
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: user?.photoURL != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.network(
                                user!.photoURL!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInitialsAvatar(user),
                              ),
                            )
                          : _buildInitialsAvatar(user),
                    ),
                    const SizedBox(height: 16),

                    // User name
                    Text(
                      user?.displayName ?? 'E-Learning User',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    // Email
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                    ),

                    const SizedBox(height: 24),

                    // Edit profile button
                    OutlinedButton.icon(
                      onPressed: () {
                        Get.to(() => const EditProfileScreen())?.then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Learning stats
              const Text(
                'Learning Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildStatsCards(),

              const SizedBox(height: 32),

              // Account options
              const Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildAccountOptions(context, authController),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(User? user) {
    String initials = 'U';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      final nameParts = user.displayName!.trim().split(' ');
      if (nameParts.length > 1) {
        initials = '${nameParts.first[0]}${nameParts.last[0]}';
      } else {
        initials = nameParts.first[0];
      }
      initials = initials.toUpperCase();
    } else if (user?.email != null) {
      initials = user!.email![0].toUpperCase();
    }

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  /// Real statistics from Firestore. These used to be the literals 5 / 24 / 3.
  Widget _buildStatsCards() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<Enrollment>>(
      stream: EnrollmentRepository().streamEnrollments(uid),
      builder: (context, enrollmentSnapshot) {
        final enrollments = enrollmentSnapshot.data ?? const <Enrollment>[];
        final completed = enrollments.where((e) => e.isComplete).length;

        return StreamBuilder<List<Certificate>>(
          stream: ExamRepository().streamCertificates(uid),
          builder: (context, certificateSnapshot) {
            final certificates =
                certificateSnapshot.data ?? const <Certificate>[];

            return Row(
              children: [
                _buildStatCard('Courses\nEnrolled', '${enrollments.length}',
                    Icons.school_rounded),
                const SizedBox(width: 16),
                _buildStatCard(
                    'Courses\nCompleted', '$completed', Icons.task_alt_rounded),
                const SizedBox(width: 16),
                _buildStatCard('Certificates\nEarned', '${certificates.length}',
                    Icons.workspace_premium_rounded),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountOptions(
      BuildContext context, AuthController authController) {
    final themeController = Get.find<ThemeController>();

    return Card(
      elevation: 2,
      child: Column(
        children: [
          Obx(() {
            final mode = themeController.mode.value;
            final isDark = mode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                : mode == ThemeMode.dark;
            return SwitchListTile(
              key: const Key('dark_mode_switch'),
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Dark Mode'),
              subtitle: Text(mode == ThemeMode.system
                  ? 'Following system'
                  : (isDark ? 'On' : 'Off')),
              value: isDark,
              onChanged: (value) =>
                  themeController.setMode(value ? ThemeMode.dark : ThemeMode.light),
            );
          }),
          const Divider(),
          _buildOptionItem(
            icon: Icons.verified_user_rounded,
            title: 'Account Settings',
            onTap: () => Get.to(() => const EditProfileScreen()),
          ),
          const Divider(),
          _buildOptionItem(
            icon: Icons.workspace_premium_rounded,
            title: 'My Certificates',
            onTap: () => Get.to(() => const CertificatesScreen()),
          ),
          const Divider(),
          _buildOptionItem(
            icon: Icons.history_edu_rounded,
            title: 'Exam History',
            onTap: () => Get.to(() => const ExamHistoryScreen()),
          ),
          const Divider(),
          _buildOptionItem(
            icon: Icons.lock_rounded,
            title: 'Change Password',
            onTap: () => showForgotPasswordDialog(
              context,
              initialEmail: FirebaseAuth.instance.currentUser?.email ?? '',
            ),
          ),
          const Divider(),
          _buildOptionItem(
            icon: Icons.help_rounded,
            title: 'Help & Support',
            onTap: () => Get.to(() => const AboutPage()),
          ),
          const Divider(),
          _buildOptionItem(
            icon: Icons.exit_to_app_rounded,
            title: 'Sign Out',
            textColor: AppTheme.errorColor,
            onTap: () async {
              try {
                await authController.signOutUsers();
                if (!context.mounted) return;
                showSuccessToast(context, 'Signed out successfully');
                Get.offAll(() => const LoginPage());
              } catch (e) {
                if (!context.mounted) return;
                showErrorToast(context, 'Error signing out. Please try again.');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? AppTheme.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}
