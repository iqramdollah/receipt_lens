import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/features/receipts/domain/day_label.dart';

void main() {
  final now = DateTime(2026, 11, 26, 15, 30);

  test('names today, yesterday and tomorrow whatever the time of day', () {
    expect(dayLabel(DateTime(2026, 11, 26, 0, 5), now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 26, 23, 59), now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 25, 23, 59), now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 11, 27), now), 'Tomorrow');
  });

  test('shows weekday and date for other days this year', () {
    expect(dayLabel(DateTime(2026, 11, 20), now), 'Fri, 20 Nov');
    expect(dayLabel(DateTime(2026, 1, 3), now), 'Sat, 3 Jan');
  });

  test('adds the year for other years', () {
    expect(dayLabel(DateTime(2025, 3, 18), now), 'Tue, 18 Mar 2025');
  });

  test('works across a month boundary', () {
    expect(
      dayLabel(DateTime(2026, 10, 31), DateTime(2026, 11, 1, 9)),
      'Yesterday',
    );
  });
}
