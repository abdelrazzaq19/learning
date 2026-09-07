import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:online_cource_app/Home/home_presentation.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

/// Cover image with a loading placeholder and a themed error fallback.
///
/// Course covers are remote URLs; the old Home passed local asset paths to
/// `Image.network`, so every cover fell through to the error builder.
class CourseCover extends StatelessWidget {
  const CourseCover({
    super.key,
    required this.url,
    this.height = 120,
    this.width = double.infinity,
  });

  final String url;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (url.isEmpty) {
      return SizedBox(
        height: height,
        width: width,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.image_outlined,
              color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: width,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => AppSkeleton(height: height, radius: 0),
        errorWidget: (_, __, ___) => ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.image_not_supported_outlined,
              color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// A course tile for the Home grid.
class CourseGridCard extends StatelessWidget {
  const CourseGridCard({
    super.key,
    required this.course,
    this.onTap,
    this.trailing,
  });

  final CourseModel course;
  final VoidCallback? onTap;

  /// Optional overlay in the top-right of the cover (the bookmark button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CourseCover(url: course.cover, height: 110),
                if (trailing != null)
                  Positioned(top: 4, right: 4, child: trailing!),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceSm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formatLessonCount(course.lessonCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          formatPrice(course.price),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wide card for the "Continue Learning" row, showing real progress.
class ContinueLearningCard extends StatelessWidget {
  const ContinueLearningCard({
    super.key,
    required this.enrollment,
    this.onTap,
  });

  final Enrollment enrollment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = enrollment.course;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceSm + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CourseCover(url: course.cover, height: 72, width: 72),
              ),
              const SizedBox(width: AppTheme.spaceSm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: enrollment.progress,
                        minHeight: 5,
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
