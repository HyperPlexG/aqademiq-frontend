/* ─── ACCOUNTS ───────────────────────────────────────────────────────────
   The same Supabase accounts as the phone app: email + password confirmed
   with a 6-digit code, Google and Apple. Signed in, the planner reads and
   writes your account through the same API the app uses.

   Inside a claude.ai artifact the browser blocks calls to other sites, so
   sign-in can't reach Supabase there; the page notices and says so, and
   everything else keeps working as a guest. The same files on any website
   sign in for real. */

const SUPABASE_URL = 'https://qwvuoooentacjslzpbqy.supabase.co';
// The public anon key (safe in a browser: row-level security guards the data).
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dnVvb29lbnRhY2pzbHpwYnF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzOTYxMjIsImV4cCI6MjA5OTk3MjEyMn0.BT6va_XbYlJOZT8aDzybmX2jF_c1eUIY_GgG9A9Tgw4';
const API_BASE = SUPABASE_URL + '/functions/v1/api/v1';
const PW_MIN = 8;
const ACCOUNT_EXISTS = 'That email already has an account. Sign in instead — and if you first joined with Apple or Google, use that button.';

const SB = {
  client: null, reachable: null, session: null, user: null, subs: new Set(), probe: null,
  emit() { this.subs.forEach((f) => f({ session: this.session, reachable: this.reachable })); },
  on(f) { this.subs.add(f); return () => this.subs.delete(f); },
};

// Can this page talk to Supabase at all? (No inside a claude.ai artifact.)
function probeAuth() {
  if (SB.probe) return SB.probe;
  SB.probe = (async () => {
    try {
      const ctl = new AbortController();
      const t = setTimeout(() => ctl.abort(), 6000);
      const r = await fetch(SUPABASE_URL + '/auth/v1/settings', { headers: { apikey: SUPABASE_ANON }, signal: ctl.signal });
      clearTimeout(t);
      SB.reachable = r.ok;
    } catch (e) { SB.reachable = false; }
    if (SB.reachable && window.supabase && window.supabase.createClient) {
      // Sessions persist in this browser, like the phone keeps you signed in.
      SB.client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' } });
      try { const { data } = await SB.client.auth.getSession(); SB.session = data.session || null; } catch (e) { SB.session = null; }
      SB.client.auth.onAuthStateChange((ev, session) => {
        SB.session = session || null;
        // However the session ends (sign out here, in another tab, or expiry), drop
        // the account's local copy from this browser.
        if (ev === 'SIGNED_OUT') { try { Object.keys(localStorage).filter((k) => k.startsWith('aq-web-acct-')).forEach((k) => localStorage.removeItem(k)); } catch (e) { /* ignore */ } }
        SB.emit();
      });
    } else if (SB.reachable) {
      SB.reachable = false; // the library didn't load
    }
    SB.emit();
    return SB.reachable;
  })();
  return SB.probe;
}

function useAuth() {
  const [st, setSt] = React.useState({ session: SB.session, reachable: SB.reachable });
  React.useEffect(() => { probeAuth(); return SB.on(setSt); }, []);
  return st;
}

// Friendlier words for Supabase's errors (the phone app shows the same ideas).
function authMessage(e) {
  const m = String((e && (e.message || e.error_description)) || e || '');
  if (/invalid login credentials/i.test(m)) return 'That email and password don\'t match. Try again, or use Forgot password.';
  if (/email not confirmed/i.test(m)) return 'Confirm your email first: enter the 6-digit code we sent you.';
  if (/token has expired|otp.*(expired|invalid)|invalid.*token/i.test(m)) return 'That code didn\'t work. Check it, or send a new one.';
  if (/rate limit|too many|security purposes/i.test(m)) return 'Too many tries. Wait a minute, then try again.';
  if (/password should be at least|weak password/i.test(m)) return `Use at least ${PW_MIN} characters.`;
  if (/already (been )?registered|email_exists|user already/i.test(m)) return ACCOUNT_EXISTS;
  if (/failed to fetch|network/i.test(m)) return 'Can\'t reach Aqademiq right now. Check your connection.';
  return m || 'Something went wrong. Try again.';
}

