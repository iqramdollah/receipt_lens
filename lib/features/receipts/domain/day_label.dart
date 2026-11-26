const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today", "Yesterday", "Fri, 20 Nov", or "Tue, 18 Mar 2025" for other years.
String dayLabel(DateTime date, DateTime now) {
  // UTC calendar dates, so daylight-saving shifts cannot skew the day count.
  final daysAgo = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;

  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo == -1) return 'Tomorrow';

  final text =
      '${_weekdays[date.weekday - 1]}, ${date.day} '
      '${_months[date.month - 1]}';
  return date.year == now.year ? text : '$text ${date.year}';
}
