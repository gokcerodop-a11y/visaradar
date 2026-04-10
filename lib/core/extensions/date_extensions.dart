extension DateTimeExtensions on DateTime {
  /// Returns a new [DateTime] with time stripped (midnight UTC).
  DateTime get dateOnly => DateTime.utc(year, month, day);

  /// Number of full days between this and [other] (absolute value).
  int daysDifference(DateTime other) =>
      dateOnly.difference(other.dateOnly).inDays.abs();

  /// Whether this date falls within the 180-day Schengen window ending [windowEnd].
  bool isInSchengenWindow(DateTime windowEnd) {
    final windowStart = windowEnd.subtract(const Duration(days: 179));
    return !isBefore(windowStart) && !isAfter(windowEnd);
  }
}
