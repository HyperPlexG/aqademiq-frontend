/* ─── AQADEMIQ WEB · CORE ────────────────────────────────────────────────
   Helpers, the saved state, the get-the-app screen and shared pieces.
   The design kit above this file supplies the tokens (ACC, WHITE, TEXT…),
   Ic (the icon pack), CubeSVG, IceTimer, MoodBlob and AdaNavFace. */

const PLAY_URL = 'https://play.google.com/store/apps/details?id=com.r13.aqademiq';
// Exactly as aqademiq.com links it; the region-free form 404s where the app isn't listed (e.g. the US).
const IOS_URL = 'https://apps.apple.com/in/app/aqademiq-study-calmly/id6792360288';

/* ── dates ── */
const pad2 = (n) => String(n).padStart(2, '0');
const dkey = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
const fromKey = (k) => { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); };
const todayKey = () => dkey(new Date());
const addDays = (k, n) => { const d = fromKey(k); d.setDate(d.getDate() + n); return dkey(d); };
const mondayOf = (k) => { const d = fromKey(k); d.setDate(d.getDate() - (d.getDay() + 6) % 7); return dkey(d); };
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const fmtTime = (t) => { if (!t) return ''; let [h, m] = t.split(':').map(Number); const ap = h < 12 ? 'AM' : 'PM'; h = h % 12 || 12; return `${h}:${pad2(m)} ${ap}`; };
const fmtDur = (m) => !m ? '' : m >= 60 ? `${Math.floor(m / 60)}h${m % 60 ? ' ' + (m % 60) + 'm' : ''}` : `${m}m`;
const shortDate = (k) => { const d = fromKey(k); return `${DAY_NAMES[d.getDay()].slice(0, 3)} ${d.getDate()} ${MONTH_NAMES[d.getMonth()].slice(0, 3)}${d.getFullYear() !== new Date().getFullYear() ? ' ' + d.getFullYear() : ''}`; };
const relDay = (k) => k === todayKey() ? 'Today' : k === addDays(todayKey(), 1) ? 'Tomorrow' : k === addDays(todayKey(), -1) ? 'Yesterday' : shortDate(k);
const relIn = (k) => { const r = relDay(k); return /^(Today|Tomorrow|Yesterday)$/.test(r) ? r.toLowerCase() : r; };
const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
const semesterNow = () => { const d = new Date(), yy = String(d.getFullYear()).slice(2); return d.getMonth() >= 6 ? `Fall '${yy}` : `Spring '${yy}`; };

/* ── tags and colours ── */
const DEFAULT_TAGS = ['Lecture', 'Class', 'Exam', 'Assignment', 'Report', 'Presentation', 'Reading'].map((n) => ({ name: n, key: AQ_TAG[n] }));
const EXTRA_TAG_ICONS = ['math', 'science', 'code', 'writing', 'languages', 'history', 'art', 'music', 'business'];
const tagInfo = (key) => {
  const t = window.AQT && window.AQT.TASKS.find((x) => x.name === key);
  const pal = window.AQT && window.AQT.PALETTE[t ? t.color : 'class'];
  return { hue: pal ? pal.hue : ACC, ink: pal ? pal.ink : ACC };
};
const SUBJECT_COLORS = ['#6b5cf0', '#5cbbff', '#e85476', '#2a9d6b', '#e8a430', '#c0497b', '#7a8699'];
const FEELINGS = ['Love it', 'Great', 'OK', 'Dread it'];

