/* ─── PLANNER ─────────────────────────────────────────────────────────── */

function taskColor(s, t) {
  const sub = t.subjectId && s.subjects.find((x) => x.id === t.subjectId);
  if (sub) return sub.color;
  const tag = s.tags.find((x) => x.name === t.tag);
  return tag ? tagInfo(tag.key).hue : ACC;
}

function TaskRow({ t, s, onOpen, onToggle, onToggleMicro }) {
  const sub = t.subjectId && s.subjects.find((x) => x.id === t.subjectId);
  const color = taskColor(s, t);
  const micro = t.subtasks || [];
  const doneN = micro.filter((m) => m.done).length;
  return (
    <div className={'task' + (t.done ? ' done' : '')} style={micro.length ? { flexDirection: 'column', padding: 0, gap: 0 } : null} onClick={() => onOpen(t)}
      role="button" tabIndex={0} aria-label={`${t.title}${t.time ? ', ' + fmtTime(t.time) : ''}${t.done ? ', done' : ''}. Open actions`} onKeyDown={onKeyActivate(() => onOpen(t))}>
      <div style={{ display: 'flex', alignItems: 'stretch', gap: 11, padding: micro.length ? '11px 13px 9px' : 0, flex: 1 }}>
        {t.time && <div className="bar" style={{ background: color }} />}
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <div className="t">{t.title}</div>
          <div className="meta">
            {t.time && <span style={{ fontWeight: 800 }}>{fmtTime(t.time)}</span>}
            {sub && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 800, color }}><span style={{ width: 6, height: 6, borderRadius: '50%', background: color }} />{sub.code || sub.name}</span>}
            {!sub && t.tag && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 800, color }}><span style={{ width: 6, height: 6, borderRadius: '50%', background: color }} />{t.tag}</span>}
            {t.dur > 0 && <span style={{ color: MED, fontWeight: 600 }}>{fmtDur(t.dur)}</span>}
            {t.source && <span style={{ color: MED, fontWeight: 600 }}>· {t.source}</span>}
          </div>
        </div>
        {micro.length > 0 ?
        <div style={{ alignSelf: 'center', textAlign: 'center', flexShrink: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 800, color: ACC, lineHeight: 1 }}>{doneN}<span style={{ color: MED }}>/{micro.length}</span></div>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.06em', color: MED, marginTop: 2 }}>DONE</div>
          </div> :
        <button className={'tick' + (t.done ? ' on' : '')} style={{ borderColor: t.done ? ACC : IS_DARK ? '#d6d3ce' : TEXT }} aria-label={t.done ? 'Mark not done' : 'Mark done'} onClick={(e) => { e.stopPropagation(); onToggle(t); }}>
            {t.done && <Ic n="check" sw={2.6} style={{ fontSize: 14, color: '#fff' }} />}
          </button>}
      </div>
      {micro.length > 0 && <>
        <div style={{ height: 3, background: BG, margin: '0 13px', borderRadius: 2 }}><div style={{ width: (doneN / micro.length * 100) + '%', height: '100%', background: ACC, borderRadius: 2 }} /></div>
        <div className="micro">
          {micro.map((m, i) =>
          <div key={i} className="m" role="checkbox" aria-checked={!!m.done} tabIndex={0} onClick={(e) => { e.stopPropagation(); onToggleMicro(t, i); }}
            onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); e.stopPropagation(); onToggleMicro(t, i); } }}>
              <div style={{ width: 16, height: 16, borderRadius: '50%', background: m.done ? ACC : 'transparent', border: `1.5px solid ${m.done ? ACC : '#cfcbc4'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{m.done && <Ic n="check" sw={2.6} style={{ fontSize: 11, color: '#fff' }} />}</div>
              <span style={{ flex: 1, color: m.done ? MED : TEXT, textDecoration: m.done ? 'line-through' : 'none' }}>{m.title}</span>
              {m.minutes > 0 && <span style={{ fontSize: 13, color: MED }}>{fmtDur(m.minutes)}</span>}
            </div>)}
        </div>
      </>}
    </div>);
}

function TaskForm({ s, task, defaults, onSave, onClose }) {
  const ui = useUI();
  const [f, setF] = React.useState(() => task ? { ...task } : { title: '', tag: null, subjectId: defaults.subjectId || null, date: defaults.date, time: defaults.time || null, dur: 30, note: '', ada: false });
  const [timed, setTimed] = React.useState(!!f.time);
  const set = (k, v) => setF((o) => ({ ...o, [k]: v }));
  const subjects = s.subjects.filter((x) => x.semester === s.semester);
  const save = () => {
    if (!f.title.trim()) return;
    onSave({ ...f, title: f.title.trim(), time: timed ? (f.time || '09:00') : null });
  };
  return (
    <Sheet title={task ? 'Edit task' : 'Add task'} onClose={onClose} foot={
      <div className="row" style={{ marginTop: 6 }}>
        <button className="btn block" disabled={!f.title.trim()} onClick={save}>Save</button>
      </div>}>
      <div className="field"><input className="input" autoFocus placeholder="What do you need to do?" value={f.title} onChange={(e) => set('title', e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} /></div>
      <div className="field"><span>Tag · what's this for?</span>
        <div className="chips">
          {s.tags.map((t) =>
          <button key={t.name} className={'chip' + (f.tag === t.name ? ' on' : '')} onClick={() => set('tag', f.tag === t.name ? null : t.name)}>
              <Ic n={'task_' + t.key} style={{ fontSize: 18, color: IS_DARK ? tagInfo(t.key).hue : tagInfo(t.key).ink }} />{t.name}
            </button>)}
        </div>
      </div>
      <div className="field"><span>Subject · link it (optional)</span>
        <div className="chips">
          <button className={'chip' + (!f.subjectId ? ' on' : '')} onClick={() => set('subjectId', null)}>None</button>
          {subjects.map((x) =>
          <button key={x.id} className={'chip' + (f.subjectId === x.id ? ' on' : '')} onClick={() => set('subjectId', x.id)}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: x.color }} />{x.code || x.name}
            </button>)}
          <button className="chip" onClick={() => ui.go('subjects')}>+ Subject</button>
        </div>
      </div>
      <div className="row" style={{ gap: 12, alignItems: 'flex-start', flexWrap: 'wrap' }}>
        <div className="field" style={{ flex: '1 1 180px' }}><span>Date</span><input className="input" type="date" value={f.date} onChange={(e) => e.target.value && set('date', e.target.value)} /></div>
        <div className="field" style={{ flex: '1 1 180px' }}><span>Time of day</span>
          <div className="row" style={{ gap: 8 }}>
            <div className="seg"><button className={!timed ? 'on' : ''} onClick={() => setTimed(false)}>Anytime</button><button className={timed ? 'on' : ''} onClick={() => setTimed(true)}>Set time</button></div>
            {timed && <input className="input" type="time" style={{ width: 130 }} value={f.time || '09:00'} onChange={(e) => set('time', e.target.value)} />}
          </div>
        </div>
      </div>
      <div className="field"><span>Duration</span>
        <div className="chips">
          {[10, 15, 30, 45, 60, 90, 120].map((m) => <button key={m} className={'chip' + (f.dur === m ? ' on' : '')} onClick={() => set('dur', m)}>{fmtDur(m)}</button>)}
        </div>
      </div>
      <div className="field"><span>Note</span><textarea className="area" placeholder="Add a note…" value={f.note || ''} onChange={(e) => set('note', e.target.value)} /></div>
      {!task && <label className="row" style={{ marginBottom: 16, cursor: 'pointer', fontSize: 15, fontWeight: 700 }}>
        <input type="checkbox" checked={!!f.ada} onChange={(e) => set('ada', e.target.checked)} style={{ width: 18, height: 18, accentColor: ACC }} />
        Let Ada break this down into small steps
      </label>}
    </Sheet>);
}

function TaskActions({ s, t, onClose, act }) {
  const sub = t.subjectId && s.subjects.find((x) => x.id === t.subjectId);
  const [pick, setPick] = React.useState(false);
  return (
    <Sheet title={t.title} onClose={onClose}>
      <div className="small" style={{ marginTop: -8, marginBottom: 10 }}>
        {[relDay(t.date), t.time ? fmtTime(t.time) : 'Anytime', fmtDur(t.dur), sub ? sub.code || sub.name : t.tag].filter(Boolean).join(' · ')}
        {t.note ? <div style={{ marginTop: 8, color: TEXT }}>{t.note}</div> : null}
      </div>
      {pick ?
      <div className="card pad" style={{ boxShadow: 'none', background: BG }}>
          <MiniCal value={t.date} onPick={(k) => act('move', t, k)} />
        </div> :
      <div className="actions">
          <button onClick={() => act('toggle', t)}><Ic n="check_circle" style={{ fontSize: 22, color: ACC }} />{t.done ? 'Mark as not done' : 'Mark as done'}</button>
          <button onClick={() => act('focus', t)}><Ic n="focus" style={{ fontSize: 22, color: ACC }} />Start session</button>
          <button onClick={() => setPick(true)}><Ic n="carry_forward" style={{ fontSize: 22, color: ACC }} />Reschedule</button>
          {t.date !== addDays(todayKey(), 1) && <button onClick={() => act('move', t, addDays(todayKey(), 1))}><Ic n="forward" style={{ fontSize: 22, color: ACC }} />Move to tomorrow</button>}
          <button onClick={() => act('breakdown', t)}><Ic n="auto_awesome" style={{ fontSize: 22, color: ACC }} />{t.subtasks && t.subtasks.length ? 'Break down again' : 'Break down with Ada'}</button>
          <button onClick={() => act('edit', t)}><Ic n="edit" style={{ fontSize: 22, color: ACC }} />Edit</button>
          <button className="danger" onClick={() => act('delete', t)}><Ic n="delete" style={{ fontSize: 22, color: '#e85476' }} />Delete</button>
        </div>}
    </Sheet>);
}

function MoodPicker({ value, onPick }) {
  return (
    <div className="row" style={{ justifyContent: 'space-between', gap: 4 }}>
      {MOODS.map((m, i) =>
      <button key={m.label} onClick={() => onPick(i)} style={{ border: 0, background: value === i ? ACCL : 'transparent', borderRadius: 16, padding: '8px 4px 6px', flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
          <MoodBlob idx={i} size={46} />
          <span style={{ fontSize: 13, fontWeight: 700, color: value === i ? ACC : MED }}>{m.label}</span>
        </button>)}
    </div>);
}

function PlanPage({ s, update }) {
  const ui = useUI();
  const [day, setDay] = React.useState(todayKey());
  React.useEffect(() => { ui.ensureWeek && ui.ensureWeek(mondayOf(day)); }, [mondayOf(day)]);
  const [open, setOpen] = React.useState({ anytime: true, planned: true });
  const [menu, setMenu] = React.useState(false);
  const menuRef = useDismiss(menu, () => setMenu(false));
  const [quick, setQuick] = React.useState('');
  const [cal, setCal] = React.useState(false);
  const t0 = todayKey();
  const d = fromKey(day);
  const week = Array.from({ length: 7 }, (_, i) => addDays(mondayOf(day), i));
  const dayTasks = s.tasks.filter((t) => t.date === day);
  const anytime = dayTasks.filter((t) => !t.time).sort((a, b) => a.done - b.done);
  const planned = dayTasks.filter((t) => t.time).sort((a, b) => a.time.localeCompare(b.time));
  const marks = React.useMemo(() => new Set(s.tasks.filter((t) => !t.done).map((t) => t.date)), [s.tasks]);
  const remaining = dayTasks.filter((t) => !t.done);
  const doneToday = s.tasks.filter((t) => t.date === t0 && t.done).length;
  const focusToday = s.sessions.filter((x) => x.date === t0).reduce((a, x) => a + x.minutes, 0);

  const addQuick = () => {
    const title = quick.trim();
    if (!title) return;
    const p = parseLine(title);
    // A day you typed ("fri", "today", "30/11") wins; otherwise it goes on the day you're looking at.
    const hasDate = p.explicit && p.note == null;
    update((st) => ({ ...st, tasks: [...st.tasks, { id: uid(), title: p.title, tag: null, subjectId: null, date: hasDate ? p.date : day, time: p.time, dur: 30, done: false, createdAt: Date.now() }] }));
    setQuick('');
    if (hasDate && p.date !== day) ui.toast(`Added to ${relIn(p.date)}`);
  };

  const grouped = s.settings.grouping === 'list';
  const rowProps = { s, onOpen: ui.openTask, onToggle: ui.toggleTask, onToggleMicro: ui.toggleMicro };

  return (
    <div className="wrap two">
      <div>
        <div className="spread" style={{ position: 'relative' }}>
          <button onClick={() => setCal(!cal)} style={{ border: 0, background: 'none', padding: 0, textAlign: 'left', color: TEXT }}>
            <h1 className="h1">{day === t0 ? DAY_NAMES[d.getDay()] : relDay(day) === 'Tomorrow' || relDay(day) === 'Yesterday' ? relDay(day) : DAY_NAMES[d.getDay()]}</h1>
            <div className="row" style={{ gap: 1, fontSize: 13, fontWeight: 800, color: MED, letterSpacing: '0.04em', marginTop: 4 }}>{d.getDate()} {MONTHS[d.getMonth()]} {d.getFullYear()}<Ic n={cal ? 'expand_more' : 'chevron_right'} style={{ fontSize: 16 }} /></div>
          </button>
          <div className="row" style={{ gap: 8, position: 'relative' }} ref={menuRef}>
            {day !== t0 && <button className="pill" onClick={() => setDay(t0)}>Today</button>}
            <div className="cluster">
              <button className="iconbtn" onClick={() => setMenu(!menu)} aria-label="More" aria-haspopup="menu" aria-expanded={menu}><Ic n="more" style={{ fontSize: 24 }} /></button>
              <button className="iconbtn" onClick={() => ui.newTask({ date: day })} aria-label="Add task"><Ic n="add" style={{ fontSize: 24 }} /></button>
            </div>
          {menu && <div className="menu" role="menu">
            <button onClick={() => { setMenu(false); ui.reschedule(day); }}><Ic n="event_note" style={{ fontSize: 20, color: MED }} />Reschedule tasks</button>
            <button onClick={() => { setMenu(false); ui.logMood(); }}><Ic n="favorite_border" style={{ fontSize: 20, color: MED }} />Log mood</button>
            <button onClick={() => { setMenu(false); update((st) => ({ ...st, settings: { ...st.settings, grouping: grouped ? 'timeline' : 'list' } })); }}><Ic n="list_view" style={{ fontSize: 20, color: MED }} />{grouped ? 'Group by time of day' : 'Group by subject'}</button>
          </div>}
          </div>
        </div>
        {cal && <div className="card pad" style={{ marginTop: 14 }}><MiniCal value={day} marks={marks} onPick={(k) => { setDay(k); setCal(false); }} /></div>}
        <div className="row" style={{ gap: 4 }}>
          <button className="iconbtn" onClick={() => setDay(addDays(day, -7))} aria-label="Previous week"><Ic n="back" style={{ fontSize: 20, color: MED }} /></button>
          <div className="strip" style={{ flex: 1 }}>
            {week.map((k) => {
              const dd = fromKey(k);
              return (
                <button key={k} className={'day' + (k === day ? ' sel' : '') + (k === t0 ? ' today' : '')} onClick={() => setDay(k)}>
                  <small>{dd.getDate()}</small><b>{'MTWTFSS'[(dd.getDay() + 6) % 7]}</b><i className={marks.has(k) ? '' : 'none'} />
                </button>);
            })}
          </div>
          <button className="iconbtn" onClick={() => setDay(addDays(day, 7))} aria-label="Next week"><Ic n="chevron_right" style={{ fontSize: 20, color: MED }} /></button>
        </div>

        {grouped ?
        <SubjectGroups s={s} tasks={dayTasks} rowProps={rowProps} /> :
        <>
          <div style={{ marginBottom: 10 }}><Collapse icon="schedule" label="ANYTIME" count={anytime.length} open={open.anytime} onClick={() => setOpen({ ...open, anytime: !open.anytime })} /></div>
          {open.anytime && <div>{anytime.map((t) => <TaskRow key={t.id} t={t} {...rowProps} />)}</div>}
          <div className="addrow">
            <span className="dot6" />
            <input placeholder={anytime.length ? 'Add a task for anytime' : 'Add one small thing, e.g. "Read chapter 4 fri"'} value={quick} onChange={(e) => setQuick(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') addQuick(); }} />
            <button className="plus" onClick={quick.trim() ? addQuick : () => ui.newTask({ date: day })} aria-label="Add">+</button>
          </div>
          <div style={{ margin: '10px 0 2px' }}><Collapse label="PLANNED" count={planned.length} open={open.planned} onClick={() => setOpen({ ...open, planned: !open.planned })} /></div>
          {open.planned && planned.map((t, i) =>
          <div key={t.id}>
              {(i === 0 || planned[i - 1].time !== t.time) && <div className="timelabel">{fmtTime(t.time)}</div>}
              <TaskRow t={t} {...rowProps} />
            </div>)}
          <button className="addrow" style={{ cursor: 'pointer', width: '100%', border: 0, background: 'none', textAlign: 'left' }} onClick={() => ui.newTask({ date: day, time: '09:00' })}>
            <span className="dot6" /><span style={{ flex: 1, fontSize: 17, color: DIM, fontWeight: 600 }}>Add a planned task</span><span className="plus" aria-hidden="true">+</span>
          </button>
          {dayTasks.length === 0 &&
          <div className="empty">
              <CubeSVG size={70} tone={CUBE_TONES[4]} melt={0} expr="smile" bubbles={3} />
              <div style={{ fontSize: 17, fontWeight: 800, marginTop: 10 }}>Nothing planned yet</div>
              <div className="small" style={{ maxWidth: 320, margin: '4px auto 14px' }}>Add one small thing above, or let Ada lay out your week.</div>
              <button className="btn sm ghost" onClick={() => ui.askAda('Plan my week')}>Plan my week with Ada</button>
            </div>}
        </>}
      </div>

      <aside className="rail">
        <div className="card pad"><MiniCal value={day} marks={marks} onPick={setDay} /></div>
        <div className="card pad">
          <div className="label" style={{ margin: '0 0 12px' }}>Today</div>
          <div className="row" style={{ gap: 18 }}>
            <div><b style={{ fontSize: 28, fontWeight: 800 }}>{doneToday}</b><div className="small">done</div></div>
            <div><b style={{ fontSize: 28, fontWeight: 800 }}>{fmtDur(focusToday) || '0m'}</b><div className="small">focused</div></div>
            <div><b style={{ fontSize: 28, fontWeight: 800 }}>{remaining.length}</b><div className="small">left {day === t0 ? 'today' : 'that day'}</div></div>
          </div>
          <button className="btn block sm" style={{ marginTop: 14 }} onClick={() => ui.go('focus')}><Ic n="play" style={{ fontSize: 18, color: '#fff' }} />Start a focus session</button>
        </div>
        <div className="card pad">
          <div className="label" style={{ margin: '0 0 10px' }}>How are you feeling?</div>
          <MoodPicker value={s.moods[t0]} onPick={(i) => { update((st) => ({ ...st, moods: { ...st.moods, [t0]: i } })); ui.toast('Mood logged'); }} />
        </div>
      </aside>
    </div>);
}

function SubjectGroups({ s, tasks, rowProps }) {
  const groups = {};
  tasks.forEach((t) => { const k = t.subjectId || '_'; (groups[k] = groups[k] || []).push(t); });
  const keys = Object.keys(groups).sort((a, b) => a === '_' ? 1 : b === '_' ? -1 : 0);
  if (!tasks.length) return <div className="empty small">Nothing on this day.</div>;
  return keys.map((k) => {
    const sub = s.subjects.find((x) => x.id === k);
    return (
      <div key={k} style={{ marginBottom: 14 }}>
        <div className="timelabel" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: sub ? sub.color : DIM }} />{sub ? `${sub.code ? sub.code + ' · ' : ''}${sub.name}` : 'No subject'}
        </div>
        {groups[k].sort((a, b) => (a.time || '99').localeCompare(b.time || '99')).map((t) => <TaskRow key={t.id} t={t} {...rowProps} />)}
      </div>);
  });
}

function RescheduleSheet({ s, day, onClose, onMove }) {
  const left = s.tasks.filter((t) => t.date === day && !t.done);
  const [sel, setSel] = React.useState(() => new Set(left.map((t) => t.id)));
  const [to, setTo] = React.useState(addDays(day, 1));
  return (
    <Sheet title="Remaining tasks" onClose={onClose}>
      <div className="small" style={{ marginTop: -8, marginBottom: 12 }}>{relDay(day)} · move {sel.size} to {relIn(to)}?</div>
      {left.length === 0 ? <div className="empty small">Everything on this day is done.</div> :
      <div className="group" style={{ boxShadow: 'none', background: BG, marginBottom: 14 }}>
          {left.map((t) =>
          <button key={t.id} className="srow" onClick={() => { const n = new Set(sel); n.has(t.id) ? n.delete(t.id) : n.add(t.id); setSel(n); }}>
              <Ic n={sel.has(t.id) ? 'check_circle' : 'radio_button_unchecked'} fill={sel.has(t.id)} style={{ fontSize: 22, color: sel.has(t.id) ? ACC : DIM }} />
              <span>{t.title}<span className="d">{t.time ? fmtTime(t.time) : 'Anytime'} · {fmtDur(t.dur)}</span></span>
            </button>)}
        </div>}
      <div className="field"><span>Move to</span><input className="input" type="date" value={to} onChange={(e) => e.target.value && setTo(e.target.value)} /></div>
      <button className="btn block" disabled={!sel.size} onClick={() => onMove([...sel], to)}>Move {sel.size} to {relIn(to)}</button>
    </Sheet>);
}
