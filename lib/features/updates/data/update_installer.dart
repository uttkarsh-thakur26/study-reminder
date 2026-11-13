import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/update_info.dart';

/// What happened when the update was handed to the system.
enum InstallStart {
  /// Android's installer or Windows Setup is running.
  started,

  /// Android needs "Install unknown apps" for this app first. Its settings
  /// page is open; try again when the user comes back.
  needsPermission,

  /// This copy can't update itself (the Windows zip). Open [UpdateInfo.pageUrl].
  unsupported,
}

/// Downloads an update and starts installing it.
class UpdateInstaller {
  UpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _channel = MethodChannel('study_reminder/updates');

  /// Where the installed Windows app lives: `{localappdata}\Programs\Study
  /// Reminder`, from windows/installer/study_reminder.iss.
  static bool get isInstalledWindowsCopy {
    if (!Platform.isWindows) return false;
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null) return false;
    final dir = p.dirname(Platform.resolvedExecutable).toLowerCase();
    return p.equals(
      dir,
      p.join(local, 'Programs', 'Study Reminder').toLowerCase(),
    );
  }

  /// Whether this copy can install [update] itself.
  static bool canInstall(UpdateInfo update) =>
      update.downloadUrl != null &&
      (Platform.isAndroid || isInstalledWindowsCopy);

  /// Downloads the file of [update], reporting progress from 0 to 1 (null
  /// while the size is unknown). Returns the downloaded file.
  Future<File> download(
    UpdateInfo update, {
    void Function(double? progress)? onProgress,
  }) async {
    final url = update.downloadUrl;
    if (url == null) throw StateError('No file for this device');
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'updates'),
    );
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, p.basename(Uri.parse(url).path)));
    final part = File('${file.path}.part');

    final response = await _client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw HttpException('Download failed (${response.statusCode})');
    }
    final total = response.contentLength ?? update.size;
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(total > 0 ? received / total : null);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      throw const HttpException('Download was cut off');
    }
    return part.rename(file.path);
  }

  /// Hands [file] to the system installer. On Windows the app quits right
  /// after, through [quitApp], so Setup can replace it, and Setup's helper
  /// starts it again when done.
  Future<InstallStart> install(
    File file, {
    required Future<void> Function() quitApp,
  }) async {
    if (Platform.isAndroid) {
      final answer = await _channel.invokeMethod<String>('install', {
        'path': file.path,
      });
      return answer == 'started'
          ? InstallStart.started
          : InstallStart.needsPermission;
    }
    if (!isInstalledWindowsCopy) return InstallStart.unsupported;
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-EncodedCommand',
      encodePowerShell(
        windowsUpdateScript(
          appPid: pid,
          setup: file.path,
          app: Platform.resolvedExecutable,
        ),
      ),
    ], mode: ProcessStartMode.detached);
    await quitApp();
    return InstallStart.started;
  }
}

/// Waits for the app to quit (Setup refuses to run while it holds its
/// lock), runs Setup without questions, then starts the app again, also
/// when Setup failed, so the old version keeps running.
String windowsUpdateScript({
  required int appPid,
  required String setup,
  required String app,
}) {
  String quote(String s) => "'${s.replaceAll("'", "''")}'";
  return [
    'Wait-Process -Id $appPid -Timeout 60 -ErrorAction SilentlyContinue',
    'Start-Process -FilePath ${quote(setup)} '
        "-ArgumentList '/SILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOCANCEL' "
        '-Wait',
    'Start-Process -FilePath ${quote(app)}',
  ].join('; ');
}

/// PowerShell's -EncodedCommand: base64 of the UTF-16LE text, which keeps
/// paths with spaces and quotes intact.
String encodePowerShell(String script) {
  final bytes = <int>[];
  for (final unit in script.codeUnits) {
    bytes
      ..add(unit & 0xff)
      ..add(unit >> 8);
  }
  return base64Encode(bytes);
}
