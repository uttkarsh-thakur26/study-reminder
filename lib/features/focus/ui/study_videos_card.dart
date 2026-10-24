import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../application/focus_providers.dart';
import '../data/youtube_titles.dart';
import '../domain/focus_prefs.dart';
import '../domain/study_videos.dart';
import 'study_player.dart';

/// The YouTube videos and playlists the user studies with, which Focus
/// lets through while YouTube is blocked. On the phone they play in the
/// app; on the laptop they open in the browser. Nothing can be added while
/// a strict session runs here.
class StudyVideosCard extends ConsumerWidget {
  const StudyVideosCard({
    super.key,
    required this.prefs,
    required this.onPhone,
    this.locked = false,
  });

  final FocusPrefs prefs;
  final bool onPhone;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final videos = prefs.studyVideos;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Study videos'),
            subtitle: Text(
              onPhone
                  ? 'YouTube stays blocked. These play in the app instead.'
                  : 'YouTube tabs close, except on these videos and '
                        'playlists.',
            ),
            trailing: TextButton.icon(
              onPressed: locked ? null : () => _add(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ),
          for (final v in videos)
            ListTile(
              leading: Icon(
                v.isPlaylist
                    ? Icons.playlist_play_rounded
                    : Icons.smart_display_rounded,
              ),
              title: Text(
                v.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(v.isPlaylist ? 'Playlist' : 'Video'),
              onTap: () => onPhone
                  ? openStudyPlayer(context, video: v)
                  : launchUrl(Uri.parse(v.url)),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _remove(ref, v),
              ),
            ),
          if (locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
              child: Text(
                'New ones can be added after this strict session.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (onPhone && videos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
              child: FilledButton.tonalIcon(
                onPressed: () => openStudyPlayer(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Watch'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final video = await showDialog<StudyVideo>(
      context: context,
      builder: (_) => const _AddStudyVideoDialog(),
    );
    if (video == null) return;
    final repo = ref.read(focusRepositoryProvider);
    final now = await repo.prefs();
    if (now.studyVideos.any(video.sameAs)) return;
    await repo.savePrefs(
      now.copyWith(studyVideos: [...now.studyVideos, video]),
    );
    final title = await lookUpYouTubeTitle(video);
    if (title == null) return;
    // Read again: the list may have changed while YouTube answered.
    final later = await repo.prefs();
    await repo.savePrefs(
      later.copyWith(
        studyVideos: [
          for (final v in later.studyVideos)
            v.sameAs(video) ? v.withTitle(title) : v,
        ],
      ),
    );
  }

  Future<void> _remove(WidgetRef ref, StudyVideo video) async {
    final repo = ref.read(focusRepositoryProvider);
    final now = await repo.prefs();
    await repo.savePrefs(
      now.copyWith(
        studyVideos: [
          for (final v in now.studyVideos)
            if (!v.sameAs(video)) v,
        ],
      ),
    );
  }
}

class _AddStudyVideoDialog extends StatefulWidget {
  const _AddStudyVideoDialog();

  @override
  State<_AddStudyVideoDialog> createState() => _AddStudyVideoDialogState();
}

class _AddStudyVideoDialogState extends State<_AddStudyVideoDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_pasteLink());
  }

  /// Fills in a YouTube link the user has just copied.
  Future<void> _pasteLink() async {
    try {
      final copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (copied != null &&
          StudyVideo.parse(copied) != null &&
          mounted &&
          _text.text.isEmpty) {
        _text.text = copied.trim();
      }
    } on Object {
      // Nothing to fill in.
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final video = StudyVideo.parse(_text.text);
    if (video == null) {
      setState(() => _error = 'Paste a YouTube link to a video or playlist');
      return;
    }
    Navigator.pop(context, video);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add a study video'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/playlist?list=…',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gap.m),
            Text(
              'In YouTube, tap Share and Copy link. A link to a video '
              'opened from a playlist adds the whole playlist.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