/* ── the API, with the same contract as the app's Dio client ── */
class ApiError extends Error { constructor(status, body) { super((body && (body.message || body.error)) || ('HTTP ' + status)); this.status = status; this.body = body; } }
async function api(method, path, body, opts = {}) {
  const session = SB.session;
  if (!session) throw new ApiError(401, { message: 'Not signed in' });
  const headers = { Authorization: 'Bearer ' + session.access_token, apikey: SUPABASE_ANON, Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (method !== 'GET') headers['Idempotency-Key'] = opts.key || (crypto.randomUUID ? crypto.randomUUID() : uid() + uid());
  const send = () => fetch(API_BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  let r = await send();
  if (r.status === 401 && SB.client && !opts.retried) {
    // One refresh-and-retry, like the app's AuthInterceptor.
    try { const { data } = await SB.client.auth.refreshSession(); if (data.session) { SB.session = data.session; headers.Authorization = 'Bearer ' + data.session.access_token; r = await send(); } } catch (e) { /* fall through */ }
  }
  const text = await r.text();
  let json = null; try { json = text ? JSON.parse(text) : null; } catch (e) { json = { message: text }; }
  if (!r.ok) throw new ApiError(r.status, json);
  return json;
}

/* ── account screens (v11 SB / AUTH_SIGNUP / AUTH_OTP) ── */
function AuthScreen({ start = 'signin', onClose, onDone, guestBlurb }) {
  const { reachable } = useAuth();
  const [mode, setMode] = React.useState(start); // signin | signup | otp | forgot | reset
  const [email, setEmail] = React.useState('');
  const [name, setName] = React.useState('');
  const [pw, setPw] = React.useState('');
  const [pw2, setPw2] = React.useState('');
  const [show, setShow] = React.useState(false);
  const [code, setCode] = React.useState('');
  const [otpType, setOtpType] = React.useState('signup');
  const [busy, setBusy] = React.useState(false);
  const [err, setErr] = React.useState('');
  const [note, setNote] = React.useState('');
  const [cool, setCool] = React.useState(0);
  React.useEffect(() => { if (!cool) return; const t = setTimeout(() => setCool(cool - 1), 1000); return () => clearTimeout(t); }, [cool]);
  const offline = reachable === false;
  const checking = reachable === null;
  const go = (m) => { setMode(m); setErr(''); setNote(''); };
  const run = async (fn) => {
    if (offline) { setErr('Signing in works on the hosted Aqademiq web app. Here, keep going as a guest.'); return; }
    setBusy(true); setErr('');
    try {
      await probeAuth();
      // The check can finish "unreachable" after the screen opened: say so plainly.
      if (!SB.client) throw new Error('Signing in works on the hosted Aqademiq web app. Here, keep going as a guest.');
      await fn();
    } catch (e) { setErr(authMessage(e)); } finally { setBusy(false); }
  };
  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());

  const signIn = () => run(async () => {
    const { data, error } = await SB.client.auth.signInWithPassword({ email: email.trim(), password: pw });
    if (error && /email not confirmed/i.test(error.message || '')) {
      // Signed up but never confirmed: send a fresh code and go straight to it.
      await SB.client.auth.resend({ type: 'signup', email: email.trim() });
      setOtpType('signup'); setCode(''); setCool(30); go('otp');
      setNote('Confirm your email first: we sent you a new 6-digit code.');
      return;
    }
    if (error) throw error;
    SB.session = data.session; SB.emit(); onDone && onDone('signin');
  });
  const signUp = () => run(async () => {
    if (pw.length < PW_MIN) throw new Error(`Use at least ${PW_MIN} characters.`);
    if (pw !== pw2) throw new Error('The passwords don\'t match.');
    const { data, error } = await SB.client.auth.signUp({ email: email.trim(), password: pw, options: { data: { name: name.trim() } } });
    if (error) throw error;
    if (data.session) { SB.session = data.session; SB.emit(); onDone && onDone('signup'); return; }
    // Supabase hides "email taken" behind a fake success with no identities (no email is sent).
    if (data.user && Array.isArray(data.user.identities) && data.user.identities.length === 0) throw new Error(ACCOUNT_EXISTS);
    setOtpType('signup'); setCode(''); setCool(30); go('otp');
  });
  const verify = () => run(async () => {
    const { data, error } = await SB.client.auth.verifyOtp({ email: email.trim(), token: code.trim(), type: otpType });
    if (error) throw error;
    SB.session = data.session; SB.emit();
    if (otpType === 'recovery') { setPw(''); setPw2(''); go('reset'); return; }
    if (name.trim()) { try { await api('PATCH', '/profile', { name: name.trim() }); } catch (e) { /* not fatal */ } }
    onDone && onDone('signup');
  });
  const resend = () => run(async () => {
    const { error } = otpType === 'recovery' ? await SB.client.auth.resetPasswordForEmail(email.trim()) : await SB.client.auth.resend({ type: 'signup', email: email.trim() });
    if (error) throw error;
    setNote('A new code is on its way.'); setCool(30);
  });
  const forgot = () => run(async () => {
    const { error } = await SB.client.auth.resetPasswordForEmail(email.trim());
    if (error) throw error;
    setOtpType('recovery'); setCode(''); setCool(30); go('otp');
    setNote(`If ${email.trim()} has an account, a reset code is on its way.`);
  });
  const savePw = () => run(async () => {
    if (pw.length < PW_MIN) throw new Error(`Use at least ${PW_MIN} characters.`);
    if (pw !== pw2) throw new Error('The passwords don\'t match.');
    const { error } = await SB.client.auth.updateUser({ password: pw });
    if (error) throw error;
    onDone && onDone('reset');
  });
  const oauth = (provider) => run(async () => {
    const { error } = await SB.client.auth.signInWithOAuth({ provider, options: { redirectTo: location.origin + location.pathname } });
    if (error) throw error; // on success the browser leaves for Google/Apple and comes back signed in
  });

  const pwField = (value, set, ph, auto) =>
  <div style={{ position: 'relative' }}>
      <input className="input" type={show ? 'text' : 'password'} autoComplete={auto} placeholder={ph} value={value} onChange={(e) => set(e.target.value)} style={{ paddingRight: 48 }} />
      <button type="button" className="iconbtn" onClick={() => setShow(!show)} aria-label={show ? 'Hide password' : 'Show password'} style={{ position: 'absolute', right: 4, top: 4 }}><Ic n={show ? 'visible' : 'hidden'} style={{ fontSize: 20, color: MED }} /></button>
    </div>;
  const submit = (fn) => (e) => { e.preventDefault(); if (!busy) fn(); };

  return (
    <div className="authwrap">
      <div className="authcard">
        <div className="spread" style={{ marginBottom: 18 }}>
          {mode === 'signin' || mode === 'signup' ? <img src={window.__resources.logo} alt="" style={{ width: 40, height: 40, borderRadius: 12 }} /> :
          <button className="iconbtn" onClick={() => go(mode === 'reset' ? 'signin' : otpType === 'recovery' ? 'forgot' : 'signup')} aria-label="Back"><Ic n="back" style={{ fontSize: 24 }} /></button>}
          {onClose && <button className="iconbtn" onClick={onClose} aria-label="Close"><Ic n="close" style={{ fontSize: 22 }} /></button>}
        </div>

        {offline && <div className="authnote">Signing in to your Aqademiq account works on the hosted web app, where it's the same account as on your phone. In this preview, you can use everything as a guest.</div>}

        {mode === 'signin' && <form onSubmit={submit(signIn)}>
          <h1 className="h1">Welcome.</h1>
          <div className="sub" style={{ margin: '4px 0 22px' }}>Sign in to continue{guestBlurb ? '. ' + guestBlurb : ''}</div>
          <OAuthButtons onPick={oauth} busy={busy} />
          <div className="ordiv"><span>or email</span></div>
          <div className="field"><span>Email</span><input className="input" type="email" autoComplete="email" placeholder="you@university.edu" value={email} onChange={(e) => setEmail(e.target.value)} /></div>
          <div className="field"><span>Password</span>{pwField(pw, setPw, 'Your password', 'current-password')}</div>
          <div style={{ textAlign: 'right', marginTop: -6, marginBottom: 16 }}><button type="button" className="link" style={{ fontSize: 14 }} onClick={() => go('forgot')}>Forgot password?</button></div>
          {err && <div className="autherr" role="alert">{err}</div>}
          <button className="btn block" type="submit" disabled={busy || checking || !emailOk || !pw}>{busy ? 'Signing in…' : 'Sign in →'}</button>
          <div className="small" style={{ textAlign: 'center', marginTop: 16 }}>New here? <button type="button" className="link" style={{ fontSize: 13 }} onClick={() => go('signup')}>Create an account</button></div>
        </form>}

        {mode === 'signup' && <form onSubmit={submit(signUp)}>
          <h1 className="h1">Create account</h1>
          <div className="sub" style={{ margin: '4px 0 22px' }}>Save your streak, grades & plan. It's the same account on your phone.</div>
          <OAuthButtons onPick={oauth} busy={busy} />
          <div className="ordiv"><span>or email</span></div>
          <div className="field"><span>Name</span><input className="input" autoComplete="given-name" placeholder="First name is fine" value={name} onChange={(e) => setName(e.target.value)} /></div>
          <div className="field"><span>Email</span><input className="input" type="email" autoComplete="email" placeholder="you@university.edu" value={email} onChange={(e) => setEmail(e.target.value)} /></div>
          <div className="field"><span>Password</span>{pwField(pw, setPw, `At least ${PW_MIN} characters`, 'new-password')}</div>
          <div className="field"><span>Confirm password</span>{pwField(pw2, setPw2, 'Type it again', 'new-password')}</div>
          {err && <div className="autherr" role="alert">{err}</div>}
          <button className="btn block" type="submit" disabled={busy || checking || !emailOk || !pw || !pw2}>{busy ? 'Creating…' : 'Create account →'}</button>
          <div className="small" style={{ textAlign: 'center', marginTop: 16 }}>Already have an account? <button type="button" className="link" style={{ fontSize: 13 }} onClick={() => go('signin')}>Sign in</button></div>
        </form>}

        {mode === 'otp' && <form onSubmit={submit(verify)}>
          <h1 className="h1">Verify it's you</h1>
          <div className="sub" style={{ margin: '4px 0 22px' }}>We sent a 6-digit code to<br /><b style={{ color: TEXT }}>{email.trim()}</b></div>
          <input className="input otp" inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="••••••" aria-label="6-digit code" value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))} autoFocus />
          {note && <div className="small" style={{ marginTop: 10 }}>{note}</div>}
          {err && <div className="autherr" role="alert" style={{ marginTop: 12 }}>{err}</div>}
          <button className="btn block" type="submit" style={{ marginTop: 18 }} disabled={busy || code.length !== 6}>{busy ? 'Verifying…' : 'Verify →'}</button>
          <div style={{ textAlign: 'center', marginTop: 14 }}>{cool ? <span className="small">Resend in 0:{pad2(cool)}</span> : <button type="button" className="link" style={{ fontSize: 14 }} onClick={resend} disabled={busy}>Resend</button>}</div>
        </form>}

        {mode === 'forgot' && <form onSubmit={submit(forgot)}>
          <h1 className="h1">Forgot password</h1>
          <div className="sub" style={{ margin: '4px 0 22px' }}>We'll email you a 6-digit code to set a new one.</div>
          <div className="field"><span>Email</span><input className="input" type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} autoFocus /></div>
          {err && <div className="autherr" role="alert">{err}</div>}
          <button className="btn block" type="submit" disabled={busy || !emailOk}>{busy ? 'Sending…' : 'Send code →'}</button>
        </form>}

        {mode === 'reset' && <form onSubmit={submit(savePw)}>
          <h1 className="h1">Set a new password</h1>
          <div className="sub" style={{ margin: '4px 0 22px' }}>Choose a password for {email.trim() || 'your account'}.</div>
          <div className="field"><span>New password</span>{pwField(pw, setPw, `At least ${PW_MIN} characters`, 'new-password')}</div>
          <div className="field"><span>Confirm password</span>{pwField(pw2, setPw2, 'Type it again', 'new-password')}</div>
          {err && <div className="autherr" role="alert">{err}</div>}
          <button className="btn block" type="submit" disabled={busy || !pw || !pw2}>{busy ? 'Saving…' : 'Save password'}</button>
        </form>}
      </div>
    </div>);
}

