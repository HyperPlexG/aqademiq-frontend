/* ─── YOUR WEEK ───────────────────────────────────────────────────────── */

function WeekPage({ s, update }) {
  const ui = useUI();
  const [off, setOff] = React.useState(0);
  const mon = addDays(mondayOf(todayKey()), off * 7);
  React.useEffect(() => { ui.ensureWeek && ui.ensureWeek(mon); }, [mon]);
  const days = Array.from({ length: 7 }, (_, i) => addDays(mon, i));
  const sun = days[6];
  const inWeek = (k) => k >= mon && k <= sun;
  const sessions = s.sessions.filter((x) => inWeek(x.date));
  const focusBy = days.map((k) => sessions.filter((x) => x.date === k).reduce((a, x) => a + x.minutes, 0));
  const done = s.tasks.filter((t) => t.done && inWeek(t.doneOn || t.date));
  const onBoard = days.filter((k, i) => focusBy[i] > 0 || done.some((t) => (t.doneOn || t.date) === k)).length;
  const max = Math.max(30, ...focusBy);
  const bySub = {};
  sessions.forEach((x) => { if (x.subjectId && x.minutes > 0) bySub[x.subjectId] = (bySub[x.subjectId] || 0) + x.minutes; });
  const topId = Object.keys(bySub).sort((a, b) => bySub[b] - bySub[a])[0];
  const top = topId && s.subjects.find((x) => x.id === topId);
  const a = fromKey(mon), b = fromKey(sun);
  return (
    <div className="wrap two">
      <div>
        <div className="spread">
          <div>
            <div className="small" style={{ fontWeight: 800, letterSpacing: '0.06em' }}>YOUR WEEK · THE CORE</div>
            <h1 className="h1" style={{ marginTop: 4 }}>{MONTH_NAMES[a.getMonth()].slice(0, 3)} {a.getDate()} – {a.getMonth() !== b.getMonth() ? MONTH_NAMES[b.getMonth()].slice(0, 3) + ' ' : ''}{b.getDate()}</h1>
          </div>
          <div className="cluster">
            <button className="iconbtn" onClick={() => setOff(off - 1)} aria-label="Previous week"><Ic n="back" style={{ fontSize: 22 }} /></button>
            <button className="iconbtn" disabled={off >= 0} style={{ opacity: off >= 0 ? 0.3 : 1 }} onClick={() => off < 0 && setOff(off + 1)} aria-label="Next week"><Ic n="chevron_right" style={{ fontSize: 22 }} /></button>
          </div>
        </div>
        <div className="sub" style={{ marginTop: 6 }}>A record, not a score. No streak to lose.</div>
        <div className="stats" style={{ marginTop: 18 }}>
          <div className="card pad stat"><b>{onBoard}</b><span>Days on the board</span></div>
          <div className="card pad stat"><b>{done.length}</b><span>Tasks done</span></div>
          <div className="card pad stat"><b>{fmtDur(focusBy.reduce((x, y) => x + y, 0)) || '0m'}</b><span>Focused</span></div>
        </div>
        <div className="label">The shape of the week</div>
        <div className="card pad">
          <div className="shape">
            {days.map((k, i) =>
            <div key={k}>
                {focusBy[i] > 0 && <span className="small" style={{ fontWeight: 800 }}>{fmtDur(focusBy[i])}</span>}
                <i className={focusBy[i] ? '' : 'zero'} style={{ height: focusBy[i] ? Math.max(14, focusBy[i] / max * 110) : 12, opacity: k > todayKey() ? 0.35 : 1 }} />
                <small style={{ color: k === todayKey() ? ACC : MED }}>{'MTWTFSS'[i]}</small>
              </div>)}
          </div>
        </div>
        <div className="label">Mood & daily reflections</div>
        <div className="card pad">
          <div className="row" style={{ justifyContent: 'space-between' }}>
            {days.map((k, i) =>
            <div key={k} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, flex: 1 }}>
                {s.moods[k] != null ? <MoodBlob idx={s.moods[k]} size={38} /> : <div style={{ width: 34, height: 34, borderRadius: 10, border: `1.5px dashed ${HILITE}` }} />}
                <small style={{ fontSize: 13, fontWeight: 800, color: k === todayKey() ? ACC : MED }}>{'MTWTFSS'[i]}</small>
              </div>)}
          </div>
          {off === 0 && <button className="btn sm ghost block" style={{ marginTop: 14 }} onClick={ui.logMood}>{s.moods[todayKey()] != null ? 'Change today\'s mood' : 'Log today\'s mood'}</button>}
        </div>
        {top && <><div className="label">One thing that happened</div>
          <div className="card pad"><div style={{ fontSize: 17, fontWeight: 800 }}>Most of your focus went to {top.code || top.name}.</div><div className="small" style={{ marginTop: 4 }}>{fmtDur(bySub[topId])} across {sessions.filter((x) => x.subjectId === topId && x.minutes > 0).length} {sessions.filter((x) => x.subjectId === topId && x.minutes > 0).length === 1 ? "session" : "sessions"}.</div></div></>}
      </div>
      <aside className="rail">
        <div className="card pad" style={{ textAlign: 'center' }}>
          <CubeSVG size={74} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
          <div style={{ fontSize: 20, fontWeight: 800, marginTop: 8 }}>Keep it frozen{s.profile.name ? ', ' + s.profile.name : ''}</div>
          <div className="small" style={{ marginTop: 4 }}>On the board since {shortDate(s.profile.since)}.</div>
        </div>
        <div className="group">
          <button className="srow" onClick={() => ui.app('icebreakers')}><Ic n="ice_breakers" style={{ fontSize: 22, color: ACC }} /><span>Ice Breakers<span className="d">Six short first-session videos</span></span><span className="v"><span className="badge">APP</span></span></button>
          <button className="srow" onClick={() => ui.app('feedback')}><Ic n="suggestion" style={{ fontSize: 22, color: ACC }} /><span>Share feedback</span><span className="v"><span className="badge">APP</span></span></button>
          <button className="srow" onClick={() => ui.go('preferences')}><Ic n="settings" style={{ fontSize: 22, color: ACC }} /><span>Settings</span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></button>
        </div>
      </aside>
    </div>);
}

/* ─── IMPORT (Calendar file, Paste a list) ────────────────────────────── */

