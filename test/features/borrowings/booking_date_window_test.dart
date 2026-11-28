import 'package:flutter_test/flutter_test.dart';
import 'package:lapak8new/features/borrowings/utils/booking_date_window.dart';

void main() {
  final today = DateTime(2026, 11, 28, 14);

  test('item booking allows today and tomorrow only', () {
    expect(
      isBookingDateWithinWindow(
        date: DateTime(2026, 11, 28),
        today: today,
        maxDaysAhead: 1,
      ),
      isTrue,
    );
    expect(
      isBookingDateWithinWindow(
        date: DateTime(2026, 11, 29),
        today: today,
        maxDaysAhead: 1,
      ),
      isTrue,
    );
    expect(
      isBookingDateWithinWindow(
        date: DateTime(2026, 11, 30),
        today: today,
        maxDaysAhead: 1,
      ),
      isFalse,
    );
  });

  test('room booking allows dates through seven days ahead', () {
    expect(
      isBookingDateWithinWindow(
        date: DateTime(2026, 12, 5),
        today: today,
        maxDaysAhead: 7,
      ),
      isTrue,
    );
    expect(
      isBookingDateWithinWindow(
        date: DateTime(2026, 12, 6),
        today: today,
        maxDaysAhead: 7,
      ),
      isFalse,
    );
  });

  test('booking window excludes dates before today', () {
    expect(
      isBookingDateWithinWindow(
        date: DateTime(2026, 11, 27),
        today: today,
        maxDaysAhead: 7,
      ),
      isFalse,
    );
  });
}
