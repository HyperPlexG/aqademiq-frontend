/* ─── SUBJECTS ────────────────────────────────────────────────────────── */

function SubjectForm({ s, subject, onSave, onDelete, onClose }) {
  const [f, setF] = React.useState(() => subject ? { ...subject } : { code: '', name: '', credits: 3, color: SUBJECT_COLORS[s.subjects.length % SUBJECT_COLORS.length], targetType: 'Grade', target: 'A', prof: '', feeling: 'OK', semester: s.semester });
  const set = (k, v) => setF((o) => ({ ...o, [k]: v }));
  const targets = { Grade: ['A', 'A-', 'B+', 'B', 'C'], GPA: ['4.0', '3.7', '3.3', '3.0'], '%': ['90%', '80%', '70%', '60%'] };
  return (
    <Sheet title={subject ? 'Edit subject' : 'Add subject'} onClose={onClose} foot={
      <div>
        <button className="btn block" disabled={!f.name.trim()} onClick={() => onSave({ ...f, name: f.name.trim(), code: f.code.trim() })}>Save</button>
        {subject && <div style={{ marginTop: 12 }}><Hold label="Hold to delete subject" ms={1200} onDone={onDelete} className="btn ghost block" /></div>}
      </div>}>
      <div className="row" style={{ gap: 12 }}>
        <div className="field" style={{ width: 130 }}><span>Code</span><input className="input" placeholder="CC 401" value={f.code} onChange={(e) => set('code', e.target.value)} /></div>
        <div className="field" style={{ flex: 1 }}><span>Name</span><input className="input" autoFocus placeholder="Compiler Construction" value={f.name} onChange={(e) => set('name', e.target.value)} /></div>
      </div>
      <div className="row" style={{ gap: 12, flexWrap: 'wrap' }}>
        <div className="field" style={{ width: 130 }}><span>Credits</span><input className="input" type="number" min="0" max="12" value={f.credits} onChange={(e) => set('credits', +e.target.value)} /></div>
        <div className="field" style={{ flex: 1, minWidth: 200 }}><span>Professor (optional)</span><input className="input" placeholder="Prof. S. Rao" value={f.prof} onChange={(e) => set('prof', e.target.value)} /></div>
      </div>
      <div className="field"><span>Colour</span>
        <div className="row">{SUBJECT_COLORS.map((c) => <button key={c} className={'swatch' + (f.color === c ? ' on' : '')} style={{ background: c }} onClick={() => set('color', c)} aria-label={'Colour ' + c} />)}</div>
      </div>
      <div className="field"><span>Target</span>
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <div className="seg">{Object.keys(targets).map((k) => <button key={k} className={f.targetType === k ? 'on' : ''} onClick={() => { set('targetType', k); set('target', targets[k][0]); }}>{k === '%' ? 'Percentage' : k}</button>)}</div>
          <div className="chips">{targets[f.targetType].map((t) => <button key={t} className={'chip' + (f.target === t ? ' on' : '')} onClick={() => set('target', t)}>{t}</button>)}</div>
        </div>
      </div>
      <div className="field"><span>How do you feel about it?</span>
        <div className="chips">{FEELINGS.map((x) => <button key={x} className={'chip' + (f.feeling === x ? ' on' : '')} onClick={() => set('feeling', x)}>{x}</button>)}</div>
      </div>
    </Sheet>);
}

