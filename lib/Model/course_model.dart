import 'package:cloud_firestore/cloud_firestore.dart';

/// A course in the catalogue.
///
/// Parsing is deliberately defensive: a malformed Firestore document must
/// degrade to a placeholder card, never crash the list that contains it.
class CourseModel {
  final String? id;
  final String cover;
  final String duration;
  final List<String> instructors;
  final String title;
  final String description;
  final double price;
  final String category;
  final double rating;
  final int enrollmentCount;
  final int lessonCount;

  const CourseModel({
    this.id,
    required this.cover,
    required this.duration,
    required this.instructors,
    required this.title,
    this.description = 'No description available',
    this.price = 0.0,
    this.category = 'General',
    this.rating = 0.0,
    this.enrollmentCount = 0,
    this.lessonCount = 0,
  });

  /// Builds a course from a Firestore document, taking the id from the
  /// document itself. Always prefer this over [fromJson] when reading.
  factory CourseModel.fromDoc(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    return CourseModel.fromJson(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
      id: doc.id,
    );
  }

  factory CourseModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return CourseModel(
      id: id ?? _asString(json['id'], ''),
      cover: _asString(json['cover'], ''),
      duration: _asString(json['duration'], 'Self-paced'),
      instructors: _asStringList(json['instructor'] ?? json['instructors']),
      title: _asString(json['title'], 'Untitled course'),
      description: _asString(json['description'], 'No description available'),
      price: _asDouble(json['price'], 0.0),
      category: _asString(json['category'], 'General'),
      rating: _asDouble(json['rating'], 0.0),
      enrollmentCount: _asInt(json['enrollmentCount'], 0),
      lessonCount: _asInt(json['lessonCount'], 0),
    );
  }

  /// The document body. The id is the document key, so it is not duplicated
  /// inside the document.
  Map<String, dynamic> toJson() {
    return {
      'cover': cover,
      'duration': duration,
      'instructor': instructors,
      'title': title,
      // Firestore has no case-insensitive search; this is what prefix
      // queries in CourseRepository.searchCourses match against.
      'titleLower': title.toLowerCase(),
      'description': description,
      'price': price,
      'category': category,
      'rating': rating,
      'enrollmentCount': enrollmentCount,
      'lessonCount': lessonCount,
    };
  }

  CourseModel copyWith({
    String? id,
    String? cover,
    String? duration,
    List<String>? instructors,
    String? title,
    String? description,
    double? price,
    String? category,
    double? rating,
    int? enrollmentCount,
    int? lessonCount,
  }) {
    return CourseModel(
      id: id ?? this.id,
      cover: cover ?? this.cover,
      duration: duration ?? this.duration,
      instructors: instructors ?? this.instructors,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      enrollmentCount: enrollmentCount ?? this.enrollmentCount,
      lessonCount: lessonCount ?? this.lessonCount,
    );
  }

  static String _asString(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is num) return value.toString();
    return fallback;
  }

  static List<String> _asStringList(Object? value) {
    if (value is Iterable) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static double _asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _asInt(Object? value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
