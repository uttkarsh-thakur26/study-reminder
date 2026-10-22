import 'package:flutter/material.dart';

/// The version CI and release builds pass in with
/// `--dart-define=APP_VERSION=1.2.0`. Empty in a local build.
const appVersion = String.fromEnvironment('APP_VERSION');

/// Settings: the app's name and the version of this build.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key, this.version = appVersion});

  final String version;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.school_rounded),
      title: const Text('Study Reminder'),
      subtitle: Text('Version ${version.isEmpty ? 'dev' : version}'),
    ),
  );
}