function SubjectsPage({ s, update }) {
  const ui = useUI();
  const [detail, setDetail] = React.useState(null);
  const [semMenu, setSemMenu] = React.useState(false);
  const semRef = useDismiss(semMenu, () => setSemMenu(false));
  const weekStart = mondayOf(todayKey());
  let list = s.subjects.filter((x) => x.semester === s.semester);
  if (s.settings.sort === 'name') list = [...list].sort((a, b) => a.name.localeCompare(b.name));
  if (s.settings.sort === 'code') list = [...list].sort((a, b) => (a.code || '').localeCompare(b.code || ''));
  const sub = detail && s.subjects.find((x) => x.id === detail);
  const stats = (x) => ({
    open: s.tasks.filter((t) => t.subjectId === x.id && !t.done).length,
    focus: s.sessions.filter((z) => z.subjectId === x.id && z.date >= weekStart).reduce((a, z) => a + z.minutes, 0),
  });
  const addSem = () => {
    const name = prompt_('New semester name', '');
    if (name) update((st) => ({ ...st, semesters: [...st.semesters, name], semester: name }));
  };

  if (sub) {
    const st = stats(sub);
    const tasks = s.tasks.filter((t) => t.subjectId === sub.id).sort((a, b) => (a.done - b.done) || a.date.localeCompare(b.date));
    return (
      <div className="wrap" style={{ maxWidth: 820 }}>
        <div className="spread" style={{ marginBottom: 16 }}>
          <button className="iconbtn" onClick={() => setDetail(null)} aria-label="Back"><Ic n="back" style={{ fontSize: 24 }} /></button>
          <button className="pill" onClick={() => ui.editSubject(sub)}><Ic n="edit" style={{ fontSize: 16 }} />Edit</button>
        </div>
        <div className="code" style={{ fontSize: 13, fontWeight: 800, color: sub.color, letterSpacing: '0.05em' }}>{sub.code ? sub.code + ' · ' : ''}{sub.credits} CREDITS</div>
        <h1 className="h1" style={{ marginTop: 4 }}>{sub.name}</h1>
        {sub.prof && <div className="sub" style={{ marginTop: 4 }}>{sub.prof}</div>}
        <div className="stats" style={{ marginTop: 18 }}>
          <div className="card pad stat"><span>Target</span><b>{sub.target}</b></div>
          <div className="card pad stat"><span>You feel</span><b style={{ fontSize: 24 }}>{sub.feeling}</b></div>
          <div className="card pad stat"><span>This week</span><b>{fmtDur(st.focus) || '0m'}</b></div>
        </div>
        <div className="spread"><div className="label">Tasks ({tasks.length})</div><button className="link" onClick={() => ui.newTask({ date: todayKey(), subjectId: sub.id })}>+ Add task</button></div>
        {tasks.length ? tasks.map((t) => <TaskRow key={t.id} t={t} s={s} onOpen={ui.openTask} onToggle={ui.toggleTask} onToggleMicro={ui.toggleMicro} />) : <div className="card pad small">No tasks yet for {sub.code || sub.name}.</div>}
        <div className="label">Materials</div>
        <button className="group srow" style={{ width: '100%' }} onClick={() => ui.app('files')}>
          <Ic n="attach" style={{ fontSize: 22, color: ACC }} /><span>Syllabus, slides and notes<span className="d">Add files in the app and Ada reads them to plan around your deadlines.</span></span><span className="v"><span className="badge">APP</span><Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} /></span>
        </button>
      </div>);
  }

  return (
    <div className="wrap">
      <div className="spread" style={{ position: 'relative' }} ref={semRef}>
        <div>
          <h1 className="h1">Subjects</h1>
          <button className="row" onClick={() => setSemMenu(!semMenu)} style={{ border: 0, background: 'none', padding: 0, gap: 2, marginTop: 6, fontSize: 13, fontWeight: 800, color: MED, letterSpacing: '0.04em' }}>{s.semester.toUpperCase()} · {list.length}<Ic n="expand_more" style={{ fontSize: 16 }} /></button>
        </div>
        <div className="cluster">
          <button className="iconbtn" onClick={() => setSemMenu(!semMenu)} aria-label="Semester and sort"><Ic n="more" style={{ fontSize: 24 }} /></button>
          <button className="iconbtn" onClick={() => ui.editSubject(null)} aria-label="Add subject"><Ic n="add" style={{ fontSize: 24 }} /></button>
        </div>
        {semMenu && <div className="menu" role="menu" style={{ left: 0, right: 'auto', top: 74 }}>
          <div className="label" style={{ margin: '8px 12px 4px' }}>Semester</div>
          {s.semesters.map((x) => <button key={x} onClick={() => { update((st) => ({ ...st, semester: x })); setSemMenu(false); }}>{x === s.semester ? <Ic n="check" style={{ fontSize: 18, color: ACC }} /> : <span style={{ width: 18 }} />}{x}</button>)}
          <button onClick={() => { setSemMenu(false); addSem(); }}><Ic n="add" style={{ fontSize: 18, color: MED }} />Add semester</button>
          <div className="label" style={{ margin: '8px 12px 4px' }}>Sort</div>
          {[['added', 'In the order you added them'], ['name', 'Name'], ['code', 'Code']].map(([k, l]) => <button key={k} onClick={() => { update((st) => ({ ...st, settings: { ...st.settings, sort: k } })); setSemMenu(false); }}>{s.settings.sort === k ? <Ic n="check" style={{ fontSize: 18, color: ACC }} /> : <span style={{ width: 18 }} />}{l}</button>)}
        </div>}
      </div>
      {list.length === 0 ?
      <div className="card pad empty" style={{ marginTop: 20 }}>
          <CubeSVG size={70} tone={CUBE_TONES[4]} melt={0} expr="smile" bubbles={3} />
          <div style={{ fontSize: 17, fontWeight: 800, marginTop: 10 }}>No subjects yet</div>
          <div className="small" style={{ margin: '4px 0 14px' }}>Add what you're studying this semester. Ada shapes your plan around it.</div>
          <button className="btn sm" onClick={() => ui.editSubject(null)}>Add a subject</button>
        </div> :
      <div className="subjects" style={{ marginTop: 20 }}>
          {list.map((x) => {
            const st = stats(x);
            return (
              <button key={x.id} className="card subj" onClick={() => setDetail(x.id)}>
                <div className="row" style={{ gap: 6 }}><span style={{ width: 8, height: 8, borderRadius: '50%', background: x.color }} /><span className="code" style={{ color: x.color }}>{x.code || 'SUBJECT'}</span><span className="small">· {x.credits} cr</span></div>
                <div style={{ fontSize: 20, fontWeight: 800, margin: '6px 0 10px', lineHeight: 1.25 }}>{x.name}</div>
                <div className="row small" style={{ gap: 12, flexWrap: 'wrap' }}>
                  <span className="row" style={{ gap: 4 }}><Ic n="goal" style={{ fontSize: 16 }} />{x.target}</span>
                  <span>{st.open} open</span>
                  <span>{fmtDur(st.focus) || '0m'} this week</span>
                  <span>Feels {x.feeling.toLowerCase()}</span>
                </div>
              </button>);
          })}
        </div>}
    </div>);
}

