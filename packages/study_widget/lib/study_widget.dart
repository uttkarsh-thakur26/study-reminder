import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One reminder on the widget.
@immutable
class StudyWidgetItem {
  const StudyWidgetItem({required this.title, required this.at, this.color});

  final String title;

  /// When it is due. The widget drops it once this has passed.
  final DateTime at;

  /// The subject's ARGB colour, or null for the widget's accent.
  final int? color;

  Map<String, Object?> toJson() => {
    'title': title,
    'at': at.millisecondsSinceEpoch,
    'color': color,
  };

  @override
  bool operator ==(Object other) =>
      other is StudyWidgetItem &&
      other.title == title &&
      other.at.isAtSameMomentAs(at) &&
      other.color == color;

  @override
  int get hashCode => Object.hash(title, at.millisecondsSinceEpoch, color);
}

/// What the widget shows: the next reminders, soonest first, and when the
/// phone's focus session ends, if one runs.
@immutable
class StudyWidgetData {
  const StudyWidgetData({this.items = const [], this.focusUntil});

  static const empty = StudyWidgetData();

  final List<StudyWidgetItem> items;
  final DateTime? focusUntil;

  Map<String, Object?> toJson() => {
    'items': [for (final i in items) i.toJson()],
    'focusUntil': focusUntil?.millisecondsSinceEpoch,
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is StudyWidgetData &&
      listEquals(other.items, items) &&
      other.focusUntil?.millisecondsSinceEpoch ==
          focusUntil?.millisecondsSinceEpoch;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), focusUntil?.millisecondsSinceEpoch);
}

/// What the user asked for from the widget.
enum StudyWidgetRequest {
  /// The "+" button: add a reminder.
  quickAdd,
}

/// The "Next up" home screen widget on Android. Does nothing elsewhere.
class StudyWidget {
  const StudyWidget();

  static const _channel = MethodChannel('study_widget');
  static StreamController<void>? _requests;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Shows [data] on every placed widget, and keeps it for widgets placed
  /// later. Safe to repeat.
  Future<void> update(StudyWidgetData data) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('update', {'json': data.encode()});
  }

  /// What the user tapped on the widget to open the app, or null. Given once.
  Future<StudyWidgetRequest?> takeRequest() async {
    if (!isSupported) return null;
    final name = await _channel.invokeMethod<String>('takeRequest');
    return StudyWidgetRequest.values.where((r) => r.name == name).firstOrNull;
  }

  /// Fires when a tap on the widget reaches the app while it runs. Then
  /// [takeRequest] has it.
  Stream<void> requests() {
    final requests = _requests ??= StreamController<void>.broadcast();
    if (isSupported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'request') requests.add(null);
      });
    }
    return requests.stream;
  }
}