/* ── the saved state ── */
const LS_KEY = 'aq-web-v1';
const freshState = () => ({
  v: 1, updatedAt: 0,
  profile: { name: '', university: '', program: '', level: '', onboarded: false, since: todayKey() },
  settings: { theme: 'system', accent: '#6b5cf0', grouping: 'timeline', focusStyle: 'Ice melt', sort: 'added', prism: { ...DEFAULT_PRISM } },
  tags: DEFAULT_TAGS,
  semesters: [semesterNow()], semester: semesterNow(),
  subjects: [], tasks: [], sessions: [], moods: {}, chats: [], imported: [],
  focus: { status: 'idle', total: 1500, endsAt: 0, remaining: 1500, taskId: null, startedAt: 0, prism: null },
});
function normalize(s) {
  const f = freshState();
  if (!s || typeof s !== 'object' || s.v !== 1) return f;
  const settings = { ...f.settings, ...s.settings };
  settings.prism = { ...DEFAULT_PRISM, ...((s.settings && s.settings.prism) || {}) };
  const arr = (x) => Array.isArray(x) ? x : [];
  return {
    ...f, ...s, profile: { ...f.profile, ...s.profile }, settings, focus: { ...f.focus, ...s.focus },
    tags: Array.isArray(s.tags) ? s.tags : f.tags, // an empty list means you removed them all
    semesters: arr(s.semesters).length ? s.semesters : f.semesters,
    subjects: arr(s.subjects), tasks: arr(s.tasks), sessions: arr(s.sessions), chats: arr(s.chats), imported: arr(s.imported),
    moods: s.moods && typeof s.moods === 'object' ? s.moods : {},
  };
}
function loadLocal() { try { return JSON.parse(localStorage.getItem(LS_KEY) || 'null'); } catch (e) { return null; } }

/* ── private claude.ai storage ──
   Documents are capped at 256 KiB, so lists are split by size into numbered
   documents (tasks0, tasks1…) and core records how many there are. */
const CHUNK_BYTES = 180000;
const jsonLen = (x) => JSON.stringify(x).length + 1;
function chunkBy(list, max) {
  const out = []; let cur = [], size = 2;
  for (const x of list) { const n = jsonLen(x); if (cur.length && size + n > max) { out.push(cur); cur = []; size = 2; } cur.push(x); size += n; }
  if (cur.length) out.push(cur);
  return out;
}
function newestWithin(list, max) {
  let size = 2, i = list.length;
  while (i > 0) { const n = jsonLen(list[i - 1]); if (size + n > max) break; size += n; i--; }
  return list.slice(i);
}
const LISTS = ['tasks', 'sessions', 'chats'];
function toDocs(s) {
  const lists = { tasks: s.tasks, sessions: s.sessions, chats: s.chats.slice(-25).map((c) => ({ ...c, messages: c.messages.slice(-40) })) };
  const docs = {}, counts = {};
  for (const k of LISTS) { const chunks = chunkBy(lists[k], CHUNK_BYTES); counts[k] = chunks.length; chunks.forEach((c, i) => { docs[k + i] = { list: c }; }); }
  docs.core = { profile: s.profile, settings: s.settings, tags: s.tags, semesters: s.semesters, semester: s.semester, subjects: s.subjects, moods: s.moods, imported: newestWithin(s.imported, 60000), focus: s.focus, counts };
  return docs;
}
async function readDocs(db, base) {
  const core = await db.doc(base + 'core').get();
  if (!core.exists) return null;
  const c = core.data();
  const out = { ...c };
  for (const k of LISTS) {
    // Older versions of this page kept each list in one document named after it.
    const names = c.counts ? Array.from({ length: c.counts[k] || 0 }, (_, i) => k + i) : [k];
    const snaps = await Promise.all(names.map((n) => db.doc(base + n).get()));
    out[k] = snaps.flatMap((sn) => (sn.exists && Array.isArray((sn.data() || {}).list)) ? sn.data().list : []);
  }
  delete out.counts;
  const state = normalize({ ...out, v: 1, updatedAt: c.updatedAt || 0 });
  state.__legacy = !c.counts;
  return state;
}
// Keep anything made here before the saved copy arrived (matched by id).
function mergeById(remote, local) {
  const add = (a, b) => { const ids = new Set(a.map((x) => x.id)); return [...a, ...b.filter((x) => x && x.id && !ids.has(x.id))]; };
  return { ...remote, tasks: add(remote.tasks, local.tasks), sessions: add(remote.sessions, local.sessions), subjects: add(remote.subjects, local.subjects), chats: add(remote.chats, local.chats) };
}