// The page runs sandboxed, where prompt() is refused: a tiny inline prompt instead.
let __promptHook = null;
function prompt_(label, initial) { return __promptHook ? __promptHook(label, initial) : null; }

/* ─── FOCUS ───────────────────────────────────────────────────────────── */

function useTick(on) {
  const [, set] = React.useState(0);
  React.useEffect(() => { if (!on) return; const t = setInterval(() => set((n) => n + 1), 1000); return () => clearInterval(t); }, [on]);
}
function focusLeft(f) { return f.status === 'running' ? Math.max(0, Math.round((f.endsAt - Date.now()) / 1000)) : f.remaining; }
const mmss = (sec) => `${pad2(Math.floor(sec / 60))}:${pad2(sec % 60)}`;

function FocusPage({ s, update }) {
  const ui = useUI();
  const f = s.focus;
  useTick(f.status === 'running');
  const left = focusLeft(f);
  const progress = f.total ? 1 - left / f.total : 0;
  const task = f.taskId && s.tasks.find((t) => t.id === f.taskId);
  const todays = s.tasks.filter((t) => !t.done && t.date <= todayKey() && t.date >= addDays(todayKey(), -7));
  const [linkOpen, setLinkOpen] = React.useState(false);
  const [durOpen, setDurOpen] = React.useState(false);
  const setF = (patch) => update((st) => ({ ...st, focus: { ...st.focus, ...patch } }));

  const pz = s.settings.prism;
  const label = f.prism || pz.mode;
  const [pst] = usePrismState();
  const [menu, setMenu] = React.useState(false);
  const prismRef = useDismiss(menu, () => setMenu(false));
  React.useEffect(() => { if (pz.autoplay || f.prism) PRISM.prefetch(label); }, [label]);
  const inSession = f.status === 'running' || f.status === 'frozen';

  // Starting and resuming come from a tap, which is what lets the browser play sound.
  const start = () => {
    if (f.status === 'idle') prismWant.current = pz.autoplay;
    if (prismWant.current && label !== PRISM_OFF) PRISM.unlock();
    setF({ status: 'running', endsAt: Date.now() + f.remaining * 1000, startedAt: f.startedAt || Date.now() });
  };
  const freeze = () => setF({ status: 'frozen', remaining: left });
  const end = () => ui.endFocus(false);
  const pick = (m) => {
    setMenu(false);
    if (m === PRISM_OFF) { prismWant.current = false; setF({ prism: m }); return; }
    prismWant.current = true;
    PRISM.unlock();
    setF({ prism: m });
    if (f.status === 'running' && (PRISM.state === 'stopped' || PRISM.state === 'blocked' || PRISM.state === 'error')) PRISM.start(m);
  };
  const playNow = () => {
    prismWant.current = true;
    if (f.status !== 'running') return; // frozen: Resume brings the sound back
    if (PRISM.unlock()) PRISM.start(label); else ui.toast(PRISM.error || 'This browser can\'t play Prism.');
  };
  const stopNow = () => { prismWant.current = false; PRISM.stop(); };

  if (f.status === 'done') return <SessionDone s={s} update={update} />;

  const idle = f.status === 'idle';
  let prismLine = null;
  if (inSession && label !== PRISM_OFF) {
    if (pst === 'playing' || pst === 'paused') prismLine = <><span className="eq" aria-hidden="true"><i /><i /><i /></span><span>{label} · Prism{pst === 'paused' ? ' · held' : ''}</span><button className="link" style={{ fontSize: 14 }} onClick={stopNow}>Stop sound</button></>;
    else if (pst === 'loading') prismLine = <span>Loading Prism…</span>;
    else if (pst === 'error') prismLine = <><span>{PRISM.error}</span><button className="link" style={{ fontSize: 14 }} onClick={playNow}>Try again</button></>;
    else if (f.status === 'running') prismLine = <button className="chip" onClick={playNow}><Ic n="play" style={{ fontSize: 16, color: ACC }} />Play {label}</button>;
  }
  return (
    <div className="wrap" style={{ maxWidth: 720 }}>
      <div className="spread" style={{ flexWrap: 'wrap', rowGap: 10 }}>
        <h1 className="h1">Focus</h1>
        <div className="row" style={{ gap: 8, position: 'relative' }} ref={prismRef}>
          <button className={'chip' + (menu ? ' on' : '')} onClick={() => setMenu(!menu)} aria-haspopup="menu" aria-expanded={menu}>
            <Ic n="prism" style={{ fontSize: 18, color: label === PRISM_OFF ? DIM : prismColor(label) }} />{label === PRISM_OFF ? 'No sound' : label}<Ic n="chevron_down" style={{ fontSize: 14 }} />
          </button>
          <button className="chip" onClick={() => ui.app('freeze')}><Ic n="freeze" style={{ fontSize: 18, color: ACC }} />App freeze</button>
          {menu && <PrismMenu current={label} autoplay={pz.autoplay} onPick={pick} onClose={() => setMenu(false)}
            onAutoplay={(v) => update((st) => ({ ...st, settings: { ...st.settings, prism: { ...st.settings.prism, autoplay: v } } }))} />}
        </div>
      </div>
      <div className="focus">
        <button className="chip" style={{ marginTop: 18, height: 40, maxWidth: '100%' }} onClick={() => idle && setLinkOpen(true)}>
          {task ? <><span style={{ overflow: 'hidden', textOverflow: 'ellipsis', fontWeight: 700, color: TEXT }}>{task.title}</span>{task.subjectId && <span className="small">{(s.subjects.find((x) => x.id === task.subjectId) || {}).code}</span>}</> : <span>{idle ? 'Link a task (optional)' : 'Just focusing'}</span>}
          {idle && <Ic n="chevron_down" style={{ fontSize: 16 }} />}
        </button>
        <div style={{ margin: '26px 0 14px' }}>
          <IceTimer progress={progress} size={260} expr={f.status === 'frozen' ? 'neutral' : 'focused'} drip={f.status === 'running'} frost={f.status === 'frozen'} />
        </div>
        <div className="small" style={{ fontWeight: 800, letterSpacing: '0.06em', marginBottom: 4 }}>{f.status === 'running' ? 'FOCUSING' : f.status === 'frozen' ? 'FROZEN · TIME HELD' : 'READY'}</div>
        <button className="clock" onClick={() => idle && setDurOpen(true)} aria-label="Session length">{mmss(left)}</button>
        {idle && <div className="small" style={{ marginTop: 2 }}>Ada melts as you focus. Freeze holds the time.{label !== PRISM_OFF && pz.autoplay ? ` Prism plays ${label}.` : ''}</div>}
        {prismLine && <div className="row small" style={{ marginTop: 8, gap: 8, justifyContent: 'center', fontWeight: 700, color: MED }}>{prismLine}</div>}
        <div className="focus-row" style={{ marginTop: 22 }}>
          {idle && <button className="btn" style={{ minWidth: 220 }} onClick={start}><Ic n="play" style={{ fontSize: 20, color: '#fff' }} />Start focus</button>}
          {f.status === 'running' && <><button className="btn ghost" onClick={freeze}><Ic n="freeze" style={{ fontSize: 20, color: ACC }} />Freeze</button><button className="btn" onClick={end}><Ic n="end" style={{ fontSize: 18, color: '#fff' }} />End</button></>}
          {f.status === 'frozen' && <><button className="btn" onClick={start}><Ic n="play" style={{ fontSize: 20, color: '#fff' }} />Resume</button><button className="btn ghost" onClick={end}><Ic n="end" style={{ fontSize: 18 }} />End</button></>}
        </div>
        <button className="link" style={{ marginTop: 26, fontSize: 14 }} onClick={() => ui.app('ambient')}>Want the timer on your lock screen? Get the app</button>
      </div>
      {linkOpen && <Sheet title="Link a task" onClose={() => setLinkOpen(false)}>
        <div className="group" style={{ boxShadow: 'none', background: BG }}>
          <button className="srow" onClick={() => { setF({ taskId: null }); setLinkOpen(false); }}><Ic n="focus" style={{ fontSize: 22, color: MED }} />Just focus, no task</button>
          {todays.map((t) => <button key={t.id} className="srow" onClick={() => { setF({ taskId: t.id, total: (t.dur || 25) * 60, remaining: (t.dur || 25) * 60 }); setLinkOpen(false); }}>
            <span style={{ width: 10, height: 10, borderRadius: '50%', background: taskColor(s, t), flexShrink: 0 }} /><span>{t.title}<span className="d">{relDay(t.date)} · {fmtDur(t.dur)}</span></span></button>)}
        </div>
        {!todays.length && <div className="small" style={{ marginTop: 10 }}>Nothing open in your plan right now.</div>}
      </Sheet>}
      {durOpen && <Sheet title="Set time" onClose={() => setDurOpen(false)}>
        <div className="chips" style={{ justifyContent: 'center', marginBottom: 16 }}>
          {[5, 15, 25, 45, 60, 90].map((m) => <button key={m} className={'chip' + (f.total === m * 60 ? ' on' : '')} style={{ height: 48, padding: '0 20px', fontSize: 17 }} onClick={() => { setF({ total: m * 60, remaining: m * 60 }); setDurOpen(false); }}>{m} min</button>)}
        </div>
      </Sheet>}
    </div>);
}

