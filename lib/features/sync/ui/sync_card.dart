import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/formatters.dart';
import '../application/sync_providers.dart';
import '../data/sync_api.dart';
import '../domain/sync_record.dart';
import 'pair_sheet.dart';

/// The devices in this device's space, fetched again after every sync so a
/// device that just joined or left shows up.
final syncedDevicesProvider = FutureProvider.autoDispose<List<SyncedDevice>>((
  ref,
) async {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return const [];
  ref.watch(syncStatusProvider.select((s) => s.lastSynced));
  return service.devices();
});

/// Settings card: whether this device is in step with the others, which
/// devices those are, and pairing.
class SyncCard extends ConsumerWidget {
  const SyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    if (status.phase == SyncPhase.off) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.cloud_off_rounded),
          title: Text('Sync is not set up in this build'),
          subtitle: Text('Reminders stay on this device.'),
        ),
      );
    }
    final devices = ref.watch(syncedDevicesProvider);
    final list = devices.value ?? const <SyncedDevice>[];
    final others = list.where((d) => !d.isMe).toList();
    final now = DateTime.now();

    return Card(
      child: Column(
        children: [
          _StatusTile(status: status, now: now),
          if (others.isNotEmpty) ...[
            const Divider(indent: 56),
            for (final d in others)
              ListTile(
                leading: Icon(
                  d.isPhone ? Icons.smartphone_rounded : Icons.laptop_rounded,
                ),
                title: Text(d.name),
                subtitle: Text('Seen ${formatRelative(d.lastSeen, now)}'),
              ),
          ] else if (devices.hasValue)
            const ListTile(
              leading: Icon(Icons.devices_rounded),
              title: Text('No other devices yet'),
              subtitle: Text(
                'Pair your phone and laptop so reminders you set on one ring '
                'on the other.',
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xs, Gap.l, Gap.l),
            child: Wrap(
              spacing: Gap.s,
              runSpacing: Gap.s,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => openPairSheet(context),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Pair a device'),
                ),
                if (others.isNotEmpty)
                  TextButton(
                    onPressed: () => _unpair(context, ref),
                    child: const Text('Unpair this device'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unpair(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair this device?'),
        content: const Text(
          'Everything stays on this device, but changes stop going to and '
          'from your other devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncServiceProvider)?.unpair();
      ref.invalidate(syncedDevicesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Unpaired')));
    } on SyncUnavailable {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reach the sync server')),
      );
    }
  }
}

class _StatusTile extends ConsumerWidget {
  const _StatusTile({required this.status, required this.now});

  final SyncStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final last = status.lastSynced;
    final (icon, title, subtitle) = switch (status.phase) {
      SyncPhase.syncing => (Icons.sync_rounded, 'Syncing', null),
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        'Offline',
        'Changes wait on this device and go out when it is back online.',
      ),
      _ => (
        Icons.cloud_done_rounded,
        'Up to date',
        last == null ? null : 'Synced ${formatRelative(last, now)}',
      ),
    };
    return ListTile(
      leading: Icon(
        icon,
        color: status.phase == SyncPhase.offline ? scheme.error : null,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: IconButton(
        tooltip: 'Sync now',
        onPressed: status.phase == SyncPhase.syncing
            ? null
            : () => ref.read(syncStatusProvider.notifier).syncNow(),
        icon: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}
