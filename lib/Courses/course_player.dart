import 'package:chewie/chewie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/Model/lesson_model.dart';
import 'package:online_cource_app/data/enrollment_repository.dart';
import 'package:online_cource_app/data/lesson_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';
import 'package:video_player/video_player.dart';

/// Plays a course, lesson by lesson.
///
/// Lessons come from `courses/{id}/lessons`; there are no hardcoded sample
/// videos. A course with no lessons says so instead of playing a placeholder.
class CoursePlayerPage extends StatefulWidget {
  const CoursePlayerPage({
    super.key,
    required this.course,
    this.lessonRepository,
    this.enrollmentRepository,
    this.uid,
  });

  final CourseModel course;
  final LessonRepository? lessonRepository;
  final EnrollmentRepository? enrollmentRepository;

  /// Overridable for tests; production reads the signed-in user.
  final String? uid;

  @override
  State<CoursePlayerPage> createState() => CoursePlayerPageState();
}

class CoursePlayerPageState extends State<CoursePlayerPage> {
  late final LessonRepository _lessons =
      widget.lessonRepository ?? LessonRepository();
  late final EnrollmentRepository _enrollments =
      widget.enrollmentRepository ?? EnrollmentRepository();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  List<LessonModel> _allLessons = const [];
  LessonModel? _selected;
  Enrollment? _enrollment;

  bool _loading = true;
  Object? _loadError;
  String? _videoError;

  /// Exposed for tests.
  LessonModel? get selectedLesson => _selected;
  List<LessonModel> get lessons => _allLessons;

  String get _courseId => widget.course.id ?? '';
  String get _uid =>
      widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final lessons = await _lessons.getLessons(_courseId);
      final enrollment = await _enrollments.getEnrollment(
        uid: _uid,
        courseId: _courseId,
      );
      if (!mounted) return;

      // Resume where the reader left off, else start at the first lesson.
      final resumeId = enrollment?.lastLessonId;
      final resume = lessons.where((l) => l.id == resumeId).firstOrNull;

      setState(() {
        _allLessons = lessons;
        _enrollment = enrollment;
        _selected = resume ?? (lessons.isEmpty ? null : lessons.first);
        _loading = false;
      });

      if (_selected != null) await _openLesson(_selected!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _openLesson(LessonModel lesson) async {
    setState(() {
      _selected = lesson;
      _videoError = null;
    });

    await _disposePlayer();

    if (!lesson.isPlayable) {
      if (!mounted) return;
      setState(() => _videoError = 'This lesson has no video yet.');
      return;
    }

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(lesson.videoUrl));
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.primaryColor,
            handleColor: AppTheme.primaryColor,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.lightBlueAccent,
          ),
        );
      });
    } catch (e) {
      debugPrint('Could not play lesson ${lesson.id}: $e');
      if (!mounted) return;
      setState(() => _videoError = 'This video could not be played.');
    }
  }

  /// Marks [lesson] finished and refreshes the progress shown on screen.
  Future<void> markLessonComplete(LessonModel lesson) async {
    final lessonId = lesson.id;
    if (lessonId == null || lessonId.isEmpty) return;

    await _enrollments.markLessonComplete(
      uid: _uid,
      courseId: _courseId,
      lessonId: lessonId,
      totalLessons: _allLessons.length,
    );

    final updated =
        await _enrollments.getEnrollment(uid: _uid, courseId: _courseId);
    if (!mounted) return;
    setState(() => _enrollment = updated);
  }

  bool get _isCurrentLessonDone =>
      _enrollment?.hasCompleted(_selected?.id) ?? false;

  bool get _hasNextLesson {
    final index = _allLessons.indexWhere((l) => l.id == _selected?.id);
    return index >= 0 && index + 1 < _allLessons.length;
  }

  /// Advances to the next lesson, if there is one.
  Future<void> _completeAndAdvance() async {
    final current = _selected;
    if (current == null) return;

    await markLessonComplete(current);

    final index = _allLessons.indexWhere((l) => l.id == current.id);
    if (index >= 0 && index + 1 < _allLessons.length) {
      await _openLesson(_allLessons[index + 1]);
    }
  }

  Future<void> _disposePlayer() async {
    final chewie = _chewieController;
    final video = _videoController;
    if (mounted) {
      setState(() {
        _chewieController = null;
        _videoController = null;
      });
    }
    chewie?.dispose();
    await video?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.course.title)),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Column(
        children: [
          AppSkeleton(height: 220, radius: 0),
          Expanded(child: AppListSkeleton(itemHeight: 64)),
        ],
      );
    }

    if (_loadError != null) {
      return AppErrorState(
        title: 'Could not open this course',
        message: _loadError.toString(),
        onRetry: _load,
      );
    }

    if (_allLessons.isEmpty) {
      return const AppEmptyState(
        icon: Icons.ondemand_video_outlined,
        title: 'No lessons yet',
        message: 'This course has no lessons published yet. '
            'Check back soon.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVideoArea(),
        _buildProgressBar(theme),
        Expanded(child: _buildLessonList(theme)),
      ],
    );
  }

  Widget _buildVideoArea() {
    if (_chewieController != null) {
      return SizedBox(
        height: 220,
        width: double.infinity,
        child: Chewie(controller: _chewieController!),
      );
    }

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: ColoredBox(
        color: Colors.black87,
        child: Center(
          child: _videoError == null
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined,
                        color: Colors.white70, size: 36),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(_videoError!,
                        style: const TextStyle(color: Colors.white70)),
                    if (_selected?.isPlayable ?? false)
                      TextButton.icon(
                        onPressed: () => _openLesson(_selected!),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Try again',
                            style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    final progress = _enrollment?.progress ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Course progress', style: theme.textTheme.titleSmall),
              Text('${((progress) * 100).round()}%',
                  style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          SizedBox(
            width: double.infinity,
            child: _isCurrentLessonDone
                ? OutlinedButton.icon(
                    onPressed: _hasNextLesson ? _completeAndAdvance : null,
                    icon: const Icon(Icons.check_circle_outline,
                        color: AppTheme.successColor),
                    label: Text(_hasNextLesson ? 'Next lesson' : 'Lesson complete'),
                  )
                : ElevatedButton.icon(
                    onPressed: _enrollment == null ? null : _completeAndAdvance,
                    icon: const Icon(Icons.check),
                    label: Text(_hasNextLesson
                        ? 'Mark complete & continue'
                        : 'Mark complete'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      itemCount: _allLessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
      itemBuilder: (context, index) {
        final lesson = _allLessons[index];
        final isSelected = lesson.id == _selected?.id;
        final isDone = _enrollment?.hasCompleted(lesson.id) ?? false;

        return Card(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
          child: ListTile(
            onTap: () => _openLesson(lesson),
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                isDone
                    ? Icons.check_circle
                    : (isSelected ? Icons.play_arrow : Icons.play_circle_outline),
                color: isDone
                    ? AppTheme.successColor
                    : (isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant),
                size: 20,
              ),
            ),
            title: Text(
              lesson.title,
              key: const Key('lesson_title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Lesson ${index + 1}'),
            trailing: lesson.durationSeconds > 0
                ? Text(lesson.formattedDuration,
                    style: theme.textTheme.bodySmall)
                : null,
          ),
        );
      },
    );
  }
}