function SessionDone({ s, update }) {
  const ui = useUI();
  const last = s.sessions[s.sessions.length - 1];
  const task = last && last.taskId && s.tasks.find((t) => t.id === last.taskId);
  const reset = (go) => { update((st) => ({ ...st, focus: { ...freshState().focus, total: st.focus.total, remaining: st.focus.total } })); if (go) ui.go(go); };
  const rate = (i) => update((st) => ({ ...st, sessions: st.sessions.map((x, k) => k === st.sessions.length - 1 ? { ...x, mood: i } : x) }));
  return (
    <div className="wrap" style={{ maxWidth: 560 }}>
      <div className="focus" style={{ paddingTop: 30 }}>
        <CubeSVG size={110} tone={CUBE_TONES[4]} melt={1} expr="happy" cheeks bubbles={0} />
        <div className="small" style={{ fontWeight: 800, letterSpacing: '0.06em', marginTop: 14 }}>SESSION DONE</div>
        <h1 className="h1" style={{ marginTop: 6 }}>{last ? fmtDur(last.minutes) || 'Under a minute' : ''} focused</h1>
        {task && <div className="sub" style={{ marginTop: 6 }}>{task.title}</div>}
        <div className="card pad" style={{ width: '100%', marginTop: 24 }}>
          <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 12 }}>How was that session?</div>
          <MoodPicker value={last && last.mood} onPick={rate} />
        </div>
        {task && !task.done && <button className="btn ghost block" style={{ marginTop: 14 }} onClick={() => { ui.toggleTask(task); }}><Ic n="check_circle" style={{ fontSize: 20, color: ACC }} />Mark "{task.title.length > 28 ? task.title.slice(0, 28) + '…' : task.title}" done</button>}
        <button className="btn block" style={{ marginTop: 12 }} onClick={() => reset('plan')}>Back to today →</button>
        <button className="quiet" style={{ marginTop: 6 }} onClick={() => reset()}>Start another session</button>
      </div>
    </div>);
}