function useAppState() {
  const [s, setS] = React.useState(() => normalize(loadLocal()));
  const [cloud, setCloud] = React.useState('local'); // local | syncing | cloud | readonly
  const mountAt = React.useRef(s.updatedAt || 0);
  const saved = React.useRef(null);
  const sync = React.useRef({ db: null, base: null, sent: {}, counts: null, busy: false, again: false, timer: 0, latest: null, fails: 0 });
  const update = React.useCallback((fn) => setS((prev) => ({ ...(typeof fn === 'function' ? fn(prev) : fn), updatedAt: Date.now() })), []);

  React.useEffect(() => {
    const json = JSON.stringify(s);
    if (json !== saved.current) { try { localStorage.setItem(LS_KEY, json); } catch (e) { /* storage blocked */ } saved.current = json; }
    sync.current.latest = s;
    schedule();
  }, [s]);

  // Another tab of this page saved: take its copy, so neither tab overwrites the other.
  React.useEffect(() => {
    const on = (e) => {
      if (e.key !== LS_KEY || !e.newValue) return;
      try { const next = normalize(JSON.parse(e.newValue)); saved.current = JSON.stringify(next); setS(next); } catch (err) { /* ignore a bad copy */ }
    };
    window.addEventListener('storage', on);
    return () => window.removeEventListener('storage', on);
  }, []);

  function schedule(ms) {
    const k = sync.current;
    if (!k.db) return;
    clearTimeout(k.timer);
    k.timer = setTimeout(flush, ms || 1200);
  }
  async function flush() {
    const k = sync.current;
    if (!k.db || !k.latest) return;
    if (k.busy) { k.again = true; return; }
    k.busy = true;
    let failed = false;
    try {
      const docs = toDocs(k.latest), stamp = k.latest.updatedAt || Date.now();
      // Lists first, core last: core says how many list documents there are.
      const names = [...Object.keys(docs).filter((n) => n !== 'core'), 'core'];
      for (const n of names) {
        const json = JSON.stringify(docs[n]);
        if (k.sent[n] === json) continue;
        try { await k.db.doc(k.base + n).set({ ...docs[n], updatedAt: stamp }); k.sent[n] = json; }
        catch (e) {
          if (e && (e.code === 'not_granted' || e.code === 'revoked')) { k.db = null; setCloud('readonly'); return; }
          failed = true; // too big, rate-limited or offline: the rest still saves, this one retries
        }
      }
      // Remove list documents left over from a longer list.
      const counts = docs.core.counts;
      if (k.counts) for (const l of LISTS) for (let i = counts[l]; i < (k.counts[l] || 0); i++) { try { await k.db.doc(k.base + l + i).delete(); delete k.sent[l + i]; } catch (e) { /* retried next time */ } }
      k.counts = counts;
      setCloud(failed ? 'local' : 'cloud');
    } finally {
      k.busy = false;
      if (k.again) { k.again = false; schedule(); }
      else if (failed && k.db) { k.fails++; schedule(Math.min(60000, 4000 * k.fails)); }
      else k.fails = 0;
    }
  }

  // Light up private claude.ai storage when this view has it; the browser copy works without it.
  React.useEffect(() => {
    let dead = false;
    (async () => {
      const c = window.claude;
      if (!c || !c.use) return;
      const [db, user] = await Promise.all([c.use('db'), c.use('user')]);
      if (dead || !db || !user) return;
      const id = await user.id();
      if (dead || !id) return;
      setCloud('syncing');
      const base = 'data/users/' + id + '/';
      try {
        const remote = await readDocs(db, base);
        if (dead) return;
        const k = sync.current;
        k.db = db; k.base = base;
        const legacy = !!(remote && remote.__legacy);
        if (remote) delete remote.__legacy;
        if (remote) {
          const local = k.latest || s;
          const remoteWins = (!local.profile.onboarded && remote.profile.onboarded) || remote.updatedAt >= mountAt.current;
          if (remoteWins) {
            const next = (local.updatedAt || 0) > mountAt.current && local.profile.onboarded ? mergeById(remote, local) : remote;
            // Only what is really stored counts as sent; an older layout is rewritten in full.
            if (!legacy) { const docs = toDocs(remote); Object.keys(docs).forEach((n) => { k.sent[n] = JSON.stringify(docs[n]); }); k.counts = docs.core.counts; }
            setS(next === remote ? { ...remote } : next);
          }
        }
        setCloud('cloud');
        schedule(300);
      } catch (e) { if (!dead) setCloud('local'); }
    })();
    return () => { dead = true; };
  }, []);

  return [s, update, cloud];
}

