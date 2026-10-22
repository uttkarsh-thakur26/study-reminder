/// Where the sync server lives. Set at build time with
/// `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_KEY=...`,
/// or filled in below for this project. The key is the project's public
/// (anon or publishable) key: it is meant to ship inside apps, because the
/// server only answers calls that carry a device's own secret.
abstract final class SyncConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _projectUrl,
  );
  static const publicKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: _projectKey,
  );

  static bool get isSet => url.isNotEmpty && publicKey.isNotEmpty;
}

const _projectUrl = 'https://uhvnlzocumbsodywkmal.supabase.co';
const _projectKey = 'sb_publishable_kDWyirVVx_OkT1xQB8odrQ_itkvyNwX';
