import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/Courses/all_courses.dart';
import 'package:online_cource_app/Courses/course_player.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

class EnrolledCoursesScreen extends StatefulWidget {
  const EnrolledCoursesScreen({super.key});

  @override
  State<EnrolledCoursesScreen> createState() => _EnrolledCoursesScreenState();
}

class _EnrolledCoursesScreenState extends State<EnrolledCoursesScreen> {
  final EnrollmentRepository _enrollments = EnrollmentRepository();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Learning')),
      body: AsyncView<List<Enrollment>>(
        stream: _enrollments.streamEnrollments(_uid),
        errorTitle: 'Could not load your courses',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 110),
        empty: AppEmptyState(
          icon: Icons.school_outlined,
          title: 'No courses yet',
          message: 'Enroll in a course and it will show up here with your '
              'progress.',
          actionLabel: 'Browse courses',
          onAction: () => Get.to(() => const CourseListPage()),
        ),
        builder: (context, enrollments) => ListView.separated(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          itemCount: enrollments.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
          itemBuilder: (context, index) =>
              EnrolledCourseItem(enrollment: enrollments[index]),
        ),
      ),
    );
  }
}

class EnrolledCourseItem extends StatelessWidget {
  const EnrolledCourseItem({super.key, required this.enrollment});

  final Enrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = enrollment.course;

    return Card(
      child: InkWell(
        onTap: () => Get.to(() => CoursePlayerPage(course: course)),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: CachedNetworkImage(
                    imageUrl: course.cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const AppSkeleton(height: 84, radius: 0),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (enrollment.isComplete)
                          const Icon(Icons.verified_rounded,
                              size: 20, color: AppTheme.successColor),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      course.instructors.isEmpty
                          ? course.duration
                          : course.instructors.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: enrollment.progress,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      enrollment.isComplete
                          ? 'Completed'
                          : '${enrollment.percent}% complete',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enrollment.isComplete
                            ? AppTheme.successColor
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