/* ── shared UI context ── */
const UI = React.createContext(null);
const useUI = () => React.useContext(UI);

/* ── get the app ── */
const APP_ONLY = {
  freeze: { title: 'App freeze is in the app', icon: 'freeze', body: 'Freezing distracting apps needs your phone\'s Screen Time (iPhone) or Usage access (Android), so it can\'t run in a browser. On your phone, Aqademiq freezes what pulls you away during study hours, and thawing takes a breath.' },
  notifications: { title: 'Reminders come from the app', icon: 'notifications', body: 'A website can\'t nudge you once it\'s closed. The app schedules every reminder on your phone: before a task, when it starts, morning check-ins and more.' },
  haptics: { title: 'Haptics need a phone', icon: 'haptics', body: 'The ice-crack haptics (22 patterns, quiet by default) play through your phone\'s Taptic Engine or vibration motor.' },
  ambient: { title: 'Lock screen & widgets are in the app', icon: 'cube_session', body: 'The melting-ice timer on your lock screen, Dynamic Island, home-screen widgets and Apple Watch all come with the app.' },
  phonecal: { title: 'Your phone\'s calendars', icon: 'date', body: 'Reading Google, Samsung or Outlook calendars on your phone needs the app. Here on the web you can import a calendar file (.ics).' },
  callink: { title: 'Calendar links are in the app', icon: 'link', body: 'Linking a Moodle, Canvas, Google or university calendar by URL needs the app. Here on the web, download the calendar as a .ics file and import that.' },
  reminders: { title: 'Apple Reminders are in the app', icon: 'reminder', body: 'Reading your Reminders lists needs the iPhone app. Here on the web, copy your list and use Paste a list.' },
  files: { title: 'Files & syllabus are in the app', icon: 'attach', body: 'Add slides, notes and your syllabus to a subject in the app, and Ada reads them to shape your plan.' },
  icebreakers: { title: 'Ice Breakers play in the app', icon: 'ice_breakers', body: 'Six short recordings that show the first session, start to finish. They play in the app.' },
  feedback: { title: 'Feedback lives in the app', icon: 'suggestion', body: 'Suggest features, vote on others and see what\'s shipping on the feedback board in the app.' },
  ada: { title: 'Ada needs to think', icon: 'chats', body: 'Ada thinks on your Aqademiq account. Sign in (top right) to chat with her here, with the same chats as on your phone, or use Ada in the app.' },
  get: { title: 'Get Aqademiq on your phone', icon: 'cube_frozen', body: 'App freeze, reminders, the lock-screen timer and widgets come with the app. Your plan, subjects, Prism and Ada are here too.' },
};

function QRCode_({ url }) {
  const ref = React.useRef(null);
  const [failed, setFailed] = React.useState(false);
  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.innerHTML = '';
    if (!window.QRCode) { setFailed(true); return; }
    try { new window.QRCode(el, { text: url, width: 272, height: 272, colorDark: '#111717', colorLight: '#ffffff', correctLevel: window.QRCode.CorrectLevel.M }); el.title = ''; }
    catch (e) { setFailed(true); }
  }, [url]);
  return <div className="code" aria-label={'QR code for ' + url}>{failed ? <span style={{ fontSize: 12, color: '#646464', wordBreak: 'break-all' }}>{url}</span> : <div ref={ref} />}</div>;
}

