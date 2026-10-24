import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/theme/app_theme.dart';
import '../application/focus_providers.dart';
import '../domain/focus_prefs.dart';
import '../domain/study_videos.dart';

/// Opens the player on the phone, at [video] or the first study video.
Future<void> openStudyPlayer(BuildContext context, {StudyVideo? video}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyPlayerScreen(initial: video),
      ),
    );

/// The phone's own player for the user's study videos, so they can watch
/// them while the YouTube app is blocked. It plays nothing else: a video
/// picked from the player's suggestions sends it back to the study video or
/// playlist. Where the user got to in a playlist is kept for next time.
class StudyPlayerScreen extends ConsumerStatefulWidget {
  const StudyPlayerScreen({super.key, this.initial});

  /// How many players are open now.
  static int openCount = 0;

  final StudyVideo? initial;

  @override
  ConsumerState<StudyPlayerScreen> createState() => _StudyPlayerScreenState();
}

class _StudyPlayerScreenState extends ConsumerState<StudyPlayerScreen> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _values;
  StudyVideo? _current;

  /// The videos of the current playlist, once the player has said.
  List<String> _playlist = const [];
  int _index = 0;
  String _lastVideo = '';

  /// The video a playlist's link opened at, to go to once the playlist has
  /// loaded.
  String? _startAt;

  @override
  void initState() {
    super.initState();
    StudyPlayerScreen.openCount++;
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        // Suggestions at the end only from the same channel.
        strictRelatedVideos: true,
      ),
    );
    _values = _controller.listen(_onValue);
    unawaited(_start());
  }

  @override
  void dispose() {
    StudyPlayerScreen.openCount--;
    unawaited(_values?.cancel());
    unawaited(_controller.close());
    super.dispose();
  }

  Future<void> _start() async {
    final videos =
        (await ref.read(focusRepositoryProvider).prefs()).studyVideos;
    final first =
        videos.where((v) => widget.initial?.sameAs(v) ?? false).firstOrNull ??
        videos.firstOrNull;
    if (first != null && mounted) await _play(first);
  }

  Future<void> _play(StudyVideo video) async {
    setState(() {
      _current = video;
      _playlist = const [];
      _index = 0;
      _lastVideo = '';
      _startAt = null;
    });
    if (!video.isPlaylist) {
      await _controller.loadVideoById(videoId: video.id);
      return;
    }
    final saved = await ref
        .read(focusRepositoryProvider)
        .studyPlaylistIndex(video.id);
    if (saved == null) _startAt = video.startId;
    await _controller.loadPlaylist(
      list: [video.id],
      listType: ListType.playlist,
      index: saved ?? 0,
    );
  }

  void _onValue(YoutubePlayerValue value) {
    final id = value.metaData.videoId;
    if (id.isEmpty || id == _lastVideo) return;
    _lastVideo = id;
    unawaited(_check(id));
  }

  /// Sends the player back when [id] is not the study video or one of the
  /// study playlist's, and keeps the place in a playlist.
  Future<void> _check(String id) async {
    final current = _current;
    if (current == null) return;
    if (!current.isPlaylist) {
      if (id != current.id) {
        await _controller.loadVideoById(videoId: current.id);
      }
      return;
    }
    List<String> fresh;
    try {
      fresh = await _controller.playlist;
    } on Object {
      fresh = const [];
    }
    if (!mounted || !identical(current, _current)) return;
    // Empty while the playlist loads, and once the player has left it for
    // a suggested video.
    final known = fresh.isNotEmpty ? fresh : _playlist;
    if (known.isEmpty) return;
    if (!known.contains(id)) {
      await _controller.loadPlaylist(
        list: [current.id],
        listType: ListType.playlist,
        index: _index,
      );
      return;
    }
    if (fresh.isNotEmpty) _playlist = fresh;
    final start = _startAt;
    if (start != null) {
      _startAt = null;
      final at = known.indexOf(start);
      if (at > 0 && at != known.indexOf(id)) {
        await _controller.playVideoAt(at);
        return;
      }
    }
    setState(() => _index = known.indexOf(id));
    await ref
        .read(focusRepositoryProvider)
        .saveStudyPlaylistIndex(current.id, _index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final videos =
        (ref.watch(focusPrefsProvider).value ?? const FocusPrefs()).studyVideos;
    final current = _current;

    return Scaffold(
      appBar: AppBar(title: const Text('Study videos')),
      body: SafeArea(
        top: false,
        // Not a ListView: scrolled out of sight, the player would be
        // rebuilt and start over.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (current != null)
                YoutubePlayer(controller: _controller)
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: Text(
                        videos.isEmpty
                            ? 'Add a study video on the Focus page'
                            : 'Pick a video below',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              if (current != null)
                YoutubeValueBuilder(
                  controller: _controller,
                  builder: (context, value) => Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.metaData.title.isNotEmpty
                              ? value.metaData.title
                              : current.label,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (value.error != YoutubeError.none) ...[
                          const SizedBox(height: Gap.xs),
                          Text(
                            switch (value.error) {
                              YoutubeError.notEmbeddable ||
                              YoutubeError.sameAsNotEmbeddable => 'Its owner lets it play only on YouTube itself.',
                              YoutubeError.videoNotFound ||
                              YoutubeError.cannotFindVideo =>
                                'This video is private or was removed.',
                              _ => 'This video could not be played.',
                            },
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ],
                        if (current.isPlaylist) ...[
                          const SizedBox(height: Gap.xs),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _playlist.isEmpty
                                      ? current.label
                                      : '${current.label} · '
                                            '${_index + 1} of ${_playlist.length}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Previous',
                                onPressed: _index > 0
                                    ? _controller.previousVideo
                                    : null,
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              IconButton(
                                tooltip: 'Next',
                                onPressed:
                                    _playlist.isEmpty ||
                                        _index < _playlist.length - 1
                                    ? _controller.nextVideo
                                    : null,
                                icon: const Icon(Icons.skip_next_rounded),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Gap.m),
              for (final v in videos)
                ListTile(
                  leading: Icon(
                    v.isPlaylist
                        ? Icons.playlist_play_rounded
                        : Icons.smart_display_rounded,
                  ),
                  title: Text(v.label),
                  subtitle: Text(v.isPlaylist ? 'Playlist' : 'Video'),
                  selected: current?.sameAs(v) ?? false,
                  onTap: () => _play(v),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
