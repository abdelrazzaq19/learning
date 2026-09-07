import 'package:intl/intl.dart';

/// Presentation helpers for the Home screen, kept free of widgets so the
/// formatting rules can be tested directly.

String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good Morning';
  if (now.hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

/// First word of a display name, or `Student` when there isn't one.
String firstNameOf(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return 'Student';
  return name.split(RegExp(r'\s+')).first;
}

final NumberFormat _priceFormat = NumberFormat('#,##0.##');

/// Formats a price with a single currency symbol.
String formatPrice(double price) {
  if (price <= 0) return 'Free';
  final formatted = price == price.roundToDouble()
      ? _priceFormat.format(price)
      : NumberFormat('#,##0.00').format(price);
  return '৳$formatted';
}

/// Lesson count for display. Zero means the course has no lesson list yet,
/// which must never render as "null lessons".
String formatLessonCount(int lessonCount) {
  if (lessonCount <= 0) return 'Self-paced';
  return lessonCount == 1 ? '1 lesson' : '$lessonCount lessons';
}
