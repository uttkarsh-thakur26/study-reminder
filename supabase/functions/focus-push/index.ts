// focus-push: wakes the other devices in a sync space when a focus session
// starts, changes or stops, so a phone with the app closed reacts at once.
//
// The app calls it with {"secret": "<device secret>"} right after it pushes
// the focus session. The function asks the database, the same way the app
// does, for the other devices' push tokens and the session, then sends each
// device a high-priority Firebase data message.
//
// Needs the secret FIREBASE_SERVICE_ACCOUNT: the whole JSON key file of the
// Firebase project's service account. Deploy with JWT verification off; the
// device secret is the check.

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

let account: ServiceAccount | null = null;
let cached: { token: string; expires: number } | null = null;

function serviceAccount(): ServiceAccount {
  if (account) return account;
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!raw) throw new Error('The FIREBASE_SERVICE_ACCOUNT secret is not set');
  account = JSON.parse(raw) as ServiceAccount;
  return account;
}

const utf8 = (s: string) => new TextEncoder().encode(s);

function base64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// An OAuth token for Firebase Cloud Messaging, from a JWT signed with the
// service account's key. Kept until a minute before it expires.
async function accessToken(sa: ServiceAccount): Promise<string> {
  if (cached && cached.expires > Date.now() + 60_000) return cached.token;
  const now = Math.floor(Date.now() / 1000);
  const head = base64url(utf8(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(utf8(JSON.stringify({
    iss: sa.client_email,
    scope: SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  })));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, utf8(`${head}.${claims}`));
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${head}.${claims}.${base64url(new Uint8Array(signature))}`,
    }),
  });
  if (!res.ok) throw new Error(`Google sign-in failed (${res.status}): ${await res.text()}`);
  const body = await res.json();
  cached = { token: body.access_token, expires: Date.now() + body.expires_in * 1000 };
  return cached.token;
}

// The project's public key: the one the app sent, else the function's own.
function publicKey(req: Request): string {
  const sent = req.headers.get('apikey');
  if (sent) return sent;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}');
    const first = Object.values(keys)[0];
    if (typeof first === 'string') return first;
  } catch {
    // Not set on this project.
  }
  return Deno.env.get('SUPABASE_ANON_KEY') ?? '';
}

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return reply(405, { error: 'Use POST' });
  let secret: unknown;
  try {
    secret = (await req.json()).secret;
  } catch {
    // Checked below.
  }
  if (typeof secret !== 'string' || secret.length === 0 || secret.length > 512) {
    return reply(400, { error: 'Missing device secret' });
  }

  const key = publicKey(req);
  const targets = await fetch(`${Deno.env.get('SUPABASE_URL')}/rest/v1/rpc/focus_push_targets`, {
    method: 'POST',
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_secret: secret }),
  });
  if (!targets.ok) {
    const error = await targets.json().catch(() => ({}));
    const status = error.code === 'SR401' ? 401 : error.code === 'SR429' ? 429 : 502;
    return reply(status, { error: error.message ?? 'Database call failed' });
  }
  const { tokens, focus } = await targets.json() as { tokens: string[]; focus: unknown };
  if (focus == null || tokens.length === 0) return reply(200, { sent: 0 });

  try {
    const sa = serviceAccount();
    const auth = await accessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const data = { type: 'focus', focus: JSON.stringify(focus) };
    const sent = await Promise.all(tokens.map(async (token) => {
      const res = await fetch(url, {
        method: 'POST',
        headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            data,
            // Only the newest focus message matters if the phone was offline.
            android: { priority: 'HIGH', ttl: '600s', collapse_key: 'focus' },
          },
        }),
      });
      if (!res.ok) console.warn(`Firebase refused a message (${res.status}): ${await res.text()}`);
      return res.ok;
    }));
    return reply(200, { sent: sent.filter(Boolean).length });
  } catch (e) {
    console.error(e);
    return reply(500, { error: e instanceof Error ? e.message : String(e) });
  }
});
