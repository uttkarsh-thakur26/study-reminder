import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/update_info.dart';

/// Where releases are published. The repository is public, so its Releases
/// page needs no sign-in. To publish elsewhere (a releases-only repository,
/// say), change this one value.
const releaseRepository = 'uttkarsh-thakur26/study-reminder';

/// The newest release on GitHub.
class ReleaseFeed {
  ReleaseFeed(this._client, {this.repository = releaseRepository});

  final http.Client _client;
  final String repository;

  /// Null when there is no usable release. Throws when GitHub can't be
  /// reached, so the next check tries again.
  Future<UpdateInfo?> latest(UpdatePlatform platform) async {
    final response = await _client
        .get(
          Uri.https('api.github.com', '/repos/$repository/releases/latest'),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'StudyReminder-app',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('GitHub answered ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, Object?>) return null;
    return UpdateInfo.fromGitHub(json, platform);
  }
}
