import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/focus_providers.dart';
import '../data/youtube_titles.dart';
import '../domain/focus_prefs.dart';
import '../domain/study_videos.dart';
import 'study_embed.dart';
import 'study_site.dart';

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

  /// YouTube's mobile site, made when it is first needed.
  StudySiteController? _site;

  /// Whether videos play on YouTube's mobile site rather than in the app's
  /// own player.
  bool _onSite = false;

  /// Keeps the player when the layout changes for full screen.
  final _playerKey = GlobalKey();
  StudyVideo? _current;
  bool _fullscreen = false;

  /// The list of the playlist's videos, and the video it was last brought
  /// into view for.
  final _listScroll = ScrollController();
  String _listShows = '';

  @override
  void initState() {
    super.initState();
    StudyPlayerScreen.openCount++;
    _embed = StudyEmbedController(onPlace: _savePlace, onBlocked: _showBlocked)
      ..addListener(_embedChanged);
    // Stops with the app out of sight, as YouTube's own player does.
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_onSite ? _site?.pause() : _embed.pause()),
    );
    unawaited(_start());
  }

  @override
  void dispose() {
    StudyPlayerScreen.openCount--;
    _lifecycle.dispose();
    _embed
      ..removeListener(_embedChanged)
      ..dispose();
    _site
      ?..removeListener(_changed)
      ..dispose();
    _listScroll.dispose();
    if (_fullscreen) unawaited(_systemUi(fullscreen: false));
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _embedChanged() {
    _changed();
    _showPlaying();
    // YouTube won't play it in the app's player: its site will.
    final problem = _embed.problem;
    if (!_onSite &&
        (problem == EmbedProblem.notEmbeddable ||
            problem == EmbedProblem.refused ||
            problem == EmbedProblem.other)) {
      unawaited(_useSite(true, told: true));
    }
  }

  /// Brings the video playing into view in the list of the playlist's
  /// videos when it moves on to one out of view: at once the first time,
  /// smoothly after.
  void _showPlaying() {
    final embed = _embed;
    final index = embed.index;
    if (embed.playlist.length <= index || embed.videoId.isEmpty) return;
    final key = '${embed.video?.id}|${embed.videoId}';
    if (key == _listShows) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScroll.hasClients || key == _listShows) return;
      final first = _listShows.isEmpty;
      _listShows = key;
      final position = _listScroll.position;
      const extent = _PlaylistRow.extent;
      final top = index * extent;
      if (top >= position.pixels &&
          top + extent <= position.pixels + position.viewportDimension) {
        return;
      }
      final to = (top - extent).clamp(0.0, position.maxScrollExtent);
      if (first) {
        _listScroll.jumpTo(to);
      } else {
        unawaited(
          _listScroll.animateTo(
            to,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  StudySiteController get _siteView => _site ??= StudySiteController(
    onPlace: _savePlace,
    onBlocked: _showBlocked,
  )..addListener(_changed);

  Future<void> _start() async {
    final repo = ref.read(focusRepositoryProvider);
    final videos = (await repo.prefs()).studyVideos;
    final onSite = await repo.studyPlayerUsesSite();
    final first =
        videos.where((v) => widget.initial?.sameAs(v) ?? false).firstOrNull ??
        videos.firstOrNull;
    if (!mounted) return;
    setState(() => _onSite = onSite);
    if (first != null) await _play(first);
  }

  /// Plays [video], unless it is playing already.
  Future<void> _choose(StudyVideo video) async {
    final current = _current;
    if (current != null &&
        current.sameAs(video) &&
        (_onSite || _embed.problem == null)) {
      return;
    }
    await _play(video);
  }

  Future<void> _play(StudyVideo video) async {
    setState(() {
      _current = video;
      _listShows = '';
    });
    final place = video.isPlaylist
        ? await ref.read(focusRepositoryProvider).studyPlaylistPlace(video.id)
        : null;
    if (!mounted || !identical(video, _current)) return;
    if (_onSite) {
      await _siteView.open(video, at: place?.video);
      return;
    }
    if (_site != null) unawaited(_site!.pause());
    await _embed.open(
      video,
      index: place?.index ?? 0,
      startAt: place?.video ?? (place == null ? video.startId : null),
    );
  }

  /// Switches between YouTube's mobile site and the app's own player, and
  /// keeps it for next time. [told] says why when it was YouTube's doing.
  Future<void> _useSite(bool site, {bool told = false}) async {
    if (site == _onSite) return;
    setState(() {
      _onSite = site;
      if (site && _fullscreen) _fullscreen = false;
    });
    if (site) {
      unawaited(_embed.pause());
      unawaited(_systemUi(fullscreen: false));
    }
    unawaited(ref.read(focusRepositoryProvider).saveStudyPlayerUsesSite(site));
    if (told && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "YouTube wouldn't play it in the app's player, so it plays "
              "on YouTube's site here instead.",
            ),
          ),
        );
    }
    final current = _current;
    if (current != null) await _play(current);
  }

  void _savePlace(StudyVideo playlist, String video, int? index) {
    if (!mounted) return;
    unawaited(
      ref
          .read(focusRepositoryProvider)
          .saveStudyPlaylistPlace(playlist.id, video: video, index: index),
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

  /// Opens a list of the study videos to switch to.
  Future<void> _pick(List<StudyVideo> videos) async {
    final picked = await showModalBottomSheet<StudyVideo>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
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
                selected: _current?.sameAs(v) ?? false,
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) await _choose(picked);
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

    final switchView = IconButton(
      tooltip: _onSite ? "Use the app's player" : "Use YouTube's site",
      onPressed: () => _useSite(!_onSite),
      icon: Icon(_onSite ? Icons.smart_display_rounded : Icons.public_rounded),
    );
    final pick = IconButton(
      tooltip: 'Your study videos',
      onPressed: () => _pick(videos),
      icon: const Icon(Icons.video_library_rounded),
    );

    if (_onSite && current != null) {
      final site = StudySite(controller: _siteView);
      // YouTube's site has its own player, playlist and full screen.
      if (landscape) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: site),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Study videos'),
          actions: [if (videos.length > 1) pick, switchView],
        ),
        body: SafeArea(top: false, child: site),
      );
    }

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

    final playlist = _embed.playlist;
    // A playlist lists its videos, with the study videos a tap away above.
    final showsPlaylist =
        current != null && current.isPlaylist && playlist.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study videos'),
        actions: [
          if (showsPlaylist && videos.length > 1) pick,
          if (current != null) switchView,
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Not in a scrolling list: scrolled away, the player would
            // start over, and the list would take its swipes.
            AspectRatio(aspectRatio: 16 / 9, child: player),
            if (current != null) _info(theme, current),
            const Divider(height: Gap.s),
            Expanded(
              child: showsPlaylist
                  ? ListView.builder(
                      controller: _listScroll,
                      itemExtent: _PlaylistRow.extent,
                      itemCount: playlist.length,
                      itemBuilder: (context, i) => _PlaylistRow(
                        id: playlist[i],
                        number: i + 1,
                        playing: i == _embed.index,
                        onTap: () {
                          if (i != _embed.index) unawaited(_embed.playAt(i));
                        },
                      ),
                    )
                  : ListView(
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
                            onTap: () => _choose(v),
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

/// The titles of playlist videos looked up so far, by video id.
final _videoTitles = <String, Future<String?>>{};

/// The title of the video [id], looked up once. One that couldn't be
/// looked up is tried again the next time it is asked for.
Future<String?> _titleOf(String id) => _videoTitles.putIfAbsent(id, () async {
  final title = await lookUpYouTubeTitle(StudyVideo.video(id));
  if (title == null) _videoTitles.remove(id);
  return title;
});

/// One video of the playlist: its place, picture and title.
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.id,
    required this.number,
    required this.playing,
    required this.onTap,
  });

  /// The height of each row.
  static const extent = 80.0;

  final String id;

  /// Its place in the playlist, from 1.
  final int number;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: playing ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.m,
            vertical: Gap.s,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: playing
                    ? Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: scheme.primary,
                      )
                    : Text(
                        '$number',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: Gap.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.s),
                child: SizedBox(
                  width: 112,
                  height: 63,
                  child: Image.network(
                    'https://i.ytimg.com/vi/$id/mqdefault.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: scheme.surfaceContainerHighest),
                    frameBuilder: (_, child, frame, loaded) =>
                        loaded || frame != null
                        ? child
                        : ColoredBox(color: scheme.surfaceContainerHighest),
                  ),
                ),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _titleOf(id),
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? 'Video $number',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: playing ? FontWeight.w600 : null,
                      color: playing ? scheme.onSecondaryContainer : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