function GetApp({ kind, onClose }) {
  const c = APP_ONLY[kind] || APP_ONLY.get;
  return (
    <div className="scrim" onClick={onClose}>
      <div className="sheet wide" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={c.title}>
        <div className="sheet-head">
          <div className="row" style={{ gap: 12 }}>
            <div style={{ width: 48, height: 48, borderRadius: 16, background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic n={c.icon} style={{ fontSize: 26, color: ACC }} /></div>
            <div>
              <div className="small" style={{ fontWeight: 800, letterSpacing: '0.05em' }}>NOT AVAILABLE ON THE WEB</div>
              <h2 className="h2" style={{ marginTop: 2 }}>{c.title}</h2>
            </div>
          </div>
          <button className="iconbtn" onClick={onClose} aria-label="Close"><Ic n="close" style={{ fontSize: 22 }} /></button>
        </div>
        <p className="sub" style={{ margin: 0 }}>{c.body}</p>
        <p className="sub" style={{ margin: '10px 0 0', color: TEXT, fontWeight: 700 }}>Download the Aqademiq app: scan a code with your phone's camera.</p>
        <div className="qrs">
          <div className="qr">
            <QRCode_ url={PLAY_URL} />
            <b>Google Play</b><span>Android</span>
            <a href={PLAY_URL} target="_blank" rel="noopener noreferrer">Open Google Play →</a>
          </div>
          <div className="qr">
            <QRCode_ url={IOS_URL} />
            <b>App Store</b><span>iPhone</span>
            <a href={IOS_URL} target="_blank" rel="noopener noreferrer">Open the App Store →</a>
          </div>
        </div>
      </div>
    </div>);
}

/* ── small shared pieces ── */

// Close a menu on a tap outside it or on Escape. Put the ref on the element
// that holds both the menu and the button that opens it.
function useDismiss(open, onClose) {
  const ref = React.useRef(null);
  const close = React.useRef(onClose); close.current = onClose;
  React.useEffect(() => {
    if (!open) return;
    const down = (e) => { if (ref.current && !ref.current.contains(e.target)) close.current(); };
    const key = (e) => { if (e.key === 'Escape') close.current(); };
    document.addEventListener('pointerdown', down, true);
    document.addEventListener('keydown', key);
    return () => { document.removeEventListener('pointerdown', down, true); document.removeEventListener('keydown', key); };
  }, [open]);
  return ref;
}
// Enter/Space on a clickable non-button element (task rows are cards with a button inside).
const onKeyActivate = (fn) => (e) => { if ((e.key === 'Enter' || e.key === ' ') && e.target === e.currentTarget) { e.preventDefault(); fn(e); } };
function Sheet({ title, onClose, children, wide, foot }) {
  React.useEffect(() => {
    const on = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', on);
    return () => window.removeEventListener('keydown', on);
  }, [onClose]);
  return (
    <div className="scrim" onClick={onClose}>
      <div className={'sheet' + (wide ? ' wide' : '')} onClick={(e) => e.stopPropagation()} role="dialog" aria-label={title}>
        <div className="sheet-head">
          <h2 className="h2">{title}</h2>
          <button className="iconbtn" onClick={onClose} aria-label="Close"><Ic n="close" style={{ fontSize: 22 }} /></button>
        </div>
        {children}
        {foot}
      </div>
    </div>);
}

function Collapse({ icon, label, count, open, onClick }) {
  return (
    <div className="center">
      <button className="pill" onClick={onClick} style={{ padding: icon ? '6px 13px 6px 7px' : '7px 15px' }}>
        {icon && <Ic n={icon} style={{ fontSize: 19, color: MED }} />}
        {label} ({count})
        <Ic n={open ? 'expand_more' : 'expand_less'} style={{ fontSize: 18 }} />
      </button>
    </div>);
}

function Hold({ label, ms = 2000, onDone, className = 'btn danger block' }) {
  const [p, setP] = React.useState(0);
  const t = React.useRef(null);
  const start = () => {
    const t0 = Date.now();
    clearInterval(t.current);
    t.current = setInterval(() => {
      const v = Math.min(1, (Date.now() - t0) / ms);
      setP(v);
      if (v >= 1) { clearInterval(t.current); setP(0); onDone(); }
    }, 30);
  };
  const stop = () => { clearInterval(t.current); setP(0); };
  React.useEffect(() => () => clearInterval(t.current), []);
  return (
    <button className={className + ' hold'} onPointerDown={start} onPointerUp={stop} onPointerLeave={stop} onPointerCancel={stop}
      onKeyDown={(e) => { if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) start(); }} onKeyUp={stop}>
      <span className="fill" style={{ width: (p * 100) + '%' }} />
      <span style={{ position: 'relative' }}>{label}</span>
    </button>);
}

function MiniCal({ value, onPick, marks }) {
  const [view, setView] = React.useState(() => { const d = fromKey(value); return [d.getFullYear(), d.getMonth()]; });
  React.useEffect(() => { const d = fromKey(value); setView([d.getFullYear(), d.getMonth()]); }, [value]);
  const [y, m] = view;
  const first = (new Date(y, m, 1).getDay() + 6) % 7, total = new Date(y, m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < first; i++) cells.push(null);
  for (let d = 1; d <= total; d++) cells.push(d);
  const t = todayKey();
  const move = (n) => { const d = new Date(y, m + n, 1); setView([d.getFullYear(), d.getMonth()]); };
  return (
    <div>
      <div className="spread" style={{ marginBottom: 10 }}>
        <b style={{ fontSize: 17, fontWeight: 800 }}>{MONTH_NAMES[m]} {y}</b>
        <div className="row" style={{ gap: 0 }}>
          <button className="iconbtn" onClick={() => move(-1)} aria-label="Previous month"><Ic n="back" style={{ fontSize: 20 }} /></button>
          <button className="iconbtn" onClick={() => move(1)} aria-label="Next month"><Ic n="chevron_right" style={{ fontSize: 20 }} /></button>
        </div>
      </div>
      <div className="cal">
        {['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((w) => <div key={w} className="w">{w}</div>)}
        {cells.map((d, i) => {
          if (!d) return <span key={i} />;
          const k = `${y}-${pad2(m + 1)}-${pad2(d)}`;
          return <button key={i} className={(k === value ? 'sel ' : '') + (k === t ? 'today ' : '') + (marks && marks.has(k) ? 'has' : '')} onClick={() => onPick(k)}>{d}</button>;
        })}
      </div>
    </div>);
}

/* ── paste-a-list parsing (same rules as the app's Reminder import) ──
   A day or time on a line puts it there; anything that only looks like a
   number ("chapter 4.5", "Marketing 2 quiz") stays in the title. */
const WD = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
const MONTH_RE = '(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
function validDate(y, m, d) { const x = new Date(y, m - 1, d); return m >= 1 && m <= 12 && d >= 1 && x.getMonth() === m - 1 && x.getDate() === d ? x : null; }
function parseLine(line) {
  const now = new Date(), today0 = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let title = line.replace(/^\s*(?:(?:[-*•]|\d+[.)](?=\s)|\[[ xX]\])\s*)+/, '').trim(), date = null, time = null;
  // A date with no year that is a little in the past is overdue; long past means next year.
  const rollYear = (d) => { if (d < today0 && (today0 - d) / 864e5 > 60) d.setFullYear(d.getFullYear() + 1); return d; };

  const day = title.match(/\b(today|tonight|tomorrow|tmrw|mon(?:day)?|tue(?:s|sday)?|wed(?:nesday)?|thu(?:rs|rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b/i);
  if (day) {
    const d = day[1].toLowerCase();
    date = new Date(today0);
    if (d === 'tomorrow' || d === 'tmrw') date.setDate(date.getDate() + 1);
    else if (d !== 'today' && d !== 'tonight') { let k = (WD.indexOf(d.slice(0, 3)) - date.getDay() + 7) % 7; if (k === 0) k = 7; date.setDate(date.getDate() + k); }
    if (d === 'tonight' && !time) time = '20:00';
    title = title.replace(day[0], ' ');
  }
  // dd/mm or dd/mm/yy(yy); dd.mm only with a year, so "4.5" stays a number.
  const dm = title.match(/\b(\d{1,2})\/(\d{1,2})(?:\/(\d{2}|\d{4}))?\b|\b(\d{1,2})\.(\d{1,2})\.(\d{2}|\d{4})\b/);
  if (dm) {
    const dd = +(dm[1] || dm[4]), mm = +(dm[2] || dm[5]), yy = dm[3] || dm[6];
    const yr = yy ? (yy.length === 2 ? 2000 + +yy : +yy) : now.getFullYear();
    const v = validDate(yr, mm, dd);
    if (v) { date = yy ? v : rollYear(v); title = title.replace(dm[0], ' '); }
  }
  const mon = title.match(new RegExp(`\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+${MONTH_RE}\\b|\\b${MONTH_RE}\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b`, 'i'));
  if (mon) {
    const dd = +(mon[1] || mon[4]), mm = MONTHS.indexOf((mon[2] || mon[3]).toUpperCase().slice(0, 3)) + 1;
    const v = validDate(now.getFullYear(), mm, dd);
    if (v) { date = rollYear(v); title = title.replace(mon[0], ' '); }
  }
  // 5pm, 5:30pm, 5.30pm (hour 1–12) or 17:30.
  const tm = title.match(/\b(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)\b|\b(\d{1,2}):(\d{2})\b/i);
  if (tm) {
    let h, mi, ok;
    if (tm[3]) { h = +tm[1]; mi = +(tm[2] || 0); ok = h >= 1 && h <= 12 && mi < 60; h = h % 12 + (tm[3].toLowerCase() === 'pm' ? 12 : 0); }
    else { h = +tm[4]; mi = +tm[5]; ok = h < 24 && mi < 60; }
    if (ok) { time = `${pad2(h)}:${pad2(mi)}`; title = title.replace(tm[0], ' '); }
  }
  title = title.replace(/\s{2,}/g, ' ').trim().replace(/\s+(by|on|at|due|before)$/i, '').replace(/^[\s,–-]+|[\s,–-]+$/g, '').trim();
  const t0 = dkey(today0);
  let k = date ? dkey(date) : null, note = null;
  if (!k) { k = t0; note = 'No date · goes on today'; } else if (k < t0) { k = t0; note = 'Overdue · goes on today'; }
  return { title: title || line.trim(), date: k, time, note, explicit: !!date };
}

/* ── .ics parsing ──
   Ignores what sits inside alarms, honours EXDATE, and expands DAILY/WEEKLY
   repeats (INTERVAL, BYDAY, UNTIL, COUNT) inside the window. Weeks start on
   Monday and days are counted on the calendar, so DST never shifts a class. */
function parseICS(text, horizonDays) {
  const lines = text.replace(/\r\n[ \t]/g, '').replace(/\n[ \t]/g, '').split(/\r?\n/);
  const events = [];
  let cur = null, depth = 0;
  for (const raw of lines) {
    const line = raw.trim();
    if (line === 'BEGIN:VEVENT') { cur = {}; depth = 0; continue; }
    if (!cur) continue;
    if (line === 'END:VEVENT') { events.push(cur); cur = null; continue; }
    if (line.startsWith('BEGIN:')) { depth++; continue; }
    if (line.startsWith('END:')) { depth = Math.max(0, depth - 1); continue; }
    if (depth > 0) continue; // inside VALARM and friends
    const i = line.indexOf(':');
    if (i < 0) continue;
    const head = line.slice(0, i), val = line.slice(i + 1), name = head.split(';')[0].toUpperCase();
    if (name === 'EXDATE') { (cur.EX = cur.EX || []).push(...val.split(',')); continue; }
    if (!(name in cur)) cur[name] = { head, val };
  }
  const parseDT = (p) => {
    if (!p) return null;
    const m = String(p.val).trim().match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?/);
    if (!m) return null;
    if (!m[4]) return { date: new Date(+m[1], +m[2] - 1, +m[3]), allDay: true };
    const d = m[7] ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5])) : new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]);
    return { date: d, allDay: false };
  };
  const unesc = (s) => (s || '').replace(/\\n/gi, ' ').replace(/\\([,;\\])/g, '$1').trim();
  const dn = (x) => Math.round(Date.UTC(x.getFullYear(), x.getMonth(), x.getDate()) / 864e5);
  const now = new Date(), start0 = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end0 = new Date(start0); end0.setDate(end0.getDate() + horizonDays);
  const startN = dn(start0), endN = dn(end0);
  const seen = new Set(), out = [];
  for (const e of events) {
    const st = parseDT(e.DTSTART);
    if (!st || !e.SUMMARY) continue;
    if (e.STATUS && /CANCELLED/i.test(e.STATUS.val)) continue;
    const en = parseDT(e.DTEND);
    let dur = en && !st.allDay ? Math.round((en.date - st.date) / 60000) : 0;
    if (!dur && e.DURATION) { const dm = e.DURATION.val.match(/PT(?:(\d+)H)?(?:(\d+)M)?/); if (dm) dur = (+(dm[1] || 0)) * 60 + (+(dm[2] || 0)); }
    const ex = new Set((e.EX || []).map((v) => { const x = parseDT({ val: v }); return x ? dkey(x.date) : null; }).filter(Boolean));
    let occ = [st.date];
    if (e.RRULE) {
      const r = Object.fromEntries(e.RRULE.val.split(';').map((x) => x.split('=')));
      const step = Math.max(1, +(r.INTERVAL || 1)), count = r.COUNT ? +r.COUNT : Infinity;
      const until = r.UNTIL ? (parseDT({ val: r.UNTIL }) || {}).date : null;
      const byday = r.BYDAY ? r.BYDAY.split(',').map((x) => ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'].indexOf(x.slice(-2))).filter((x) => x >= 0) : null;
      if (r.FREQ === 'DAILY' || r.FREQ === 'WEEKLY') {
        occ = [];
        const s0 = dn(st.date), wk0 = s0 - (st.date.getDay() + 6) % 7;
        let n = 0;
        for (let d = new Date(st.date); n < count; d.setDate(d.getDate() + 1)) {
          const di = dn(d);
          if (di > endN || (until && d > until)) break;
          const ok = r.FREQ === 'DAILY' ? (di - s0) % step === 0 : (Math.floor((di - wk0) / 7) % step === 0 && (byday && byday.length ? byday.includes(d.getDay()) : d.getDay() === st.date.getDay()));
          if (ok) { occ.push(new Date(d)); n++; }
        }
      }
    }
    for (const o of occ) {
      const oi = dn(o);
      if (oi < startN || oi >= endN) continue;
      const k = dkey(o);
      if (ex.has(k)) continue;
      const key = 'ics:' + unesc(e.UID ? e.UID.val : e.SUMMARY.val) + ':' + k;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({ key, title: unesc(e.SUMMARY.val), date: k, time: st.allDay ? null : `${pad2(o.getHours())}:${pad2(o.getMinutes())}`, dur: dur > 0 && dur <= 600 ? dur : 0, note: st.allDay ? 'All day' : null });
    }
  }
  return out.sort((a, b) => (a.date + (a.time || '')).localeCompare(b.date + (b.time || '')));
}
