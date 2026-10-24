import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/focus_providers.dart';
import '../domain/focus_prefs.dart';
import '../domain/study_videos.dart';
import 'study_embed.dart';

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
  late final StudyEmbedController _embed;
  late final AppLifecycleListener _lifecycle;

  /// Keeps the player when the layout changes for full screen.
  final _playerKey = GlobalKey();
  StudyVideo? _current;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    StudyPlayerScreen.openCount++;
    _embed = StudyEmbedController(
      onPlaylistIndex: _saveIndex,
      onBlocked: _showBlocked,
    )..addListener(_changed);
    // Stops with the app out of sight, as YouTube's own player does.
    _lifecycle = AppLifecycleListener(onHide: () => unawaited(_embed.pause()));
    unawaited(_start());
  }

  @override
  void dispose() {
    StudyPlayerScreen.openCount--;
    _lifecycle.dispose();
    _embed
      ..removeListener(_changed)
      ..dispose();
    if (_fullscreen) unawaited(_systemUi(fullscreen: false));
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
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
    setState(() => _current = video);
    if (!video.isPlaylist) {
      await _embed.open(video);
      return;
    }
    final saved = await ref
        .read(focusRepositoryProvider)
        .studyPlaylistIndex(video.id);
    if (!mounted || !identical(video, _current)) return;
    await _embed.open(
      video,
      index: saved ?? 0,
      startAt: saved == null ? video.startId : null,
    );
  }

  void _saveIndex(StudyVideo playlist, int index) {
    if (!mounted) return;
    unawaited(
      ref
          .read(focusRepositoryProvider)
          .saveStudyPlaylistIndex(playlist.id, index),
    );
  }

  void _showBlocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Only your study videos play here.')),
      );
  }

  Future<void> _setFullscreen(bool on) async {
    setState(() => _fullscreen = on);
    await _systemUi(fullscreen: on);
  }

  Future<void> _systemUi({required bool fullscreen}) async {
    await SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    await SystemChrome.setPreferredOrientations(
      fullscreen
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final videos =
        (ref.watch(focusPrefsProvider).value ?? const FocusPrefs()).studyVideos;
    final current = _current;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final player = KeyedSubtree(
      key: _playerKey,
      child: current != null
          ? StudyEmbed(controller: _embed)
          : ColoredBox(
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
    );

    // The player alone, filling the screen.
    if (_fullscreen || landscape) {
      return PopScope(
        canPop: !_fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_setFullscreen(false));
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: AspectRatio(aspectRatio: 16 / 9, child: player),
              ),
              if (_fullscreen)
                Positioned(
                  top: Gap.s,
                  right: Gap.s,
                  child: IconButton(
                    tooltip: 'Exit full screen',
                    color: Colors.white,
                    onPressed: () => _setFullscreen(false),
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Study videos')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Not in a scrolling list: scrolled away, the player would
            // start over, and the list would take its swipes.
            AspectRatio(aspectRatio: 16 / 9, child: player),
            if (current != null) _info(theme, current),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: Gap.s),
                children: [
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
          ],
        ),
      ),
    );
  }

  /// The title, how far into the playlist, what the player is waiting for,
  /// and the buttons under the player.
  Widget _info(ThemeData theme, StudyVideo current) {
    final scheme = theme.colorScheme;
    final embed = _embed;
    final problem = embed.problem;
    final status = switch (problem) {
      EmbedProblem.offline =>
        "YouTube's player didn't load. Check the internet connection.",
      EmbedProblem.notEmbeddable =>
        'Its owner lets it play only on YouTube itself.',
      EmbedProblem.notFound => 'This video is private or was removed.',
      EmbedProblem.refused => 'YouTube turned the player down.',
      EmbedProblem.other => 'This video could not be played.',
      null when !embed.ready => "Loading YouTube's player…",
      null when embed.needsTap => 'Tap the video to play.',
      null => null,
    };
    final playlist = current.isPlaylist;
    final count = embed.count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.s, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.s),
            child: Text(
              embed.title.isNotEmpty ? embed.title : current.label,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  playlist && count > 0
                      ? '${current.label} · ${embed.index + 1} of $count'
                      : current.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (playlist) ...[
                IconButton(
                  tooltip: 'Previous',
                  onPressed: count > 0 && embed.index > 0
                      ? embed.previous
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: count > 0 && embed.index < count - 1
                      ? embed.next
                      : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
              IconButton(
                tooltip: 'Full screen',
                onPressed: () => _setFullscreen(true),
                icon: const Icon(Icons.fullscreen_rounded),
              ),
            ],
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(right: Gap.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: problem != null
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (problem == EmbedProblem.offline ||
                      problem == EmbedProblem.refused)
                    TextButton(
                      onPressed: embed.retry,
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
