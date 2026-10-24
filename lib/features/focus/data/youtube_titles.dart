import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/study_videos.dart';

/// Looks up what YouTube calls a video or playlist, through its public
/// oEmbed page, which needs no account or key. Null when it can't tell,
/// such as offline or for a private video.
Future<String?> lookUpYouTubeTitle(
  StudyVideo video, {
  http.Client? client,
}) async {
  final page = video.isPlaylist
      ? 'https://www.youtube.com/playlist?list=${video.id}'
      : 'https://www.youtube.com/watch?v=${video.id}';
  final uri = Uri.https('www.youtube.com', '/oembed', {
    'url': page,
    'format': 'json',
  });
  final c = client ?? http.Client();
  try {
    final response = await c.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final title = body is Map ? body['title'] : null;
    return title is String && title.trim().isNotEmpty ? title.trim() : null;
  } on Object catch (e) {
    debugPrint('focus: could not look up the video title: $e');
    return null;
  } finally {
    if (client == null) c.close();
  }
}
