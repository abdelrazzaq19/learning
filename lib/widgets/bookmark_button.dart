import 'package:flutter/material.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/bookmark_repository.dart';

/// Save/unsave toggle for a course.
///
/// Updates optimistically so the icon responds immediately, and rolls back if
/// the write fails.
class BookmarkButton extends StatefulWidget {
  const BookmarkButton({
    super.key,
    required this.course,
    required this.uid,
    this.repository,
    this.color,
  });

  final CourseModel course;
  final String uid;
  final BookmarkRepository? repository;
  final Color? color;

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> {
  late final BookmarkRepository _repository =
      widget.repository ?? BookmarkRepository();

  bool _bookmarked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final courseId = widget.course.id;
    if (courseId == null || courseId.isEmpty || widget.uid.isEmpty) return;

    final bookmarked =
        await _repository.isBookmarked(uid: widget.uid, courseId: courseId);
    if (!mounted) return;
    setState(() => _bookmarked = bookmarked);
  }

  Future<void> _toggle() async {
    final courseId = widget.course.id;
    if (_busy || courseId == null || courseId.isEmpty || widget.uid.isEmpty) {
      return;
    }

    final previous = _bookmarked;
    setState(() {
      _busy = true;
      _bookmarked = !previous;
    });

    try {
      final result =
          await _repository.toggle(uid: widget.uid, course: widget.course);
      if (!mounted) return;
      setState(() => _bookmarked = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookmarked = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your bookmarks.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _bookmarked ? 'Remove bookmark' : 'Save for later',
      onPressed: widget.uid.isEmpty ? null : _toggle,
      icon: Icon(
        _bookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: widget.color ??
            (_bookmarked ? Theme.of(context).colorScheme.primary : null),
      ),
    );
  }
}
