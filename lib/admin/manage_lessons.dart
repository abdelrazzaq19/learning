import 'package:flutter/material.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/Model/lesson_model.dart';
import 'package:online_cource_app/data/lesson_repository.dart';
import 'package:online_cource_app/theme/app_theme.dart';
import 'package:online_cource_app/widgets/app_states.dart';

/// Admin screen for adding, editing and removing a course's lessons.
class ManageLessonsScreen extends StatefulWidget {
  const ManageLessonsScreen({
    super.key,
    required this.course,
    this.repository,
  });

  final CourseModel course;
  final LessonRepository? repository;

  @override
  State<ManageLessonsScreen> createState() => _ManageLessonsScreenState();
}

class _ManageLessonsScreenState extends State<ManageLessonsScreen> {
  late final LessonRepository _lessons = widget.repository ?? LessonRepository();

  String get _courseId => widget.course.id ?? '';

  Future<void> _addOrEdit({LessonModel? existing}) async {
    final defaultOrder =
        existing?.order ?? await _lessons.nextOrder(_courseId);
    if (!mounted) return;

    final result = await showModalBottomSheet<LessonModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LessonForm(
        existing: existing,
        defaultOrder: defaultOrder,
      ),
    );
    if (result == null) return;

    try {
      if (existing?.id == null) {
        await _lessons.addLesson(_courseId, result);
      } else {
        await _lessons.updateLesson(_courseId, existing!.id!, result);
      }
      // Keep the course's lessonCount in step with the subcollection.
      await _lessons.syncLessonCount(_courseId);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the lesson: $e')),
      );
    }
  }

  Future<void> _delete(LessonModel lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text(
          '"${lesson.title}" will be removed from this course. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || lesson.id == null) return;

    try {
      await _lessons.deleteLesson(_courseId, lesson.id!);
      await _lessons.syncLessonCount(_courseId);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the lesson: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lessons · ${widget.course.title}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add lesson'),
      ),
      body: AsyncView<List<LessonModel>>(
        stream: _lessons.streamLessons(_courseId),
        errorTitle: 'Could not load lessons',
        onRetry: () => setState(() {}),
        loading: const AppListSkeleton(itemHeight: 72),
        empty: AppEmptyState(
          icon: Icons.playlist_add,
          title: 'No lessons yet',
          message: 'Add the first lesson so students have something to watch.',
          actionLabel: 'Add lesson',
          onAction: () => _addOrEdit(),
        ),
        builder: (context, lessons) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceMd,
              AppTheme.spaceMd, 88),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (context, index) {
            final lesson = lessons[index];

            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${lesson.order}')),
                title: Text(lesson.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  lesson.isPlayable
                      ? '${lesson.formattedDuration} · ${lesson.videoUrl}'
                      : 'No video URL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _addOrEdit(existing: lesson),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.errorColor),
                      onPressed: () => _delete(lesson),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LessonForm extends StatefulWidget {
  const _LessonForm({this.existing, required this.defaultOrder});

  final LessonModel? existing;
  final int defaultOrder;

  @override
  State<_LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends State<_LessonForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _videoUrl =
      TextEditingController(text: widget.existing?.videoUrl ?? '');
  late final TextEditingController _order =
      TextEditingController(text: '${widget.defaultOrder}');
  late final TextEditingController _minutes = TextEditingController(
    text: widget.existing == null
        ? ''
        : '${(widget.existing!.durationSeconds / 60).round()}',
  );

  @override
  void dispose() {
    _title.dispose();
    _videoUrl.dispose();
    _order.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      LessonModel(
        id: widget.existing?.id,
        title: _title.text.trim(),
        videoUrl: _videoUrl.text.trim(),
        order: int.tryParse(_order.text.trim()) ?? widget.defaultOrder,
        durationSeconds: (int.tryParse(_minutes.text.trim()) ?? 0) * 60,
        resources: widget.existing?.resources ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spaceLg,
        right: AppTheme.spaceLg,
        top: AppTheme.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add lesson' : 'Edit lesson',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Lesson title'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the lesson a title'
                  : null,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextFormField(
              controller: _videoUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Video URL',
                helperText: 'A direct link to an .mp4 file',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Add the video URL';
                final uri = Uri.tryParse(text);
                if (uri == null || !uri.isAbsolute) {
                  return 'That does not look like a valid URL';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Order'),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: TextFormField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.existing == null ? 'Add' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
