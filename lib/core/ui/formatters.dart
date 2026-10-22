import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../time/calendar_date.dart';

/// Time of day in the user's 12 or 24 hour preference.
String formatTime(BuildContext context, DateTime t) =>
    TimeOfDay(hour: t.hour, minute: t.minute).format(context);

String formatMinuteOfDay(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

/// "Today", "Tomorrow", "Yesterday", or a short date like "Sat, 24 Oct".
String formatDay(CalendarDate date, CalendarDate today) {
  final diff = today.daysUntil(date);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final dt = DateTime(date.year, date.month, date.day);
  if (date.year != today.year) return DateFormat('EEE, d MMM y').format(dt);
  return DateFormat('EEE, d MMM').format(dt);
}

/// "in 5 min", "in 2 h", "5 min ago" for times close to [now].
String formatRelative(DateTime t, DateTime now) {
  final diff = t.difference(now);
  final minutes = diff.inMinutes.abs();
  final ahead = !diff.isNegative;
  String amount;
  if (minutes < 1) {
    return ahead ? 'now' : 'just now';
  } else if (minutes < 60) {
    amount = '$minutes min';
  } else if (minutes < 60 * 24) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    amount = m == 0 || h >= 3 ? '$h h' : '$h h $m min';
  } else {
    amount = '${minutes ~/ (60 * 24)} d';
  }
  return ahead ? 'in $amount' : '$amount ago';
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
