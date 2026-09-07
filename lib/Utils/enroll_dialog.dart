import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

/// Confirms and performs enrollment.
///
/// Returns `true` when the user actually enrolled, so callers can refresh.
Future<bool> showEnrollmentDialog(BuildContext context, CourseModel course) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _EnrollmentDialog(course: course),
  );
  return result ?? false;
}

class _EnrollmentDialog extends StatefulWidget {
  const _EnrollmentDialog({required this.course});

  final CourseModel course;

  @override
  State<_EnrollmentDialog> createState() => _EnrollmentDialogState();
}

class _EnrollmentDialogState extends State<_EnrollmentDialog> {
  final EnrollmentRepository _enrollments = EnrollmentRepository();

  bool _submitting = false;
  String? _error;

  Future<void> _enroll() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _error = 'Please sign in again to enroll.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Awaited: the previous version fired this write and reported success
      // unconditionally, so failures were invisible.
      await _enrollments.enroll(uid: uid, course: widget.course);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not enroll: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = widget.course;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm enrollment', style: theme.textTheme.displaySmall),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: CachedNetworkImage(
                      imageUrl: course.cover,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const AppSkeleton(height: 88, radius: 0),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text('${course.duration} · ${course.instructors.join(', ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppTheme.spaceSm),
                      Text(
                        course.price == 0
                            ? 'Free'
                            : 'BDT ${course.price.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppTheme.successColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (course.description.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                course.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.errorColor),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                ElevatedButton(
                  onPressed: _submitting ? null : _enroll,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enroll'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
