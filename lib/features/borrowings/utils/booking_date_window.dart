bool isBookingDateWithinWindow({
  required DateTime date,
  required DateTime today,
  required int maxDaysAhead,
}) {
  final firstAllowedDate = DateTime(today.year, today.month, today.day);
  final selectedDate = DateTime(date.year, date.month, date.day);
  final lastAllowedDate = firstAllowedDate.add(Duration(days: maxDaysAhead));
  return !selectedDate.isBefore(firstAllowedDate) &&
      !selectedDate.isAfter(lastAllowedDate);
}