function ImportReview({ s, items, sourceLabel, onAdd, onBack }) {
  // Already imported: remembered keys, plus the key each imported task carries (so the list's size cap never lets one back in).
  const ui = useUI();
  const [serverHave, setServerHave] = React.useState(null);
  // Signed in, ask the account which are already imported (from the phone or here).
  React.useEffect(() => {
    let dead = false;
    if (ui.importCheck && items.length) ui.importCheck(items, sourceLabel.startsWith('Pasted') ? 'Reminders' : 'Calendar').then((h) => { if (!dead) setServerHave(h); }).catch(() => {});
    return () => { dead = true; };
  }, [items]);
  const have = React.useMemo(() => new Set([...s.imported, ...s.tasks.map((t) => t.importKey).filter(Boolean), ...(serverHave || [])]), [s.imported, s.tasks, serverHave]);
  const fresh = items.filter((x) => !have.has(x.key));
  const already = items.length - fresh.length;
  const [off, setOff] = React.useState({});
  const [tag, setTag] = React.useState(null);
  const n = fresh.filter((x) => !off[x.key]).length;
  return (
    <div>
      <div className="small" style={{ marginTop: -8, marginBottom: 12 }}>{sourceLabel}{already ? ` · ${already} already in your plan` : ''}</div>
      <div className="field"><span>Add as</span>
        <div className="chips">
          <button className={'chip' + (!tag ? ' on' : '')} onClick={() => setTag(null)}>No tag</button>
          {s.tags.map((t) => <button key={t.name} className={'chip' + (tag === t.name ? ' on' : '')} onClick={() => setTag(t.name)}><Ic n={'task_' + t.key} style={{ fontSize: 16, color: tagInfo(t.key).hue }} />{t.name}</button>)}
        </div>
      </div>
      <div className="spread"><span className="label" style={{ margin: '6px 4px 8px' }}>Pick what to add</span>
        <span className="row" style={{ gap: 12 }}><button className="link" onClick={() => setOff({})}>Select all</button><button className="link" onClick={() => setOff(Object.fromEntries(fresh.map((x) => [x.key, true])))}>Clear</button></span></div>
      <div className="group" style={{ boxShadow: 'none', background: BG, maxHeight: 340, overflow: 'auto', marginBottom: 14 }}>
        {fresh.length === 0 && <div className="pad small">Nothing new to add.</div>}
        {fresh.map((x) =>
        <button key={x.key} className="srow" onClick={() => setOff({ ...off, [x.key]: !off[x.key] })} style={{ opacity: off[x.key] ? 0.5 : 1 }}>
            <Ic n={off[x.key] ? 'radio_button_unchecked' : 'check_circle'} fill={!off[x.key]} style={{ fontSize: 22, color: off[x.key] ? DIM : ACC }} />
            <span style={{ minWidth: 0 }}>{x.title}<span className="d">{/^(No date|Overdue)/.test(x.note || '') ? x.note + (x.time ? ' · ' + fmtTime(x.time) : '') : `${relDay(x.date)} · ${x.time ? fmtTime(x.time) : x.note || 'Any time'}`}</span></span>
          </button>)}
      </div>
      <div className="row">
        <button className="btn ghost" onClick={onBack}>Back</button>
        <button className="btn" style={{ flex: 1 }} disabled={!n} onClick={() => onAdd(fresh.filter((x) => !off[x.key]), tag)}>{n ? `Add ${n} to my plan` : 'Pick what to add'}</button>
      </div>
    </div>);
}

function ImportSheet({ s, kind, onClose, onAdd }) {
  const ui = useUI();
  const [step, setStep] = React.useState('pick');
  const [items, setItems] = React.useState([]);
  const [label, setLabel] = React.useState('');
  const [paste, setPaste] = React.useState('');
  const [ahead, setAhead] = React.useState(30);
  const [icsText, setIcsText] = React.useState(null);
  const [err, setErr] = React.useState('');
  const fileRef = React.useRef(null);
  const cal = kind === 'calendar';

  const readFile = (file) => {
    if (!file) return;
    const r = new FileReader();
    r.onload = () => {
      const txt = String(r.result || '');
      if (!/BEGIN:VCALENDAR/.test(txt)) { setErr('That file doesn\'t look like a calendar (.ics).'); return; }
      setErr(''); setIcsText(txt); setLabel(file.name);
      const list = parseICS(txt, ahead);
      setItems(list); setStep('review');
    };
    r.readAsText(file);
  };
  React.useEffect(() => { if (icsText) setItems(parseICS(icsText, ahead)); }, [ahead]);

  const previewPaste = () => {
    const lines = paste.split('\n').map((l) => l.trim()).filter(Boolean).slice(0, 200);
    setItems(lines.map((l) => { const p = parseLine(l); return { ...p, key: 'paste:' + p.title.toLowerCase() + ':' + p.date, dur: 30 }; }));
    setLabel(`Pasted list · ${lines.length} ${lines.length === 1 ? 'line' : 'lines'}`);
    setStep('review');
  };

  return (
    <Sheet title={step === 'review' ? 'Import' : step === 'paste' ? 'Paste a list' : cal ? 'Calendar import' : 'Reminder import'} onClose={onClose} wide={step === 'review'}>
      {step === 'pick' && <>
        {!cal && <div className="sub" style={{ marginTop: -8, marginBottom: 14 }}>Turn your reminders into tasks, so they sit in your plan with everything else.</div>}
        <div className="label" style={{ marginTop: 0 }}>Import from</div>
        <div className="group" style={{ boxShadow: 'none', background: BG, marginBottom: 12 }}>
          {cal ? <>
            <button className="srow" onClick={() => fileRef.current && fileRef.current.click()}><Ic n="file" style={{ fontSize: 22, color: ACC }} /><span>Calendar file (.ics)<span className="d">A timetable or invite you saved or were sent</span></span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></button>
            <button className="srow" onClick={() => ui.app('callink')}><Ic n="link" style={{ fontSize: 22, color: ACC }} /><span>Calendar link<span className="d">An iCal link from Moodle, Canvas, Google, Outlook or your university</span></span><span className="v"><span className="badge">APP</span></span></button>
            <button className="srow" onClick={() => ui.app('phonecal')}><Ic n="date" style={{ fontSize: 22, color: ACC }} /><span>This phone's calendars<span className="d">Google, Samsung, Outlook — every calendar on your phone</span></span><span className="v"><span className="badge">APP</span></span></button>
          </> : <>
            <button className="srow" onClick={() => setStep('paste')}><Ic n="note" style={{ fontSize: 22, color: ACC }} /><span>Paste a list<span className="d">Copied from Samsung Reminder, Google Keep, Todoist, Notes or anywhere else</span></span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></button>
            <button className="srow" onClick={() => ui.app('reminders')}><Ic n="reminder" style={{ fontSize: 22, color: ACC }} /><span>Apple Reminders<span className="d">Your open reminders, including iCloud lists</span></span><span className="v"><span className="badge">APP</span></span></button>
          </>}
        </div>
        {cal && <div className="field"><span>How far ahead</span><div className="chips">{[[14, '2 weeks'], [30, 'A month'], [120, 'The semester']].map(([d, l]) => <button key={d} className={'chip' + (ahead === d ? ' on' : '')} onClick={() => setAhead(d)}>{l}</button>)}</div></div>}
        {err && <div className="small" style={{ color: '#e85476', marginBottom: 8 }}>{err}</div>}
        <div className="small">{cal ? 'Nothing changes in your calendar. Importing the same calendar again only adds what\'s new.' : 'Undated and overdue reminders go on today. Nothing changes in your reminders app.'}</div>
        <input ref={fileRef} type="file" accept=".ics,text/calendar" style={{ display: 'none' }} onChange={(e) => { readFile(e.target.files && e.target.files[0]); e.target.value = ''; }} />
      </>}
      {step === 'paste' && <>
        <div className="sub" style={{ marginTop: -8, marginBottom: 12 }}>One reminder per line. Add a day or time and it lands there — “Essay draft fri”, “Lab report 30/11 5pm”, “Pay fees by Nov 3”. Lines without one go on today.</div>
        <textarea className="area" autoFocus style={{ minHeight: 200 }} value={paste} onChange={(e) => setPaste(e.target.value)} placeholder={'Essay draft fri\nLab report 30/11 5pm\nReturn library books'} />
        <div className="row" style={{ marginTop: 14 }}>
          <button className="btn ghost" onClick={() => setStep('pick')}>Back</button>
          <button className="btn" style={{ flex: 1 }} disabled={!paste.trim()} onClick={previewPaste}>Preview</button>
        </div>
      </>}
      {step === 'review' && <>
        {cal && <div className="field"><span>How far ahead</span><div className="chips">{[[14, '2 weeks'], [30, 'A month'], [120, 'The semester']].map(([d, l]) => <button key={d} className={'chip' + (ahead === d ? ' on' : '')} onClick={() => setAhead(d)}>{l}</button>)}</div></div>}
        <ImportReview s={s} items={items} sourceLabel={label} onBack={() => setStep(cal ? 'pick' : 'paste')} onAdd={(list, tag) => onAdd(list, tag, cal ? 'Calendar' : 'Reminders')} />
      </>}
    </Sheet>);
}