/* ─── ADA ─────────────────────────────────────────────────────────────── */

const ADA_STARTERS = [['Plan my week', 'calendar_month'], ["I'm overwhelmed", 'self_improvement'], ['Break this down', 'account_tree'], ['Deadline help', 'alarm']];

function adaContext(s) {
  const t0 = todayKey();
  const tasks = s.tasks.filter((t) => t.date >= addDays(t0, -3) && t.date <= addDays(t0, 21)).slice(0, 120)
    .map((t) => ({ id: t.id, title: t.title, date: t.date, time: t.time, minutes: t.dur, done: !!t.done, subject: (s.subjects.find((x) => x.id === t.subjectId) || {}).code || null, tag: t.tag }));
  const subjects = s.subjects.filter((x) => x.semester === s.semester).map((x) => ({ code: x.code, name: x.name, credits: x.credits, target: x.target, feeling: x.feeling }));
  return { today: t0, weekday: DAY_NAMES[new Date().getDay()], student: s.profile.name || 'the student', tags: s.tags.map((t) => t.name), subjects, tasks, recentMood: s.moods[t0] != null ? MOODS[s.moods[t0]].label : null };
}

const ADA_RULES = `You are Ada, the planner inside Aqademiq, a calm study app for university students. Your mascot is a friendly ice cube.
Voice: warm, brief, practical. Never guilt, never shame missed work, no streak pressure. Short paragraphs. No markdown headings, no tables.
You can propose changes to the student's plan, but every change waits for their approval, so propose rather than claim you did it.
Reply ONLY with a JSON object:
{"reply": string (what you say, under 120 words),
 "proposals": [ {"action":"add","title":string,"date":"YYYY-MM-DD","time":"HH:MM" or null,"minutes":number,"subject":subject code or null,"tag":one of the tags or null}
              | {"action":"move","taskId":string,"date":"YYYY-MM-DD","time":"HH:MM", or null to keep the task's current time} ]}
Use proposals only when the student asks for planning, scheduling, breaking down or rescheduling; otherwise an empty list. At most 8 proposals. Keep sessions 15–90 minutes, leave breaks, avoid stacking more than about 4 hours of study in a day, and never schedule in the past.`;

