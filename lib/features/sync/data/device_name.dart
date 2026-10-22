import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What other devices see this one as: the phone's model, or the laptop's
/// computer name.
Future<String> readDeviceName() async {
  if (kIsWeb) return 'Browser';
  if (Platform.isAndroid) {
    try {
      final name = await const MethodChannel('study_reminder/device')
          .invokeMethod<String>('name');
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } on Object {
      // Fall through to the generic name.
    }
    return 'Phone';
  }
  final host = Platform.localHostname.trim();
  return host.isEmpty ? 'Laptop' : host;
}