/* ─── SETTINGS ────────────────────────────────────────────────────────── */

/* Settings → Prism (settings_sounds_screen.dart): play in Focus, default mode, three levels. */
function PrismSettings({ s, update }) {
  const ui = useUI();
  const pz = s.settings.prism;
  const [pst, plabel] = usePrismState();
  const inSession = s.focus.status === 'running' || s.focus.status === 'frozen';
  const previewing = prismWant.preview && (pst === 'playing' || pst === 'loading');
  const setP = (patch) => update((st) => ({ ...st, settings: { ...st.settings, prism: { ...st.settings.prism, ...patch } } }));
  const sRef = React.useRef(s); sRef.current = s;
  React.useEffect(() => { PRISM.prefetch(pz.mode === PRISM_OFF ? 'Deep Work' : pz.mode); }, [pz.mode]);
  // Leaving Settings ends a preview, never a session's sound.
  React.useEffect(() => () => {
    const fs = sRef.current.focus.status;
    if (prismWant.preview && fs !== 'running' && fs !== 'frozen') { prismWant.preview = false; PRISM.stop(); }
  }, []);
  const preview = () => {
    if (previewing) { prismWant.preview = false; PRISM.stop(); return; }
    if (!PRISM.unlock()) { ui.toast(PRISM.error || 'This browser can\'t play Prism.'); return; }
    prismWant.preview = true;
    PRISM.start(pz.mode === PRISM_OFF ? 'Deep Work' : pz.mode);
  };
  const pickDefault = (m) => {
    setP({ mode: m });
    if (previewing) { if (m === PRISM_OFF) { prismWant.preview = false; PRISM.stop(); } else PRISM.switchMode(m); }
  };
  // A plain function, not a component: a component defined in render would remount the slider mid-drag.
  const slider = (k, label, sub) =>
  <div key={k} className="srow" style={{ cursor: 'default' }}>
      <Ic n={k === 'master' ? 'volume' : k === 'env' ? 'state_relax' : 'streak'} style={{ fontSize: 22, color: ACC }} />
      <span style={{ minWidth: 120 }}>{label}{sub && <span className="d">{sub}</span>}</span>
      <input type="range" className="range" min="0" max="100" value={Math.round(pz[k] * 100)} aria-label={label + ' volume'}
    onChange={(e) => setP({ [k]: +e.target.value / 100 })} style={{ '--p': Math.round(pz[k] * 100) + '%' }} />
      <span className="small" style={{ width: 38, textAlign: 'right', fontWeight: 700 }}>{Math.round(pz[k] * 100)}</span>
    </div>;
  return (
    <>
      <div className="label">Prism</div>
      <div className="small" style={{ margin: '-2px 4px 10px' }}>Focus soundscapes tuned to the kind of work you're doing.</div>
      <div className="group">
        <label className="srow" style={{ cursor: 'pointer' }}><Ic n="prism" style={{ fontSize: 22, color: ACC }} /><span>Play Prism in Focus<span className="d">Starts with every session. You can still pick a mode on the Focus page.</span></span><span className="v"><input type="checkbox" className="switch" checked={pz.autoplay} onChange={(e) => setP({ autoplay: e.target.checked })} /></span></label>
        <div className="srow" style={{ cursor: 'default', flexWrap: 'wrap' }}>
          <Ic n="graphic_eq" style={{ fontSize: 22, color: ACC }} /><span>Default mode</span>
          <div className="chips" style={{ width: '100%', paddingLeft: 34, marginTop: 4 }}>
            {[...PRISM_MODES.map((m) => m.label), PRISM_OFF].map((m) =>
            <button key={m} className={'chip' + (pz.mode === m ? ' on' : '')} onClick={() => pickDefault(m)}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: prismColor(m) }} />{m}
              </button>)}
          </div>
          {pz.mode !== PRISM_OFF && <div className="small" style={{ paddingLeft: 34, marginTop: 8 }}>{(PRISM_MODES.find((m) => m.label === pz.mode) || {}).desc}</div>}
        </div>
        {slider('master', 'Master')}
        {slider('env', 'Environment', 'Rain, sea, ambience')}
        {slider('rhythm', 'Rhythm', 'Pulse beats')}
      </div>
      <div className="row" style={{ marginTop: 10, gap: 10, flexWrap: 'wrap' }}>
        <button className="btn sm ghost" onClick={preview} disabled={inSession}>
          <Ic n={previewing ? 'end' : 'play'} style={{ fontSize: 16, color: ACC }} />{previewing ? 'Stop preview' : `Preview ${pz.mode === PRISM_OFF ? 'Deep Work' : pz.mode}`}
        </button>
        <span className="small">{inSession ? `A focus session is running${pst === 'playing' ? ` with ${plabel}` : ''}. Changes apply to it live.` : pst === 'loading' && prismWant.preview ? 'Loading Prism…' : pst === 'error' ? PRISM.error : 'Use headphones for the full stereo field.'}</span>
      </div>
    </>);
}