function OAuthButtons({ onPick, busy }) {
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <button type="button" className="btn ghost block oauth" onClick={() => onPick('apple')} disabled={busy}>
        <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.83-.81-3-.79-1.55.02-2.97.9-3.77 2.28-1.6 2.78-.41 6.9 1.15 9.15.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.68zM14.1 5.86c.63-.77 1.06-1.83.94-2.89-.91.04-2.01.61-2.66 1.37-.58.67-1.09 1.75-.95 2.79 1.01.08 2.05-.51 2.67-1.27z" /></svg>
        Sign in with Apple
      </button>
      <button type="button" className="btn ghost block oauth" onClick={() => onPick('google')} disabled={busy}>
        <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1z" /><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A11 11 0 0 0 12 23z" /><path fill="#FBBC05" d="M5.84 14.1A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.44.34-2.1V7.07H2.18A11 11 0 0 0 1 12c0 1.78.43 3.45 1.18 4.93l3.66-2.84z" /><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" /></svg>
        Sign in with Google
      </button>
    </div>);
}

/* ── top-bar account button + menu ── */
function AccountButton({ s, onSettings }) {
  const ui = useUI();
  const { session } = useAuth();
  const [open, setOpen] = React.useState(false);
  const ref = useDismiss(open, () => setOpen(false));
  if (!session) return <button className="signinbtn" onClick={() => ui.openAuth('signin')}>Sign in</button>;
  const email = session.user && session.user.email || '';
  const name = s.profile.name || (session.user && session.user.user_metadata && session.user.user_metadata.name) || email.split('@')[0];
  return (
    <div style={{ position: 'relative' }} ref={ref}>
      <button className="acctbtn" onClick={() => setOpen(!open)} aria-haspopup="menu" aria-expanded={open} aria-label={'Account: ' + name}>
        <span className="avatar" style={{ background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})` }}>{(name || '?').slice(0, 1).toUpperCase()}</span>
        <span className="nm">{name.split(' ')[0]}</span>
        <Ic n="chevron_down" style={{ fontSize: 14, color: MED }} />
      </button>
      {open && <div className="menu acctmenu" role="menu">
        <div className="who"><div style={{ fontWeight: 800, fontSize: 16 }}>{name}</div><div className="small">{email}</div>
          <div className="small" style={{ marginTop: 6, display: 'flex', alignItems: 'center', gap: 6 }}><Ic n="sync" style={{ fontSize: 15, color: SUCC }} />Same account as your phone</div></div>
        <button role="menuitem" onClick={() => { setOpen(false); ui.editProfile(); }}><Ic n="profile" style={{ fontSize: 20, color: MED }} />Profile</button>
        <button role="menuitem" onClick={() => { setOpen(false); onSettings(); }}><Ic n="settings" style={{ fontSize: 20, color: MED }} />Settings</button>
        <button role="menuitem" onClick={() => { setOpen(false); ui.signOut(); }}><Ic n="sign_out" style={{ fontSize: 20, color: MED }} />Sign out</button>
      </div>}
    </div>);
}