function AdaPage({ s, update }) {
  const ui = useUI();
  const [chatId, setChatId] = React.useState(() => (s.chats[s.chats.length - 1] || {}).id || null);
  const [text, setText] = React.useState('');
  const [busy, setBusy] = React.useState(false);
  const [sampleOk, setSampleOk] = React.useState(null);
  const [listOpen, setListOpen] = React.useState(false);
  const endRef = React.useRef(null);
  const chat = s.chats.find((c) => c.id === chatId);
  const msgs = chat ? chat.messages : [];

  React.useEffect(() => { (async () => { const c = window.claude; const sm = c && c.use ? await c.use('sample') : null; setSampleOk(!!sm); })(); }, []);
  React.useEffect(() => { const box = endRef.current && endRef.current.parentElement; if (box) box.scrollTop = box.scrollHeight; }, [msgs.length, busy, chatId]);
  React.useEffect(() => { if (ui.adaDraft) { const d = ui.adaDraft; ui.clearAdaDraft(); send(d, true); } }, [ui.adaDraft]);

  const patchChat = (id, fn) => update((st) => ({ ...st, chats: st.chats.map((c) => c.id === id ? fn(c) : c) }));

  async function send(raw, fresh) {
    const q = (raw || '').trim();
    if (!q || busy) return;
    let id = fresh ? null : chatId;
    const userMsg = { role: 'user', text: q, at: Date.now() };
    if (!id) {
      id = uid();
      const c = { id, title: q.slice(0, 48), date: todayKey(), messages: [userMsg] };
      update((st) => ({ ...st, chats: [...st.chats, c] }));
      setChatId(id);
    } else patchChat(id, (c) => ({ ...c, messages: [...c.messages, userMsg] }));
    setText('');
    const c = window.claude;
    const sample = c && c.use ? await c.use('sample') : null;
    if (!sample) { patchChat(id, (cc) => ({ ...cc, messages: [...cc.messages, { role: 'ada', text: 'I think with Claude, and this view can\'t reach it. Open this page on claude.ai while signed in, or chat with me in the Aqademiq app.', at: Date.now(), offline: true }] })); return; }
    setBusy(true);
    const history = [...((s.chats.find((x) => x.id === id) || {}).messages || []), userMsg].slice(-12);
    const convo = history.map((m) => `${m.role === 'user' ? 'Student' : 'Ada'}: ${m.text}`).join('\n');
    const input = `${ADA_RULES}\n\nThe student's plan right now (JSON):\n${JSON.stringify(adaContext(s))}\n\nConversation so far:\n${convo}\n\nAnswer the student's last message as Ada, as the JSON object described.`;
    try {
      let out = await sample.json(input, { modelTier: 'default', cache: false });
      if (typeof out === 'string') { try { out = JSON.parse(out); } catch (e) { out = { reply: out, proposals: [] }; } }
      const reply = (out && typeof out.reply === 'string' && out.reply) || 'Here\'s what I\'d suggest.';
      const t0 = todayKey(), okDate = (d) => /^\d{4}-\d{2}-\d{2}$/.test(d || '') && dkey(fromKey(d)) === d && d >= t0; // a real date, never in the past
      const props = (out && Array.isArray(out.proposals) ? out.proposals : []).filter((p) => p && okDate(p.date) && (p.action === 'add' ? typeof p.title === 'string' && p.title.trim() : p.action === 'move' && s.tasks.some((t) => t.id === p.taskId))).slice(0, 8)
        .map((p) => ({ ...p, id: uid(), state: 'waiting', time: /^\d{2}:\d{2}$/.test(p.time || '') ? p.time : null }));
      patchChat(id, (cc) => ({ ...cc, messages: [...cc.messages, { role: 'ada', text: reply, proposals: props, at: Date.now() }] }));
    } catch (e) {
      const msg = e && e.code === 'not_granted' ? 'I need your OK to think with Claude on this page. Try again and allow it, or use me in the app.' : e && e.code === 'rate_limited' ? 'I\'m getting a lot of questions right now. Give me a minute and ask again.' : 'Something went wrong on my side. Ask me again?';
      patchChat(id, (cc) => ({ ...cc, messages: [...cc.messages, { role: 'ada', text: msg, at: Date.now() }] }));
    } finally { setBusy(false); }
  }

  const decide = (msgIdx, propIds, approve) => {
    update((st) => {
      let tasks = st.tasks;
      const chats = st.chats.map((c) => {
        if (c.id !== chatId) return c;
        const messages = c.messages.map((m, i) => {
          if (i !== msgIdx || !m.proposals) return m;
          return { ...m, proposals: m.proposals.map((p) => {
            if (!propIds.includes(p.id) || p.state !== 'waiting') return p;
            if (approve) {
              if (p.action === 'add') {
                const sub = st.subjects.find((x) => x.code && p.subject && x.code.toLowerCase() === String(p.subject).toLowerCase());
                const tag = st.tags.find((x) => p.tag && x.name.toLowerCase() === String(p.tag).toLowerCase());
                const tid = uid();
                tasks = [...tasks, { id: tid, title: p.title, date: p.date, time: p.time, dur: Math.max(5, Math.min(240, +p.minutes || 30)), subjectId: sub ? sub.id : null, tag: tag ? tag.name : null, done: false, source: 'Ada', createdAt: Date.now() }];
                return { ...p, state: 'added', taskId: tid };
              }
              tasks = tasks.map((t) => t.id === p.taskId ? { ...t, date: p.date, time: p.time || t.time, prev: { date: t.date, time: t.time } } : t);
              return { ...p, state: 'added' };
            }
            return { ...p, state: 'declined' };
          }) };
        });
        return { ...c, messages };
      });
      return { ...st, tasks, chats };
    });
  };
  const undo = (msgIdx, p) => update((st) => ({
    ...st,
    tasks: p.action === 'add' ? st.tasks.filter((t) => t.id !== p.taskId) : st.tasks.map((t) => t.id === p.taskId && t.prev ? { ...t, date: t.prev.date, time: t.prev.time, prev: undefined } : t),
    chats: st.chats.map((c) => c.id !== chatId ? c : { ...c, messages: c.messages.map((m, i) => i !== msgIdx ? m : { ...m, proposals: m.proposals.map((x) => x.id === p.id ? { ...x, state: 'waiting' } : x) }) }),
  }));

  const propLabel = (p) => {
    if (p.action === 'move') {
      const t = s.tasks.find((x) => x.id === p.taskId);
      const time = p.time || (t && t.time);
      return { t: `Move "${t ? t.title : 'task'}"`, d: `to ${relIn(p.date)} · ${time ? fmtTime(time) : 'Anytime'}` };
    }
    return { t: p.title, d: [relDay(p.date), p.time ? fmtTime(p.time) : 'Anytime', fmtDur(Math.max(5, Math.min(240, +p.minutes || 30))), p.subject].filter(Boolean).join(' · ') };
  };

  return (
    <div className="ada">
      <aside className="chatlist">
        <div className="spread" style={{ padding: '0 4px 10px' }}><h2 className="h2">Chats</h2><button className="iconbtn" onClick={() => setChatId(null)} aria-label="New chat"><Ic n="edit" style={{ fontSize: 20 }} /></button></div>
        {[...s.chats].reverse().map((c) => <button key={c.id} className={c.id === chatId ? 'on' : ''} onClick={() => setChatId(c.id)}><small>{shortDate(c.date).toUpperCase()}</small><b>{c.title}</b></button>)}
        {!s.chats.length && <div className="small" style={{ padding: '0 12px' }}>Your chats with Ada show up here.</div>}
      </aside>
      <section className="chat">
        <div className="spread" style={{ marginBottom: 8 }}>
          <div className="row"><AdaNavFace size={36} /><h1 className="h2">Ada</h1></div>
          <div className="row" style={{ gap: 6 }}>
            {s.chats.length > 0 && <button className="pill mob-only" onClick={() => setListOpen(true)}><Ic n="chats" style={{ fontSize: 16 }} />Chats</button>}
            {chat && <button className="pill" onClick={() => setChatId(null)}><Ic n="add" style={{ fontSize: 16 }} />New chat</button>}
          </div>
        </div>
        {listOpen && <Sheet title="Chats" onClose={() => setListOpen(false)}>
          <div className="chatlist sheet-list">
            {[...s.chats].reverse().map((c) => <button key={c.id} className={c.id === chatId ? 'on' : ''} onClick={() => { setChatId(c.id); setListOpen(false); }}><small>{shortDate(c.date).toUpperCase()}</small><b>{c.title}</b></button>)}
          </div>
        </Sheet>}
        <div className="msgs">
          {!chat &&
          <div className="empty" style={{ paddingTop: 40 }}>
              <CubeSVG size={96} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
              <h2 className="h2" style={{ marginTop: 14 }}>Hi{s.profile.name ? ' ' + s.profile.name : ''}, I'm Ada.</h2>
              <div className="sub" style={{ maxWidth: 420, margin: '6px auto 20px' }}>I build your week from your real workload. Every change I suggest waits for your OK.</div>
              <div className="chips" style={{ justifyContent: 'center' }}>{ADA_STARTERS.map(([q, ic]) => <button key={q} className="chip" onClick={() => send(q, true)}><Ic n={ic} style={{ fontSize: 18, color: ACC }} />{q}</button>)}</div>
              {sampleOk === false && <div className="card pad small" style={{ marginTop: 20, textAlign: 'left' }}>Ada thinks on your Aqademiq account. <button className="link" style={{ fontSize: 13 }} onClick={() => ui.openAuth('signin')}>Sign in</button> to chat with her here, or <button className="link" style={{ fontSize: 13 }} onClick={() => ui.app('ada')}>use Ada in the app</button>.</div>}
            </div>}
          {msgs.map((m, i) => m.role === 'user' ?
          <div key={i} className="msg me">{m.text}</div> :
          <div key={i} className="msg bot">
              <AdaNavFace size={30} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div>{m.text}</div>
                {m.offline && <button className="btn sm ghost" style={{ marginTop: 10 }} onClick={() => ui.app('ada')}>Get the app</button>}
                {m.proposals && m.proposals.length > 0 &&
              <div className="card" style={{ marginTop: 10, overflow: 'hidden' }}>
                    <div className="spread" style={{ padding: '10px 14px', borderBottom: `1px solid ${BORDER}` }}>
                      <span className="small" style={{ fontWeight: 800, letterSpacing: '0.05em' }}>{m.proposals.filter((p) => p.state === 'waiting').length} WAITING</span>
                      {m.proposals.some((p) => p.state === 'waiting') && <div className="row" style={{ gap: 6 }}>
                        <button className="quiet" style={{ fontSize: 14, padding: 4 }} onClick={() => decide(i, m.proposals.map((p) => p.id), false)}>Decline all</button>
                        <button className="btn sm" style={{ height: 34 }} onClick={() => decide(i, m.proposals.map((p) => p.id), true)}>Approve all</button>
                      </div>}
                    </div>
                    {m.proposals.map((p) => {
                  const l = propLabel(p);
                  return (
                    <div key={p.id} className="prop" style={{ opacity: p.state === 'declined' ? 0.45 : 1 }}>
                          <Ic n={p.action === 'move' ? 'carry_forward' : 'add'} style={{ fontSize: 20, color: ACC }} />
                          <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 15, fontWeight: 800 }}>{l.t}</div><div className="small">{l.d}</div></div>
                          {p.state === 'waiting' && <><button className="quiet" style={{ fontSize: 14 }} onClick={() => decide(i, [p.id], false)}>Decline</button><button className="btn sm" style={{ height: 34 }} onClick={() => decide(i, [p.id], true)}>Approve</button></>}
                          {p.state === 'added' && <><span className="small" style={{ color: SUCC, fontWeight: 800 }}>Added</span><button className="link" style={{ fontSize: 14 }} onClick={() => undo(i, p)}>Undo</button></>}
                          {p.state === 'declined' && <span className="small">Declined</span>}
                        </div>);
                })}
                  </div>}
              </div>
            </div>)}
          {busy && <div className="msg bot"><AdaNavFace size={30} /><div className="row small" style={{ gap: 6 }}><span className="think" style={{ display: 'inline-block', animation: 'aqPulse 1s infinite' }}>●</span>Ada is thinking…</div></div>}
          <div ref={endRef} />
        </div>
        <div className="composer">
          <textarea rows={1} placeholder={chat ? 'Ask Ada anything…' : "What's on your mind?"} value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(text); } }} />
          <button className="send" disabled={!text.trim() || busy} onClick={() => send(text)} aria-label="Send"><Ic n="send" style={{ fontSize: 20, color: '#fff' }} /></button>
        </div>
      </section>
    </div>);
}