function SettingsPage({ s, update, cloud }) {
  const ui = useUI();
  const setSet = (k, v) => update((st) => ({ ...st, settings: { ...st.settings, [k]: v } }));
  const [newTag, setNewTag] = React.useState(null);
  const Row = ({ icon, label, value, onClick, app, desc }) =>
  <button className="srow" onClick={onClick}><Ic n={icon} style={{ fontSize: 22, color: ACC }} /><span>{label}{desc && <span className="d">{desc}</span>}</span><span className="v">{value}{app && <span className="badge">APP</span>}<Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></button>;
  return (
    <div className="wrap" style={{ maxWidth: 760 }}>
      <h1 className="h1">Settings</h1>
      <button className="card pad row" style={{ width: '100%', border: 0, textAlign: 'left', marginTop: 18, color: TEXT, gap: 13 }} onClick={ui.editProfile}>
        <div style={{ width: 46, height: 46, borderRadius: '50%', background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 800, fontSize: 19 }}>{(s.profile.name || '?').slice(0, 1).toUpperCase()}</div>
        <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 17, fontWeight: 800 }}>{s.profile.name || 'Add your name'}</div><div className="small">{[s.profile.university, s.profile.program].filter(Boolean).join(' · ') || 'University and program'}</div></div>
        <Ic n="chevron_right" style={{ fontSize: 20, color: DIM }} />
      </button>

      <div className="label">Study tags</div>
      <div className="card pad">
        <div className="chips">
          {s.tags.map((t) =>
          <span key={t.name} className="chip" style={{ color: TEXT, fontWeight: 700 }}>
              <Ic n={'task_' + t.key} style={{ fontSize: 18, color: IS_DARK ? tagInfo(t.key).hue : tagInfo(t.key).ink }} />{t.name}
              <button onClick={() => update((st) => ({ ...st, tags: st.tags.filter((x) => x.name !== t.name) }))} style={{ border: 0, background: 'none', padding: 0, display: 'flex' }} aria-label={'Remove ' + t.name}><Ic n="close" style={{ fontSize: 16, color: DIM }} /></button>
            </span>)}
          <button className="chip" style={{ borderStyle: 'dashed', borderColor: ACC + '88', color: ACC, fontWeight: 700 }} onClick={() => setNewTag({ name: '', key: 'math' })}><Ic n="add" style={{ fontSize: 18 }} />New tag</button>
        </div>
      </div>
      <div className="small" style={{ margin: '7px 4px 0' }}>Ada uses your tags to read your workload and shape your plan.</div>

      <div className="label">Preferences</div>
      <div className="group">
        <div className="srow"><Ic n="auto_mode" style={{ fontSize: 22, color: ACC }} /><span>Appearance</span><span className="v"><span className="seg">{[['system', 'System'], ['light', 'Light'], ['dark', 'Dark']].map(([k, l]) => <button key={k} className={s.settings.theme === k ? 'on' : ''} onClick={() => setSet('theme', k)}>{l}</button>)}</span></span></div>
        <div className="srow"><Ic n="adjust" style={{ fontSize: 22, color: ACC }} /><span>Accent</span><span className="v">{['#6b5cf0', '#e85476', '#2a9d6b'].map((c) => <button key={c} className={'swatch' + (s.settings.accent === c ? ' on' : '')} style={{ background: c }} onClick={() => setSet('accent', c)} aria-label={'Accent ' + c} />)}</span></div>
        <div className="srow"><Ic n="focus" style={{ fontSize: 22, color: ACC }} /><span>Focus timer</span><span className="v"><span className="seg">{['Ice melt', 'Glass fill'].map((k) => <button key={k} className={s.settings.focusStyle === k ? 'on' : ''} onClick={() => setSet('focusStyle', k)}>{k}</button>)}</span></span></div>
        <Row icon="notifications" label="Notifications" app onClick={() => ui.app('notifications')} />
        <Row icon="haptics" label="Haptics" app onClick={() => ui.app('haptics')} />
        <Row icon="freeze" label="App freeze" app onClick={() => ui.app('freeze')} />
        <Row icon="date" label="Calendar import" desc="Import a calendar file (.ics)" onClick={() => ui.importer('calendar')} />
        <Row icon="list_view" label="Reminder import" desc="Paste a list from any reminders app" onClick={() => ui.importer('reminders')} />
      </div>

      <PrismSettings s={s} update={update} />

      <div className="label">Account</div>
      {ui.signedIn ? <>
        <div className="group">
          <div className="srow"><Ic n="sync" style={{ fontSize: 22, color: SUCC }} /><span>Signed in as {s.profile.email}<span className="d">The same account as on your phone: your plan, subjects, focus and Ada are shared both ways.</span></span></div>
          <Row icon="profile" label="Profile" onClick={ui.editProfile} />
          <Row icon="sign_out" label="Sign out" onClick={ui.signOut} />
          <Row icon="cube_session" label="Lock screen, widgets & Watch" app onClick={() => ui.app('ambient')} />
        </div>
        <div className="card pad" style={{ marginTop: 12 }}>
          <div style={{ fontSize: 17, fontWeight: 800 }}>Delete account</div>
          <div className="small" style={{ margin: '4px 0 12px' }}>Permanently removes your Aqademiq account and everything in it, on the web and on your phone. There is no undo.</div>
          <Hold label="Hold to delete" ms={2000} onDone={ui.deleteAccount} />
        </div>
      </> : <>
        <div className="group">
          <button className="srow" onClick={() => ui.openAuth('signin')}><Ic n="profile" style={{ fontSize: 22, color: ACC }} /><span>Sign in or create an account<span className="d">The same account as on your phone, so your plan is on both.</span></span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></button>
          <div className="srow"><Ic n="sync" style={{ fontSize: 22, color: ACC }} /><span>Where this guest plan is saved<span className="d">{cloud === 'cloud' ? 'Privately with your claude.ai account, so it follows you to any browser where you open this page.' : cloud === 'syncing' ? 'Connecting to your claude.ai account…' : cloud === 'readonly' ? 'In this browser only: this view can\'t save to your account.' : 'In this browser only. Sign in to keep it in your Aqademiq account.'}</span></span></div>
          <Row icon="cube_session" label="Lock screen, widgets & Watch" app onClick={() => ui.app('ambient')} />
        </div>
        <div className="card pad" style={{ marginTop: 12 }}>
          <div style={{ fontSize: 17, fontWeight: 800 }}>Start over</div>
          <div className="small" style={{ margin: '4px 0 12px' }}>Removes this guest plan's tasks, subjects, sessions and chats. There is no undo.</div>
          <Hold label="Hold to delete everything" ms={2000} onDone={() => { update(() => freshState()); ui.toast('Everything was deleted'); }} />
        </div>
      </>}

      <div className="label">About</div>
      <div className="group">
        <a className="srow" href="https://aqademiq.app/" target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}><Ic n="language" style={{ fontSize: 22, color: ACC }} /><span>Aqademiq on the web<span className="d">aqademiq.app</span></span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></a>
        <a className="srow" href="https://www.aqademiq.com/faq" target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}><Ic n="help" style={{ fontSize: 22, color: ACC }} /><span>FAQ</span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></a>
        <a className="srow" href="https://www.aqademiq.com/privacy-policy" target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}><Ic n="description" style={{ fontSize: 22, color: ACC }} /><span>Privacy Policy</span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></a>
        <a className="srow" href="https://www.aqademiq.com/terms-of-use" target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}><Ic n="note" style={{ fontSize: 22, color: ACC }} /><span>Terms of use</span><span className="v"><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span></a>
      </div>

      {newTag && <Sheet title="New tag" onClose={() => setNewTag(null)}>
        <div className="field"><input className="input" autoFocus placeholder="Tag name, e.g. Lab" value={newTag.name} onChange={(e) => setNewTag({ ...newTag, name: e.target.value })} /></div>
        <div className="field"><span>Icon</span><div className="chips">{EXTRA_TAG_ICONS.concat(Object.values(AQ_TAG)).map((k) => <button key={k} className={'chip' + (newTag.key === k ? ' on' : '')} style={{ padding: '0 10px' }} onClick={() => setNewTag({ ...newTag, key: k })} aria-label={k}><Ic n={'task_' + k} style={{ fontSize: 20, color: tagInfo(k).hue }} /></button>)}</div></div>
        <button className="btn block" disabled={!newTag.name.trim() || s.tags.some((t) => t.name.toLowerCase() === newTag.name.trim().toLowerCase())} onClick={() => { update((st) => ({ ...st, tags: [...st.tags, { name: newTag.name.trim(), key: newTag.key }] })); setNewTag(null); }}>Add tag</button>
      </Sheet>}
    </div>);
}

function ProfileSheet({ s, onSave, onClose }) {
  const [p, setP] = React.useState({ ...s.profile });
  return (
    <Sheet title="Profile" onClose={onClose} foot={<button className="btn block" onClick={() => onSave(p)}>Save</button>}>
      <div className="field"><span>Name</span><input className="input" autoFocus value={p.name} onChange={(e) => setP({ ...p, name: e.target.value })} /></div>
      <div className="field"><span>University</span><input className="input" placeholder="BITS Pilani Dubai" value={p.university} onChange={(e) => setP({ ...p, university: e.target.value })} /></div>
      <div className="field"><span>Program</span><input className="input" placeholder="CS · Undergrad" value={p.program} onChange={(e) => setP({ ...p, program: e.target.value })} /></div>
    </Sheet>);
}

/* ─── ONBOARDING ──────────────────────────────────────────────────────── */

