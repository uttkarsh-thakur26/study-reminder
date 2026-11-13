import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../settings/ui/about_card.dart';
import '../data/release_feed.dart';
import '../data/update_installer.dart';
import '../domain/app_version.dart';
import '../domain/update_info.dart';
import 'update_service.dart';

/// The release file this platform installs; null where the app can't
/// update itself.
UpdatePlatform? get currentUpdatePlatform {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => UpdatePlatform.android,
    TargetPlatform.windows => UpdatePlatform.windows,
    _ => null,
  };
}

/// Builds the service for [db]. Also used by the Android background task.
UpdateService updateServiceFor(
  AppDatabase db,
  http.Client client, {
  String version = appVersion,
}) {
  final platform = currentUpdatePlatform;
  final feed = ReleaseFeed(client);
  return UpdateService(
    current: platform == null ? null : AppVersion.tryParse(version),
    platform: platform ?? UpdatePlatform.android,
    fetch: feed.latest,
    read: db.readSetting,
    write: db.writeSetting,
  );
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return updateServiceFor(ref.watch(databaseProvider), client);
});

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller(),
);
