import 'package:cloud_firestore/cloud_firestore.dart';

/// One playable lesson inside a course (`courses/{id}/lessons/{lessonId}`).
class LessonModel {
  final String? id;
  final String title;
  final String videoUrl;
  final int order;
  final int durationSeconds;
  final List<String> resources;

  const LessonModel({
    this.id,
    required this.title,
    required this.videoUrl,
    this.order = 0,
    this.durationSeconds = 0,
    this.resources = const [],
  });

  factory LessonModel.fromDoc(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    return LessonModel.fromJson(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
      id: doc.id,
    );
  }

  factory LessonModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return LessonModel(
      id: id,
      title: _asString(json['title'], 'Untitled lesson'),
      videoUrl: _asString(json['videoUrl'], ''),
      order: _asInt(json['order'], 0),
      durationSeconds: _asInt(json['durationSeconds'], 0),
      resources: json['resources'] is Iterable
          ? (json['resources'] as Iterable).map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'videoUrl': videoUrl,
        'order': order,
        'durationSeconds': durationSeconds,
        'resources': resources,
      };

  bool get isPlayable => videoUrl.isNotEmpty;

  /// Human-readable runtime, e.g. `12:05`.
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _asString(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static int _asInt(Object? value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