function Onboarding({ s, update, onSignIn }) {
  const [step, setStep] = React.useState(0);
  const [name, setName] = React.useState(s.profile.name || '');
  const [level, setLevel] = React.useState('Undergraduate');
  const [subs, setSubs] = React.useState([]);
  const [code, setCode] = React.useState('');
  const [sname, setSname] = React.useState('');
  const addSub = () => { if (!sname.trim()) return; setSubs([...subs, { code: code.trim(), name: sname.trim() }]); setCode(''); setSname(''); };
  const [mode, setMode] = React.useState(s.settings.prism.mode === PRISM_OFF ? 'Deep Work' : s.settings.prism.mode);
  const [hearing, setHearing] = React.useState(null);
  const [pst] = usePrismState();
  const audible = pst === "playing" || pst === "loading";
  React.useEffect(() => { if (step === 3) PRISM.prefetch(mode); }, [step]);
  React.useEffect(() => () => { if (prismWant.preview) { prismWant.preview = false; PRISM.stop(); } }, []);
  const hear = (m) => {
    setMode(m);
    if (hearing === m && audible) { setHearing(null); prismWant.preview = false; PRISM.stop(); return; }
    if (!PRISM.unlock()) return;
    prismWant.preview = true; setHearing(m);
    if (PRISM.state === 'playing' || PRISM.state === 'loading') PRISM.switchMode(m); else PRISM.start(m);
  };
  const finish = () => {
    const extra = sname.trim() ? [{ code: code.trim(), name: sname.trim() }] : [];
    if (prismWant.preview) { prismWant.preview = false; PRISM.stop(); }
    update((st) => ({
      ...st,
      settings: { ...st.settings, prism: { ...st.settings.prism, mode } },
      profile: { ...st.profile, name: name.trim(), level, program: level, onboarded: true, since: todayKey() },
      subjects: [...st.subjects, ...[...subs, ...extra].map((x, i) => ({ id: uid(), code: x.code, name: x.name, credits: 3, color: SUBJECT_COLORS[(st.subjects.length + i) % SUBJECT_COLORS.length], targetType: 'Grade', target: 'A', prof: '', feeling: 'OK', semester: st.semester }))],
    }));
  };
  const dots = <div className="dots" aria-label={`Step ${step} of 3`}>{[1, 2, 3].map((i) => <i key={i} className={step === i ? 'on' : ''} />)}</div>;
  return (
    <div className="ob">
      <div className="ob-card">
        {step === 0 && <div style={{ textAlign: 'center' }}>
          <img src={window.__resources.logo} alt="" className="applogo" style={{ width: 84, height: 84, borderRadius: 24 }} />
          <h1 className="h1" style={{ marginTop: 18, fontSize: 40 }}>Aqademiq</h1>
          <div className="sub" style={{ fontSize: 17, marginTop: 6 }}>Your focus sanctuary.</div>
          <div className="sub" style={{ margin: '18px auto 30px', maxWidth: 380 }}>Plan your week with Ada, focus with a melting-ice timer, and see your week as a record, not a score.</div>
          <button className="btn block" onClick={() => setStep(1)}>Jump right in!</button>
          <button className="btn ghost block" style={{ marginTop: 10 }} onClick={onSignIn}>Sign in / Sign up</button>
          <div className="small" style={{ marginTop: 14 }}>Already on Aqademiq on your phone? Sign in with the same account and your plan is here.</div>
        </div>}
        {step === 1 && <div>
          {dots}
          <h1 className="h1">What should we<br />call you?</h1>
          <div className="sub" style={{ margin: '6px 0 20px' }}>First name is fine. Ada uses it when she talks to you.</div>
          <input className="input" autoFocus placeholder="Your first name" value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter' && name.trim()) setStep(2); }} />
          <button className="btn block" style={{ marginTop: 22 }} disabled={!name.trim()} onClick={() => setStep(2)}>Continue →</button>
        </div>}
        {step === 2 && <div>
          {dots}
          <h1 className="h1">What are you<br />studying?</h1>
          <div className="sub" style={{ margin: '6px 0 18px' }}>Ada shapes your plan around your workload.</div>
          <div className="label" style={{ marginTop: 0 }}>Level</div>
          <div className="chips">{['Undergraduate', 'Postgraduate', 'School', 'Self-taught'].map((l) => <button key={l} className={'chip' + (level === l ? ' on' : '')} onClick={() => setLevel(l)}>{l}</button>)}</div>
          <div className="label">Subjects this semester</div>
          {subs.map((x, i) => <div key={i} className="row" style={{ marginBottom: 6, fontWeight: 700 }}><span style={{ width: 8, height: 8, borderRadius: '50%', background: SUBJECT_COLORS[i % 7] }} />{x.code && <span style={{ color: MED }}>{x.code}</span>}{x.name}<button className="iconbtn" style={{ width: 28, height: 28, marginLeft: 'auto' }} onClick={() => setSubs(subs.filter((_, k) => k !== i))} aria-label="Remove"><Ic n="close" style={{ fontSize: 16, color: DIM }} /></button></div>)}
          <div className="row" style={{ gap: 8 }}>
            <input className="input" style={{ width: 110 }} placeholder="Code" value={code} onChange={(e) => setCode(e.target.value)} />
            <input className="input" placeholder="Subject name" value={sname} onChange={(e) => setSname(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') addSub(); }} />
            <button className="btn sm ghost" style={{ height: 48 }} onClick={addSub} disabled={!sname.trim()}>Add</button>
          </div>
          <button className="btn block" style={{ marginTop: 24 }} onClick={() => { if (sname.trim()) addSub(); setStep(3); }}>{subs.length || sname.trim() ? 'Continue →' : 'Skip for now →'}</button>
        </div>}
        {step === 3 && <div>
          {dots}
          <h1 className="h1">Meet Prism</h1>
          <div className="sub" style={{ margin: '6px 0 18px' }}>Focus soundscapes tuned to the kind of work you're doing. Tap one to hear it.</div>
          <div className="label" style={{ marginTop: 0 }}>Prism modes</div>
          <div className="group">
            {PRISM_MODES.map((m) =>
            <button key={m.label} className="srow" onClick={() => hear(m.label)} aria-pressed={mode === m.label} style={{ background: mode === m.label ? ACCL : 'transparent' }}>
                <div style={{ width: 40, height: 40, borderRadius: 12, background: m.color + '22', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n={m.glyph} style={{ fontSize: 22, color: m.color }} /></div>
                <span style={{ flex: 1 }}>{m.label}<span className="d">{m.desc}</span></span>
                <span className="v">{hearing === m.label && audible ? <span className="eq" aria-label="Playing"><i /><i /><i /></span> : mode === m.label ? <Ic n="check" style={{ fontSize: 20, color: ACC }} /> : null}</span>
              </button>)}
          </div>
          <div className="small" style={{ margin: '10px 4px 0' }}>Plays when you start a focus session. Change it any time on the Focus page or in Settings.</div>
          <button className="btn block" style={{ marginTop: 22 }} onClick={finish}>Let's go →</button>
        </div>}
      </div>
    </div>);
}

/* ─── THE APP ─────────────────────────────────────────────────────────── */

const PAGES = [['plan', 'Planner', 'planner'], ['subjects', 'Subjects', 'subjects'], ['focus', 'Focus', 'focus'], ['ada', 'Ada', null], ['week', 'Your week', 'insights'], ['preferences', 'Settings', 'settings']];

function useDark(theme) {
  const mq = typeof matchMedia === 'function' ? matchMedia('(prefers-color-scheme: dark)') : null;
  const [sys, setSys] = React.useState(mq ? mq.matches : false);
  React.useEffect(() => { if (!mq) return; const on = (e) => setSys(e.matches); mq.addEventListener ? mq.addEventListener('change', on) : mq.addListener(on); return () => (mq.removeEventListener ? mq.removeEventListener('change', on) : mq.removeListener(on)); }, []);
  return theme === 'dark' || (theme === 'system' && sys);
}

// Guest (this browser) or signed in (your account, shared with the phone).
const toastBus = new EventTarget();
const busToast = (text) => toastBus.dispatchEvent(new CustomEvent('toast', { detail: text }));

const themeVars = () => ({ '--page': PAGE, '--pill': PILL, '--bg': BG, '--hilite': HILITE, '--card': WHITE, '--text': TEXT, '--med': MED, '--dim': DIM, '--border': BORDER, '--shadow': SHADOW, '--acc': ACC, '--accl': ACCL, '--ink': INK, '--navon': NAV_ON });

function AqademiqWeb() {
  const [gs, gupdate, cloud] = useAppState();
  const { session, reachable } = useAuth();
  const signedIn = !!(session && reachable);
  const acct = useAccountStore(signedIn ? session : null, gs.settings, busToast);
  // The sign-in screen lives up here, above the guest/account switch: verifying a
  // reset code signs you in, and the screen must stay open to set the new password.
  const [auth, setAuth] = React.useState(null);
  const settings = (signedIn && acct.s ? acct.s : gs).settings;
  const dark = useDark(settings.theme);
  applyTweaks({ accent: settings.accent, warmth: 'Cool', darkMode: dark, subjectsLayout: 'List', focusTimer: settings.focusStyle });
  const vars = themeVars();
  const authLayer = auth && <div className={'scrim full' + (dark ? ' dark' : '')} style={vars}>
    <AuthScreen start={auth} onClose={() => setAuth(null)} onDone={(how) => { setAuth(null); busToast(how === 'reset' ? 'Password saved. You\'re signed in.' : 'Signed in'); }} />
  </div>;
  let body;
  if (signedIn && !acct.s) {
    body = (
      <div className={'ob' + (dark ? ' dark' : '')} style={vars}>
        <div style={{ textAlign: 'center' }}>
          <CubeSVG size={80} tone={CUBE_TONES[4]} melt={0} expr={acct.status === 'error' ? 'meh' : 'happy'} bubbles={3} />
          <div style={{ fontSize: 17, fontWeight: 800, marginTop: 14 }}>{acct.status === 'error' ? 'Couldn\'t open your account' : 'Opening your account…'}</div>
          {acct.status === 'error' && <div className="row" style={{ justifyContent: 'center', gap: 10, marginTop: 16 }}>
            <button className="btn sm" onClick={acct.reload}>Try again</button>
            <button className="btn sm ghost" onClick={() => SB.client && SB.client.auth.signOut()}>Sign out</button>
          </div>}
        </div>
      </div>);
  } else {
    body = <AppView key={signedIn ? 'acct:' + session.user.id : 'guest'} s={signedIn ? acct.s : gs} update={signedIn ? acct.update : gupdate} cloud={cloud} acct={signedIn ? acct : null} guest={gs} guestUpdate={gupdate} session={signedIn ? session : null} openAuth={(m) => setAuth(m || 'signin')} />;
  }
  return <>{body}{authLayer}</>;
}

function AppView({ s, update, cloud, acct, guest, guestUpdate, session, openAuth }) {
  const dark = useDark(s.settings.theme);
  applyTweaks({ accent: s.settings.accent, warmth: 'Cool', darkMode: dark, subjectsLayout: 'List', focusTimer: s.settings.focusStyle });
  const hashPage = () => { const h = (location.hash || '').slice(1); return PAGES.some((p) => p[0] === h) ? h : 'plan'; };
  const [page, setPage] = React.useState(hashPage);
  const [app, setApp] = React.useState(null);
  const [sheet, setSheet] = React.useState(null);
  const [toast, setToast] = React.useState(null);
  const [adaDraft, setAdaDraft] = React.useState(null);
  const [ask, setAsk] = React.useState(null);
  const sRef = React.useRef(s); sRef.current = s;
  React.useEffect(() => { const on = (e) => setToast({ text: e.detail }); toastBus.addEventListener('toast', on); return () => toastBus.removeEventListener('toast', on); }, []);

  // Signed in with a plan still in this browser from guest use: offer to bring it over, once.
  const bringKey = session ? 'aq-web-bring-' + session.user.id : null;
  React.useEffect(() => {
    if (!acct || acct.status !== 'ready' || !s.profile.onboarded) return;
    const has = guest.tasks.length || guest.subjects.length;
    let asked = false; try { asked = !!localStorage.getItem(bringKey); } catch (e) { /* ignore */ }
    if (has && !asked) setSheet(<BringOver guest={guest} onClose={() => { try { localStorage.setItem(bringKey, '1'); } catch (e) { /* ignore */ } setSheet(null); }}
      onBring={async () => {
        const moved = (kind, id) => guestUpdate((st) => kind === 'task' ? { ...st, tasks: st.tasks.filter((x) => x.id !== id) }
          : kind === 'subject' ? { ...st, subjects: st.subjects.filter((x) => x.id !== id) }
          : { ...st, moods: Object.fromEntries(Object.entries(st.moods).filter(([d]) => d !== id)) });
        try {
          await acct.bringOver(guest, moved);
          try { localStorage.setItem(bringKey, '1'); } catch (e) { /* ignore */ }
          setSheet(null); setToast({ text: 'Your plan is in your account now' });
        } catch (e) {
          setSheet(null); setToast({ text: 'Part of your plan didn\'t move. We\'ll offer the rest next time you open Aqademiq.' });
        }
      }} />);
  }, [acct && acct.status, s.profile.onboarded]);

  async function signOut() {
    if (PRISM.state !== 'stopped') PRISM.stop();
    try { if (session) localStorage.removeItem(ACCT_CACHE(session.user.id)); } catch (e) { /* ignore */ }
    try { await SB.client.auth.signOut(); } catch (e) { /* the session is dropped locally anyway */ }
    SB.session = null; SB.emit();
  }

  React.useEffect(() => { document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light'); }, [dark]);
  // Finishing onboarding always lands on the Planner.
  const wasOnboarded = React.useRef(s.profile.onboarded);
  React.useEffect(() => { if (!wasOnboarded.current && s.profile.onboarded) setPage('plan'); wasOnboarded.current = s.profile.onboarded; }, [s.profile.onboarded]);
  React.useEffect(() => { if (location.hash.slice(1) !== page) history.replaceState(null, '', '#' + page); window.scrollTo(0, 0); }, [page]);
  React.useEffect(() => { const on = () => setPage(hashPage()); window.addEventListener('hashchange', on); return () => window.removeEventListener('hashchange', on); }, []);
  React.useEffect(() => { if (!toast) return; const t = setTimeout(() => setToast(null), toast.undo ? 5000 : 2600); return () => clearTimeout(t); }, [toast]);
  React.useEffect(() => { __promptHook = (label, initial) => { setAsk({ label, value: initial || '' }); return null; }; }, []);

  // The focus clock runs everywhere: finishing ends the session even on another page.
  const f = s.focus;
  useTick(f.status === 'running');
  const left = focusLeft(f);
  React.useEffect(() => { if (f.status === 'running' && left <= 0) endFocus(true); }, [f.status, left]);
  React.useEffect(() => { document.title = f.status === 'running' ? `${mmss(left)} · Aqademiq` : 'Aqademiq'; }, [f.status, left]);

  // Prism follows the session like the app's PrismAudioController: play on start
  // (Autoplay or an explicit pick), hold while frozen, fade out when it ends.
  const pz = s.settings.prism;
  const prismLabel = f.prism || pz.mode;
  const prevStatus = React.useRef(f.status);
  React.useEffect(() => { PRISM.setVolumes({ master: pz.master, env: pz.env, rhythm: pz.rhythm }); }, [pz.master, pz.env, pz.rhythm]);
  React.useEffect(() => {
    const prev = prevStatus.current, st = PRISM.state;
    prevStatus.current = f.status;
    if (f.status === 'running') {
      if (prev !== 'running' && prev !== 'frozen') prismWant.preview = false;
      if (prismLabel === PRISM_OFF) { if (st !== 'stopped') PRISM.stop(); return; }
      if (st === 'paused') { if (PRISM.label !== prismLabel) PRISM.switchMode(prismLabel); PRISM.resume(); return; }
      if (st === 'playing' || st === 'loading') { if (PRISM.label !== prismLabel) PRISM.switchMode(prismLabel); return; }
      if (prismWant.current) PRISM.start(prismLabel);
    } else if (f.status === 'frozen') {
      if (prismLabel === PRISM_OFF) { if (st !== 'stopped') PRISM.stop(); return; }
      if (st === 'playing') PRISM.pause();
      // Still loading: drop it. prismWant stays set, so Resume starts it fresh.
      else if (st === 'loading') PRISM.stop();
      if (PRISM.label !== prismLabel && (st === 'playing' || st === 'paused')) PRISM.switchMode(prismLabel);
    } else if (prev === 'running' || prev === 'frozen') {
      PRISM.stop();
    }
  }, [f.status, prismLabel]);

  function endFocus(finished) {
    update((st) => {
      const ff = st.focus;
      if (ff.status !== 'running' && ff.status !== 'frozen') return st;
      const l = focusLeft(ff);
      const minutes = Math.round((ff.total - (finished ? 0 : l)) / 60);
      const task = ff.taskId && st.tasks.find((t) => t.id === ff.taskId);
      // A session that ran out while the tab was closed belongs to the day it ended.
      const sess = { id: uid(), date: dkey(new Date(finished && ff.endsAt ? Math.min(ff.endsAt, Date.now()) : Date.now())), minutes, taskId: ff.taskId, subjectId: task ? task.subjectId : null, at: Date.now() };
      return { ...st, sessions: [...st.sessions, sess], focus: { ...ff, status: 'done', remaining: 0 } };
    });
  }

  const toggleTask = (t) => update((st) => ({ ...st, tasks: st.tasks.map((x) => x.id === t.id ? { ...x, done: !x.done, doneOn: !x.done ? todayKey() : null } : x) }));
  const toggleMicro = (t, i) => update((st) => ({ ...st, tasks: st.tasks.map((x) => {
    if (x.id !== t.id) return x;
    const subtasks = x.subtasks.map((m, k) => k === i ? { ...m, done: !m.done } : m);
    const all = subtasks.every((m) => m.done);
    return { ...x, subtasks, done: all, doneOn: all ? todayKey() : null };
  }) }));

  async function breakdown(t) {
    if (acct) {
      setToast({ text: 'Ada is breaking it down…' });
      try { const n = await acct.breakdown(t); setToast({ text: n ? `Broken into ${n} steps` : 'Ada couldn\'t break that down. Try again?' }); }
      catch (e) { setToast({ text: e && e.status === 429 ? 'Ada has done all the thinking she can for today.' : 'Ada couldn\'t break that down. Try again?' }); }
      return;
    }
    const c = window.claude;
    const sample = c && c.use ? await c.use('sample') : null;
    if (!sample) { setApp('ada'); return; }
    setToast({ text: 'Ada is breaking it down…' });
    try {
      const sub = t.subjectId && sRef.current.subjects.find((x) => x.id === t.subjectId);
      let out = await sample.json(`You are Ada, a calm study planner. Break this study task into 3 to 5 small, concrete steps a student can tick off. Task: "${t.title}"${sub ? ` for ${sub.code || ''} ${sub.name}` : ''}, about ${t.dur || 30} minutes in total${t.note ? `. Note: ${t.note}` : ''}. Reply ONLY with JSON: {"steps":[{"title":string,"minutes":number}]} with minutes summing to roughly the total.`, { modelTier: 'quick', cache: false });
      if (typeof out === 'string') out = JSON.parse(out);
      const steps = (out && Array.isArray(out.steps) ? out.steps : []).filter((x) => x && x.title).slice(0, 6).map((x) => ({ title: String(x.title).slice(0, 80), minutes: Math.max(0, Math.round(+x.minutes || 0)), done: false }));
      if (!steps.length) throw new Error('empty');
      update((st) => ({ ...st, tasks: st.tasks.map((x) => x.id === t.id ? { ...x, subtasks: steps, done: false } : x) }));
      setToast({ text: `Broken into ${steps.length} steps` });
    } catch (e) { setToast({ text: e && e.code === 'not_granted' ? 'Ada needs your OK to think with Claude' : 'Ada couldn\'t break that down. Try again?' }); }
  }

  const act = (what, t, arg) => {
    setSheet(null);
    if (what === 'toggle') toggleTask(t);
    if (what === 'move') { update((st) => ({ ...st, tasks: st.tasks.map((x) => x.id === t.id ? { ...x, date: arg } : x) })); setToast({ text: `Moved to ${relIn(arg)}` }); }
    if (what === 'focus') { update((st) => ({ ...st, focus: st.focus.status === 'idle' || st.focus.status === 'done' ? { ...freshState().focus, taskId: t.id, total: (t.dur || 25) * 60, remaining: (t.dur || 25) * 60 } : st.focus })); setPage('focus'); }
    if (what === 'edit') ui.newTask({}, t);
    if (what === 'breakdown') breakdown(t);
    if (what === 'delete') {
      const snapshot = t;
      update((st) => ({ ...st, tasks: st.tasks.filter((x) => x.id !== t.id) }));
      setToast({ text: 'Task deleted', undo: () => update((st) => ({ ...st, tasks: [...st.tasks, snapshot] })) });
    }
  };

  const ui = {
    go: (p) => { setSheet(null); setPage(p); },
    app: (k) => setApp(k),
    openAuth: (mode) => openAuth(mode || 'signin'),
    signOut,
    signedIn: !!acct,
    ensureWeek: (mon) => { if (acct) acct.ensureWeek(mon); },
    importCheck: acct ? (list, source) => acct.importCheck(list, source) : null,
    deleteAccount: async () => {
      try { await api('DELETE', '/profile/account'); } catch (e) { setToast({ text: 'Couldn\'t delete your account right now. Try again.' }); return; }
      await signOut(); busToast('Your account was deleted');
    },
    toast: (text) => setToast({ text }),
    toggleTask, toggleMicro, endFocus,
    adaDraft, clearAdaDraft: () => setAdaDraft(null),
    askAda: (q) => { setAdaDraft(q); setPage('ada'); },
    openTask: (t) => setSheet(<TaskActions s={sRef.current} t={t} onClose={() => setSheet(null)} act={act} />),
    newTask: (defaults, task) => setSheet(<TaskForm s={sRef.current} task={task} defaults={{ date: todayKey(), ...defaults }} onClose={() => setSheet(null)} onSave={(v) => {
      setSheet(null);
      if (task) { update((st) => ({ ...st, tasks: st.tasks.map((x) => x.id === task.id ? { ...x, ...v } : x) })); return; }
      const nt = { id: uid(), title: v.title, tag: v.tag, subjectId: v.subjectId || null, date: v.date, time: v.time, dur: v.dur, note: v.note, done: false, createdAt: Date.now() };
      update((st) => ({ ...st, tasks: [...st.tasks, nt] }));
      setToast({ text: `Added to ${relIn(v.date)}` });
      if (v.ada) breakdown(nt);
    }} />),
    editSubject: (sub) => setSheet(<SubjectForm s={sRef.current} subject={sub} onClose={() => setSheet(null)}
      onDelete={() => { update((st) => ({ ...st, subjects: st.subjects.filter((x) => x.id !== sub.id), tasks: st.tasks.map((t) => t.subjectId === sub.id ? { ...t, subjectId: null } : t) })); setSheet(null); }}
      onSave={(v) => { update((st) => ({ ...st, subjects: sub ? st.subjects.map((x) => x.id === sub.id ? { ...x, ...v } : x) : [...st.subjects, { ...v, id: uid() }] })); setSheet(null); }} />),
    editProfile: () => setSheet(<ProfileSheet s={sRef.current} onClose={() => setSheet(null)} onSave={(p) => { update((st) => ({ ...st, profile: p })); setSheet(null); }} />),
    logMood: () => setSheet(<Sheet title="How are you feeling today?" onClose={() => setSheet(null)}><MoodPicker value={sRef.current.moods[todayKey()]} onPick={(i) => { update((st) => ({ ...st, moods: { ...st.moods, [todayKey()]: i } })); setSheet(null); setToast({ text: 'Mood logged' }); }} /></Sheet>),
    reschedule: (day) => setSheet(<RescheduleSheet s={sRef.current} day={day} onClose={() => setSheet(null)} onMove={(ids, to) => { update((st) => ({ ...st, tasks: st.tasks.map((t) => ids.includes(t.id) ? { ...t, date: to } : t) })); setSheet(null); setToast({ text: `Moved ${ids.length} to ${relIn(to)}` }); }} />),
    importer: (kind) => setSheet(<ImportSheet s={sRef.current} kind={kind} onClose={() => setSheet(null)} onAdd={async (list, tag, source) => {
      if (acct) {
        // Signed in: the server imports and dedupes, exactly as from the phone.
        setSheet(<Sheet title="Adding to your plan…" onClose={() => {}}><div className="empty small">Sending {list.length} {list.length === 1 ? 'item' : 'items'} to your account…</div></Sheet>);
        try {
          const r = await acct.importItems(list, tag, source);
          setSheet(<Sheet title="Added to your plan" onClose={() => setSheet(null)}>
            <div className="empty" style={{ paddingTop: 0 }}>
              <CubeSVG size={84} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
              <div className="sub" style={{ margin: '10px auto 18px', maxWidth: 340 }}>Added {r.imported} {r.imported === 1 ? 'task' : 'tasks'}{r.skipped ? `, ${r.skipped} already in your plan` : ''}. They're on your phone too.</div>
              <button className="btn block" onClick={() => { setSheet(null); setPage('plan'); }}>See it in my plan</button>
            </div>
          </Sheet>);
        } catch (e) { setSheet(null); setToast({ text: 'Couldn\'t import that into your account. Try again.' }); }
        return;
      }
      update((st) => ({
        ...st,
        tasks: [...st.tasks, ...list.map((x) => ({ id: uid(), title: x.title, tag, subjectId: null, date: x.date, time: x.time, dur: x.dur || 30, done: false, source, importKey: x.key, createdAt: Date.now() }))],
        imported: [...st.imported, ...list.map((x) => x.key)],
      }));
      setSheet(<Sheet title="Added to your plan" onClose={() => setSheet(null)}>
        <div className="empty" style={{ paddingTop: 0 }}>
          <CubeSVG size={84} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
          <div className="sub" style={{ margin: '10px auto 18px', maxWidth: 320 }}>Added {list.length} {list.length === 1 ? 'task' : 'tasks'}. They're ordinary tasks now, and importing the same source again only adds what's new.</div>
          <button className="btn block" onClick={() => { setSheet(null); setPage('plan'); }}>See it in my plan</button>
        </div>
      </Sheet>);
    }} />),
  };

  const vars = { '--page': PAGE, '--pill': PILL, '--bg': BG, '--hilite': HILITE, '--card': WHITE, '--text': TEXT, '--med': MED, '--dim': DIM, '--border': BORDER, '--shadow': SHADOW, '--acc': ACC, '--accl': ACCL, '--ink': INK, '--navon': NAV_ON };


  if (!s.profile.onboarded) {
    return (
      <UI.Provider value={ui}>
        <div className={dark ? 'dark' : ''} style={vars}>
          {acct ? <AccountOnboarding s={s} onDone={() => acct.reload()} onSignOut={signOut} /> : <Onboarding s={s} update={update} onSignIn={() => openAuth('signin')} />}
        </div>
        {app && <div style={vars}><GetApp kind={app} onClose={() => setApp(null)} /></div>}
        {toast && <div className="toast" style={vars}>{toast.text}</div>}
      </UI.Provider>);
  }

  const P = { s, update, cloud };
  return (
    <UI.Provider value={ui}>
      <div className={'aq' + (dark ? ' dark' : '')} style={vars}>
        <header className="topbar">
          <div className="topbar-in">
            <button className="brand" onClick={() => ui.go('plan')} aria-label="Aqademiq, go to Planner"><img src={window.__resources.logo} alt="" /><b>Aqademiq</b></button>
            <nav className="tabs" aria-label="Main">
              {PAGES.filter((p) => p[0] !== 'preferences').map(([k, l, ic]) =>
              <button key={k} className={page === k ? 'on' : ''} aria-current={page === k ? 'page' : undefined} onClick={() => ui.go(k)}>
                  {ic ? <Ic n={ic} fill={page === k} style={{ fontSize: 20 }} /> : <AdaNavFace size={22} />}<span>{l}</span>
                </button>)}
            </nav>
            <div className="topbar-end">
              {f.status !== 'idle' && f.status !== 'done' && page !== 'focus' &&
              <button className="runpill" onClick={() => ui.go('focus')} aria-label="Back to the focus session"><Ic n={f.status === 'frozen' ? 'freeze' : 'focus'} style={{ fontSize: 16 }} />{mmss(left)}</button>}
              <button className="getbtn" onClick={() => setApp('get')}><Ic n="download" style={{ fontSize: 18 }} /><span>Get the app</span></button>
              <AccountButton s={s} onSettings={() => ui.go('preferences')} />
            </div>
          </div>
        </header>
        <main className="main">
          {page === 'plan' && <PlanPage {...P} />}
          {page === 'subjects' && <SubjectsPage {...P} />}
          {page === 'focus' && <FocusPage {...P} />}
          {page === 'ada' && (acct ? <AccountAdaPage s={s} onPlanChanged={() => acct.reload()} /> : <AdaPage {...P} />)}
          {page === 'week' && <WeekPage {...P} />}
          {page === 'preferences' && <SettingsPage {...P} />}
        </main>
        <nav className="mobnav">
          {[['subjects', 'subjects'], ['plan', 'planner'], ['ada', null], ['focus', 'focus'], ['week', 'insights']].map(([k, ic]) =>
          <button key={k} className={page === k ? 'on' : ''} onClick={() => ui.go(k)} aria-label={k}>
              {ic ? <Ic n={ic} fill={page === k} style={{ fontSize: 24 }} /> : <AdaNavFace size={34} />}
            </button>)}
        </nav>
        {sheet}
        {app && <GetApp kind={app} onClose={() => setApp(null)} />}
        {ask && <Sheet title={ask.label} onClose={() => setAsk(null)}>
          <input className="input" autoFocus value={ask.value} onChange={(e) => setAsk({ ...ask, value: e.target.value })} onKeyDown={(e) => { if (e.key === 'Enter' && ask.value.trim()) { const v = ask.value.trim(); update((st) => ({ ...st, semesters: st.semesters.includes(v) ? st.semesters : [...st.semesters, v], semester: v })); setAsk(null); } }} placeholder="Spring '27" />
          <button className="btn block" style={{ marginTop: 14 }} disabled={!ask.value.trim()} onClick={() => { const v = ask.value.trim(); update((st) => ({ ...st, semesters: st.semesters.includes(v) ? st.semesters : [...st.semesters, v], semester: v })); setAsk(null); }}>Add semester</button>
        </Sheet>}
        {toast && <div className="toast">{toast.text}{toast.undo && <button onClick={() => { toast.undo(); setToast(null); }}>Undo</button>}</div>}
      </div>
    </UI.Provider>);
}

ReactDOM.createRoot(document.getElementById('root')).render(<AqademiqWeb />);
