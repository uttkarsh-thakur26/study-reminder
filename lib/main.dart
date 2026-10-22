import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'desktop/desktop_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpDesktopWindow();
  final overrides = await bootstrap();
  runApp(ProviderScope(overrides: overrides, child: const StudyReminderApp()));
}
