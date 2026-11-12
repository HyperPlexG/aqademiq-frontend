/* ─── SIGNED IN: your Aqademiq account, same as the phone ────────────────
   The pages keep using one state object and update(); signed in, every
   change is turned into the API call the phone makes (POST/PATCH/DELETE),
   one at a time, in order. Server ids replace the page's own as they come
   back. Days are fetched per day: the API's range listing leaves undated
   one-off tasks without their date. */

const ACCT_CACHE = (id) => 'aq-web-acct-' + id;
const CONSENT_VERSION = '2026-07-01';
const feelToMood = (f) => ({ 'Love it': 4, Great: 3, OK: 2, 'Dread it': 0 })[f] ?? 2;
const moodToFeel = (m) => m == null ? 'OK' : m >= 4 ? 'Love it' : m === 3 ? 'Great' : m === 2 ? 'OK' : 'Dread it';
const isUuidish = (x) => /^[0-9a-f]{8}-[0-9a-f]{4}-/i.test(String(x || ''));
const targetTypeOf = (t) => /%$/.test(t || '') ? '%' : /^\d(\.\d+)?$/.test(t || '') ? 'GPA' : 'Grade';
const tagKeyFor = (label) => AQ_TAG[label] || (EXTRA_TAG_ICONS.includes(String(label).toLowerCase()) ? String(label).toLowerCase() : 'class');

function taskFromApi(o, day, meta) {
  const tag = meta.tagsById[o.category] || meta.tagsByLabel[String(o.category || '').toLowerCase()];
  return {
    id: o.id, title: o.title, subjectId: o.subject_id || null, date: day,
    time: o.scheduled_at ? o.scheduled_at.slice(11, 16) : null,
    dur: Math.max(0, Math.round((o.duration_seconds || 0) / 60)), done: o.status === 'COMPLETE',
    tag: tag ? tag.label : null, note: o.note || '',
    subtasks: (o.steps || []).map((st) => ({ id: st.id, title: st.title, minutes: Math.round((st.duration_seconds || 0) / 60), done: st.status === 'COMPLETE' })),
    repeat: o.repeat && o.repeat.kind && o.repeat.kind !== 'none' ? o.repeat : null,
  };
}
function subjectFromApi(x, semName) {
  return { id: x.id, code: x.code || '', name: x.name, credits: x.credits ?? 3, color: x.color_hex || '#6b5cf0', targetType: targetTypeOf(x.target_grade), target: x.target_grade || 'A', prof: x.prof || '', feeling: moodToFeel(x.mood), semester: semName(x.semester_id), semesterId: x.semester_id };
}
const subjectBody = (x, semId, patch) => ({
  name: x.name, color_hex: x.color, mood: feelToMood(x.feeling),
  // On an edit, empty strings clear a code or professor; on create, leave them out.
  ...(patch ? { code: x.code || '', prof: x.prof || '' } : { ...(x.code ? { code: x.code } : {}), ...(x.prof ? { prof: x.prof } : {}) }),
  ...(Number(x.credits) ? { credits: Number(x.credits) } : {}), ...(x.target ? { target_grade: x.target } : {}),
  ...(semId ? { semester_id: semId } : {}),
});

function useAccountStore(session, guestSettings, onError) {
  const uid = session ? session.user.id : null;
  const [s, setS] = React.useState(null);
  const [status, setStatus] = React.useState('idle'); // idle | loading | ready | error
  const sRef = React.useRef(null);
  const meta = React.useRef(null);
  const err = React.useRef(onError); err.current = onError;

  // Every async path checks it still belongs to this signed-in session (m0), so
  // a reply that lands after signing out or switching account is dropped.
  const live = (m0) => !!m0 && meta.current === m0;
  const commit = (next, m0) => {
    if (m0 && !live(m0)) return;
    sRef.current = next; setS(next);
    if (uid) { try { localStorage.setItem(ACCT_CACHE(uid), JSON.stringify(next)); } catch (e) { /* full or blocked */ } }
  };
  const applyServer = (fn, m0) => { const m = m0 || meta.current; if (sRef.current && live(m)) commit(fn(sRef.current), m); };
  const OCC_KEY = uid ? ACCT_CACHE(uid) + '-occ' : null;
  const saveOcc = (m) => { if (OCC_KEY && live(m)) { try { localStorage.setItem(OCC_KEY, JSON.stringify(m.occOf)); } catch (e) { /* full or blocked */ } } };
  const resolve = (id) => { const m = meta.current; let x = id, n = 0; while (m && m.idMap[x] && n++ < 8) x = m.idMap[x]; return x; };
  // Server ids replace the page's own (and an occurrence's child override replaces the occurrence).
  const replaceId = (from, to) => {
    const m = meta.current;
    if (!m || !from || !to || from === to) return;
    const cur = resolve(from), hit = (x) => !!x && (x === from || x === cur);
    for (const k in m.idMap) if (hit(m.idMap[k])) m.idMap[k] = to;
    m.idMap[from] = to; if (cur !== from && cur !== to) m.idMap[cur] = to;
    m.known.add(to);
    // A day of a series ("<id>@<date>") that just got its own row: remember which
    // day it was, so moving that row later can clear the day it left (see push).
    const occ = [from, cur].find((x) => String(x).includes('@'));
    if (occ && !String(to).includes('@')) { m.occOf[to] = m.occOf[cur] || occ; saveOcc(m); }
    applyServer((st) => ({
      ...st,
      tasks: st.tasks.map((t) => hit(t.id) ? { ...t, id: to } : hit(t.subjectId) ? { ...t, subjectId: to } : t),
      subjects: st.subjects.map((x) => hit(x.id) ? { ...x, id: to } : x),
      focus: hit(st.focus.taskId) ? { ...st.focus, taskId: to } : st.focus,
      sessions: st.sessions.map((x) => hit(x.taskId) ? { ...x, taskId: to } : x),
    }), m);
  };

  /* ── reading ── */
  async function fetchDays(days) {
    const m = meta.current, out = [];
    for (let i = 0; i < days.length; i += 6) {
      const batch = days.slice(i, i + 6);
      const res = await Promise.all(batch.map((d) => api('GET', '/tasks?date=' + d)));
      res.forEach((r, k) => (r.tasks || []).forEach((o) => out.push(taskFromApi(o, batch[k], m))));
    }
    // One task, one day: if the API lists an id on two days, keep the later one.
    const seen = new Map();
    out.forEach((t) => { const had = seen.get(t.id); if (!had || had.date < t.date) seen.set(t.id, t); });
    return [...seen.values()];
  }
  async function fetchWeek(mon) {
    const days = Array.from({ length: 7 }, (_, i) => addDays(mon, i));
    const [tasks, mood] = await Promise.all([fetchDays(days), api('GET', '/mood-entries/week?date=' + mon).catch(() => null)]);
    const moods = {};
    ((mood && mood.days) || []).forEach((d) => { if (d.mood_index != null) moods[d.date] = d.mood_index; });
    return { days, tasks, moods };
  }
  function mergeWeek(st, w, m) {
    const inWeek = new Set(w.days);
    // Keep tasks outside these days, and ones made here that the server hasn't confirmed yet.
    const keepLocal = st.tasks.filter((t) => !inWeek.has(t.date) || !m.known.has(t.id));
    w.tasks.forEach((t) => m.known.add(t.id));
    const ids = new Set(w.tasks.map((t) => t.id));
    const moods = { ...st.moods };
    w.days.forEach((d) => { delete moods[d]; });
    return { ...st, tasks: [...keepLocal.filter((t) => !ids.has(t.id)), ...w.tasks], moods: { ...moods, ...w.moods } };
  }
  async function loadAll(soft) {
    const m0 = meta.current;
    if (!uid || !m0) return;
    const rev0 = m0.rev, wk0 = new Set(m0.weeks);
    if (!soft) setStatus('loading');
    try {
      const [profile, subj, sems, tags, focus] = await Promise.all([
        api('GET', '/profile'), api('GET', '/subjects'), api('GET', '/semesters').catch(() => ({ semesters: [] })),
        api('GET', '/study-tags'), api('GET', `/focus-sessions?from=${addDays(todayKey(), -91)}&to=${todayKey()}`).catch(() => ({ sessions: [] })),
      ]);
      const t0 = todayKey(), mon = mondayOf(t0);
      const weeks = soft && wk0.size ? [...wk0] : [-2, -1, 0, 1, 2].map((k) => addDays(mon, k * 7));
      const ws = await Promise.all(weeks.map(fetchWeek));
      if (!live(m0)) return; // signed out or switched account meanwhile
      // An edit made while this was loading wins: load again once it has been sent.
      if (m0.rev !== rev0) { m0.queue = m0.queue.then(() => loadAll(true)); return; }
      m0.tagsById = {}; m0.tagsByLabel = {};
      (tags.tags || []).forEach((t) => { m0.tagsById[t.id] = t; m0.tagsByLabel[t.label.toLowerCase()] = t; });
      const semList = sems.semesters || [];
      m0.semIds = {}; semList.forEach((x) => { m0.semIds[x.name] = x.id; });
      const semName = (id) => (semList.find((x) => x.id === id) || {}).name || (semList.find((x) => x.is_active) || {}).name || semesterNow();
      const active = (semList.find((x) => x.is_active) || semList[0] || {}).name || semesterNow();
      const extra = [...m0.weeks].filter((w) => !weeks.includes(w)); // opened while loading
      m0.weeks = new Set(weeks); m0.known = new Set();
      const cur = sRef.current || normalize(null);
      let next = {
        ...cur, v: 1, account: true,
        profile: { ...cur.profile, name: profile.name || '', email: profile.email || session.user.email || '', university: profile.university || '', program: profile.program || '', onboarded: !!(profile.onboarding_complete || profile.is_guest) },
        settings: { ...(cur.account ? cur.settings : guestSettings) },
        tags: (tags.tags || []).map((t) => ({ name: t.label, key: tagKeyFor(t.label), id: t.id })),
        semesters: semList.length ? semList.map((x) => x.name) : [active], semester: active,
        subjects: (subj.subjects || []).map((x) => subjectFromApi(x, semName)),
        // Local day of the session, not the UTC one.
        sessions: (focus.sessions || []).map((x) => ({ id: x.id, date: dkey(new Date(x.started_at || x.created_at || Date.now())), minutes: x.actual_duration_mins ?? Math.round((x.elapsed_sec || 0) / 60), taskId: x.task_id || null, subjectId: x.course_id || null, mood: null })).reverse(),
        tasks: [], moods: {},
      };
      ws.forEach((w) => { next = mergeWeek(next, w, m0); });
      commit(next, m0);
      m0.loadedAt = Date.now();
      setStatus('ready');
      extra.forEach((w) => ensureWeek(w));
    } catch (e) {
      if (!live(m0)) return;
      if (e && e.status === 401) { try { await SB.client.auth.signOut(); } catch (x) { /* ignore */ } return; }
      if (!soft) setStatus(sRef.current ? 'ready' : 'error');
      err.current('Couldn\'t load your account. ' + (e && e.status ? 'Try again in a moment.' : 'Check your connection.'));
    }
  }
  // Reloads wait behind any changes still being sent.
  const reload = () => { const m = meta.current; if (!m) return Promise.resolve(); const p = m.queue.then(() => loadAll(true)); m.queue = p.catch(() => {}); return p; };
  async function ensureWeek(mon) {
    const m = meta.current;
    if (!m || m.weeks.has(mon)) return;
    m.weeks.add(mon);
    try { const w = await fetchWeek(mon); applyServer((st) => mergeWeek(st, w, m), m); } catch (e) { if (live(m)) m.weeks.delete(mon); }
  }
  async function refreshDays(days) {
    const m = meta.current;
    try {
      const fresh = await fetchDays(days);
      fresh.forEach((t) => m.known.add(t.id));
      const set = new Set(days);
      applyServer((st) => ({ ...st, tasks: [...st.tasks.filter((t) => !set.has(t.date) || !m.known.has(t.id)).filter((t) => !fresh.some((f) => f.id === t.id)), ...fresh] }), m);
    } catch (e) { /* the next refresh catches up */ }
  }
  // After steps are written to an occurrence ("id@date"), the server keeps them on a
  // new child row: find it and use its id from then on.
  async function childAfterSteps(id, date, steps) {
    if (!String(id).includes('@') || !steps.length) return id;
    const day = await api('GET', '/tasks?date=' + date);
    const o = (day.tasks || []).find((x) => (x.steps || []).some((st) => st.id === steps[0].id));
    if (o && o.id !== id) { replaceId(id, o.id); return o.id; }
    return id;
  }

  /* ── writing: diff the change, send what the phone would, one at a time ── */
  const enqueue = (job) => {
    const m = meta.current;
    m.pending++;
    m.queue = m.queue.then(job).catch((e) => {
      if (!live(m)) return;
      console.warn('[aqademiq] sync failed', e && e.status, e && (e.body || e.message));
      err.current(e && e.status === 422 ? (e.body && e.body.message) || 'That change wasn\'t accepted.' : 'Couldn\'t save that to your account. Syncing again.');
      m.queue = m.queue.then(() => loadAll(true)).catch(() => {});
    }).finally(() => { m.pending--; });
  };
  function update(fn) {
    const prev = sRef.current, m = meta.current;
    if (!prev || !m) return;
    const next = { ...(typeof fn === 'function' ? fn(prev) : fn), updatedAt: Date.now() };
    m.rev++;
    commit(next, m);
    enqueue(() => push(prev, next, m));
  }
  async function push(a, b, m) {
    if (!live(m)) return;
    // profile
    const pf = {};
    ['name', 'university', 'program'].forEach((k) => { if ((a.profile[k] || '') !== (b.profile[k] || '')) pf[k] = b.profile[k] || ''; });
    if (Object.keys(pf).length) await api('PATCH', '/profile', pf);
    // semesters
    for (const name of b.semesters) if (!a.semesters.includes(name) && !m.semIds[name]) {
      const r = await api('POST', '/semesters', { name, start: todayKey(), end: addDays(todayKey(), 182) }); m.semIds[name] = r.id;
    }
    if (a.semester !== b.semester && m.semIds[b.semester]) await api('PATCH', `/semesters/${m.semIds[b.semester]}/activate`);
    // tags (by label)
    const al = new Set(a.tags.map((t) => t.name.toLowerCase())), bl = new Set(b.tags.map((t) => t.name.toLowerCase()));
    for (const t of b.tags) if (!al.has(t.name.toLowerCase())) { const r = await api('POST', '/study-tags', { label: t.name }); m.tagsById[r.id] = r; m.tagsByLabel[r.label.toLowerCase()] = r; }
    for (const t of a.tags) if (!bl.has(t.name.toLowerCase())) {
      await api('DELETE', '/study-tags/' + encodeURIComponent(t.name));
      const old = m.tagsByLabel[t.name.toLowerCase()];
      if (old) { delete m.tagsById[old.id]; delete m.tagsByLabel[t.name.toLowerCase()]; }
    }
    const catOf = (label) => { const t = label && m.tagsByLabel[label.toLowerCase()]; return t ? t.id : 'general'; };
    // subjects
    const as = new Map(a.subjects.map((x) => [x.id, x])), bs = new Map(b.subjects.map((x) => [x.id, x]));
    for (const x of b.subjects) {
      const p = as.get(x.id), semId = m.semIds[x.semester];
      if (!p) { const r = await api('POST', '/subjects', subjectBody(x, semId)); replaceId(x.id, r.id); }
      else if (JSON.stringify(p) !== JSON.stringify(x)) await api('PATCH', '/subjects/' + resolve(x.id), subjectBody(x, semId, true));
    }
    for (const x of a.subjects) if (!bs.has(x.id)) await api('DELETE', '/subjects/' + resolve(x.id));
    // tasks
    const at = new Map(a.tasks.map((t) => [t.id, t])), bt = new Map(b.tasks.map((t) => [t.id, t]));
    for (const t of b.tasks) {
      const p = at.get(t.id);
      if (!p) {
        // Exactly as the phone creates tasks: a series with repeat "none", so
        // moving it later carries its time to the new day (POST /tasks/move).
        const body = { title: t.title, date: t.date, duration_seconds: Math.max(60, (t.dur || 30) * 60), category: catOf(t.tag), part_of_day: 'anytime', repeat: { kind: 'none' } };
        if (t.time) body.scheduled_at = `${t.date}T${t.time}:00`;
        if (t.subjectId) body.subject_id = resolve(t.subjectId);
        if (t.note) body.note = t.note;
        const r = await api('POST', '/tasks', body);
        replaceId(t.id, r.id);
        let id = r.id;
        if (t.done) { const r2 = await api('PATCH', '/tasks/' + id, { status: 'COMPLETE' }); if (r2 && r2.id && r2.id !== id) { replaceId(id, r2.id); id = r2.id; } }
        if (t.subtasks && t.subtasks.length) await sendSteps(id, t);
        continue;
      }
      if (JSON.stringify(p) === JSON.stringify(t)) continue;
      let id = resolve(t.id);
      // Field edits first, on the occurrence where they were made…
      const patch = {};
      if (p.title !== t.title) patch.title = t.title;
      if ((p.note || '') !== (t.note || '')) patch.note = t.note || '';
      if (p.dur !== t.dur) patch.duration_seconds = Math.max(60, (t.dur || 30) * 60);
      if (p.time !== t.time) patch.scheduled_at = t.time ? `${p.date}T${t.time}:00` : '';
      if (p.tag !== t.tag) patch.category = catOf(t.tag);
      if (p.subjectId !== t.subjectId) patch.subject_id = t.subjectId ? resolve(t.subjectId) : null;
      if (p.done !== t.done) patch.status = t.done ? 'COMPLETE' : 'PENDING';
      if (Object.keys(patch).length) { const r = await api('PATCH', '/tasks/' + id, patch); if (r && r.id && r.id !== id) { replaceId(id, r.id); id = r.id; } }
      const ps = p.subtasks || [], ns = t.subtasks || [];
      const sameSteps = ps.length === ns.length && ps.every((x, i) => x.title === ns[i].title);
      if (!sameSteps) id = await sendSteps(id, t, p.date);
      else for (let i = 0; i < ns.length; i++) if (!!ps[i].done !== !!ns[i].done && ns[i].id) await api('PATCH', `/tasks/${id}/steps/${ns[i].id}`, { done: !!ns[i].done });
      // …then the move, so nothing typed in the same edit is lost.
      if (p.date !== t.date) {
        await api('POST', '/tasks/move', { from: p.date, to: t.date, ids: [id] });
        // A day of a series that has its own row (edited, ticked, broken down) is
        // moved as that row, and the server can leave the series showing on the
        // old day. Clear that day; where the server already did, this changes nothing.
        const occ = m.occOf[id];
        if (occ && occ.endsWith('@' + p.date)) {
          await api('DELETE', '/tasks/' + occ).catch(() => {});
          delete m.occOf[id]; saveOcc(m);
        }
        // For a plain (non-series) timed task the API moves only the day, not the time: carry it over.
        if (t.time && !String(id).includes('@')) await api('PATCH', '/tasks/' + id, { scheduled_at: `${t.date}T${t.time}:00` });
        await refreshDays([p.date, t.date]); // a series' moved day gets a new id
      }
    }
    for (const t of a.tasks) if (!bt.has(t.id)) await api('DELETE', '/tasks/' + resolve(t.id));
    // moods (keep any intention written on the phone)
    for (const d of Object.keys(b.moods)) if (a.moods[d] !== b.moods[d]) {
      const cur = await api('GET', '/mood-entries/' + d).catch(() => ({}));
      await api('POST', '/mood-entries', { date: d, mood_index: b.moods[d], ...(cur && cur.intention ? { intention: cur.intention } : {}) });
    }
    // focus session lifecycle
    const fa = a.focus, fb = b.focus;
    if (fa.status !== fb.status) {
      if (fb.status === 'running' && (fa.status === 'idle' || fa.status === 'done')) {
        const label = fb.prism || (b.settings.prism && b.settings.prism.mode) || 'none';
        const r = await api('POST', '/focus-sessions', { planned_min: Math.min(120, Math.max(5, Math.round(fb.total / 60))), prism_mode: label === PRISM_OFF ? 'none' : label, task_id: fb.taskId ? resolve(fb.taskId) : undefined, engine_version: 'prism-web-1' });
        // The server's Prism holdout: these sessions run without sound.
        applyServer((st) => ({ ...st, focus: { ...st.focus, serverId: r.id, ...(r.control_arm ? { prism: PRISM_OFF } : {}) } }), m);
      } else if ((sRef.current && sRef.current.focus.serverId) || fa.serverId) {
        const sid = (sRef.current && sRef.current.focus.serverId) || fa.serverId;
        const elapsed = Math.max(0, fb.total - (fb.status === 'running' ? Math.round((fb.endsAt - Date.now()) / 1000) : fb.remaining));
        if (fb.status === 'frozen') await api('PATCH', '/focus-sessions/' + sid, { status: 'PAUSED', elapsed_sec: elapsed });
        else if (fb.status === 'running') await api('PATCH', '/focus-sessions/' + sid, { status: 'RUNNING' });
        else if (fb.status === 'done') {
          const last = b.sessions[b.sessions.length - 1];
          const r = await api('POST', `/focus-sessions/${sid}/complete`, { elapsed_sec: Math.max(0, (last ? last.minutes : 0) * 60) });
          applyServer((st) => ({ ...st, focus: { ...st.focus, serverId: null }, sessions: st.sessions.map((x, i) => i === st.sessions.length - 1 ? { ...x, id: r.id || x.id } : x) }), m);
          // Completing a linked session ticks its task on the server: show it.
          const lt = fb.taskId && b.tasks.find((x) => x.id === fb.taskId);
          if (r && r.linked_task) await refreshDays([lt ? lt.date : todayKey()]);
        }
      }
    }
  }
  async function sendSteps(id, t, onDate) {
    const date = onDate || t.date;
    const r = await api('POST', `/tasks/${id}/breakdown`, { date, steps: (t.subtasks || []).map((x) => ({ title: x.title, duration_seconds: Math.max(0, (x.minutes || 0) * 60) })) });
    const steps = (r.steps || []).map((st, i) => ({ id: st.id, title: st.title, minutes: Math.round((st.duration_seconds || 0) / 60), done: !!(t.subtasks[i] && t.subtasks[i].done) }));
    applyServer((st) => ({ ...st, tasks: st.tasks.map((x) => x.id === t.id || x.id === id ? { ...x, subtasks: steps } : x) }));
    const cid = await childAfterSteps(id, date, steps);
    for (const x of steps) if (x.done) await api('PATCH', `/tasks/${cid}/steps/${x.id}`, { done: true });
    return cid;
  }

  // Ada breaks a task down on the server, like the phone. In line behind any
  // pending save, so a task created a moment ago has its server id.
  function breakdown(t) {
    return new Promise((res, rej) => {
      const m = meta.current;
      const p = m.queue.then(async () => {
        try {
          const id = resolve(t.id);
          const r = await api('POST', `/tasks/${id}/breakdown`, { date: t.date });
          const steps = (r.steps || []).map((st) => ({ id: st.id, title: st.title, minutes: Math.round((st.duration_seconds || 0) / 60), done: st.status === 'COMPLETE' }));
          applyServer((st) => ({ ...st, tasks: st.tasks.map((x) => x.id === t.id || x.id === id ? { ...x, subtasks: steps, done: false } : x) }), m);
          await childAfterSteps(id, t.date, steps);
          res(steps.length);
        } catch (e) { rej(e); }
      });
      m.queue = p.catch(() => {});
    });
  }
  // Which of these are already in the account (so the review can say so up front).
  const extId = (x) => x.key.replace(/^(ics|paste):/, '').replace(/:(\d{4}-\d{2}-\d{2})$/, '@$1').slice(0, 400);
  async function importCheck(list, source) {
    const src = source === 'Calendar' ? 'ics' : 'text', have = new Set();
    for (let i = 0; i < list.length; i += 1000) {
      const part = list.slice(i, i + 1000);
      const r = await api('POST', '/integrations/import/check', { source: src, external_ids: part.map(extId) });
      const ex = new Set(r.existing || []);
      part.forEach((x) => { if (ex.has(extId(x))) have.add(x.key); });
    }
    return have;
  }
  // Calendar / reminder import goes through the same endpoint as the phone.
  async function importItems(list, tag, source) {
    const m = meta.current, cat = tag && m.tagsByLabel[tag.toLowerCase()] ? m.tagsByLabel[tag.toLowerCase()].id : undefined;
    let imported = 0, skipped = 0;
    for (let i = 0; i < list.length; i += 200) {
      const items = list.slice(i, i + 200).map((x) => ({
        external_id: extId(x),
        title: x.title.slice(0, 255), date: x.date, ...(x.time ? { start_time: x.time } : {}),
        ...(x.dur ? { duration_seconds: x.dur * 60 } : {}), part_of_day: 'anytime',
      }));
      const r = await api('POST', '/integrations/import', { source: source === 'Calendar' ? 'ics' : 'text', ...(cat ? { category: cat } : {}), items });
      imported += r.imported || 0; skipped += r.skipped || 0;
    }
    const days = [...new Set(list.map((x) => x.date))].filter((d) => [...m.weeks].some((w) => d >= w && d <= addDays(w, 6)));
    if (days.length) await refreshDays(days);
    return { imported, skipped };
  }
  // Guest plan from this browser → the account. onItem(kind, id) after each one,
  // so a retry after a failure never sends the same item twice.
  async function bringOver(g, onItem) {
    const m = meta.current, subjMap = {};
    for (const x of g.subjects) { const r = await api('POST', '/subjects', subjectBody(x)); subjMap[x.id] = r.id; onItem('subject', x.id); }
    for (const t of g.tasks) {
      const tg = t.tag && m.tagsByLabel[t.tag.toLowerCase()];
      const body = { title: t.title, date: t.date, duration_seconds: Math.max(60, (t.dur || 30) * 60), category: tg ? tg.id : 'general', part_of_day: 'anytime', repeat: { kind: 'none' } };
      if (t.time) body.scheduled_at = `${t.date}T${t.time}:00`;
      if (t.subjectId && subjMap[t.subjectId]) body.subject_id = subjMap[t.subjectId];
      if (t.note) body.note = t.note;
      const r = await api('POST', '/tasks', body);
      if (t.done) await api('PATCH', '/tasks/' + r.id, { status: 'COMPLETE' });
      onItem('task', t.id);
    }
    for (const [d, v] of Object.entries(g.moods || {})) if (d <= todayKey()) { await api('POST', '/mood-entries', { date: d, mood_index: v }).catch(() => {}); onItem('mood', d); }
    await reload();
  }

  // Start / stop with the session.
  React.useEffect(() => {
    if (!uid) { meta.current = null; sRef.current = null; setS(null); setStatus('idle'); return; }
    const m = { weeks: new Set(), known: new Set(), tagsById: {}, tagsByLabel: {}, semIds: {}, idMap: {}, occOf: {}, pending: 0, rev: 0, queue: Promise.resolve(), loadedAt: 0 };
    try { m.occOf = JSON.parse(localStorage.getItem(ACCT_CACHE(uid) + '-occ') || '{}') || {}; } catch (e) { m.occOf = {}; }
    meta.current = m;
    let cached = null;
    try { cached = JSON.parse(localStorage.getItem(ACCT_CACHE(uid)) || 'null'); } catch (e) { cached = null; }
    if (cached) { const c = normalize(cached); c.account = true; sRef.current = c; setS(c); setStatus('ready'); } else { sRef.current = null; setS(null); }
    loadAll(!!cached);
    // Back to this tab: pick up what the phone changed (after anything still being sent).
    const vis = () => { if (document.visibilityState === 'visible' && live(m) && !m.pending && Date.now() - m.loadedAt > 30000) { m.loadedAt = Date.now(); reload(); } };
    // Closing the tab while a change is still being sent would lose it: ask first.
    const leave = (e) => { if (live(m) && m.pending) { e.preventDefault(); e.returnValue = ''; } };
    document.addEventListener('visibilitychange', vis);
    window.addEventListener('beforeunload', leave);
    return () => { document.removeEventListener('visibilitychange', vis); window.removeEventListener('beforeunload', leave); if (meta.current === m) meta.current = null; };
  }, [uid]);

  return { s, status, update, applyServer, ensureWeek, breakdown, importItems, importCheck, bringOver, reload };
}

/* ── onboarding for an account that hasn't finished it (age + consent are required by the API) ── */
function AccountOnboarding({ s, onDone, onSignOut }) {
  const [step, setStep] = React.useState(1);
  const [age, setAge] = React.useState('');
  const [consent, setConsent] = React.useState(null);
  const [name, setName] = React.useState(s.profile.name || '');
  const [level, setLevel] = React.useState('Undergraduate');
  const [subs, setSubs] = React.useState([]);
  const [code, setCode] = React.useState('');
  const [sname, setSname] = React.useState('');
  const [busy, setBusy] = React.useState(false);
  const [err, setErr] = React.useState('');
  const ageN = parseInt(age, 10);
  const addSub = () => { if (!sname.trim()) return; setSubs([...subs, { code: code.trim(), name: sname.trim() }]); setCode(''); setSname(''); };
  const finish = async () => {
    setBusy(true); setErr('');
    const all = [...subs, ...(sname.trim() ? [{ code: code.trim(), name: sname.trim() }] : [])];
    try {
      await api('POST', '/onboarding/complete', {
        consent_given: true, consent_version: CONSENT_VERSION, age: ageN, name: name.trim() || undefined, education_level: level,
        subjects: all.map((x, i) => ({ name: x.name, color_hex: SUBJECT_COLORS[i % SUBJECT_COLORS.length], mood: 2 })),
      });
      // Codes aren't part of onboarding: set them on the new subjects.
      if (all.some((x) => x.code)) {
        const list = (await api('GET', '/subjects')).subjects || [];
        for (const x of all) if (x.code) { const hit = list.find((y) => y.name === x.name && !y.code); if (hit) await api('PATCH', '/subjects/' + hit.id, { code: x.code }).catch(() => {}); }
      }
      await onDone(); // stays busy until the account reloads, so Finish can't send twice
    } catch (e) { setErr(e && e.status === 403 ? 'Aqademiq needs your consent and an age of 18 or over to continue.' : authMessage(e)); }
    finally { setBusy(false); }
  };
  const dots = <div className="dots" aria-label={`Step ${step} of 4`}>{[1, 2, 3, 4].map((i) => <i key={i} className={step === i ? 'on' : ''} />)}</div>;
  return (
    <div className="ob">
      <div className="ob-card">
        <div className="spread" style={{ marginBottom: 6 }}><span className="small">{s.profile.email}</span><button className="link" style={{ fontSize: 13 }} onClick={onSignOut}>Sign out</button></div>
        {step === 1 && <div>
          {dots}
          <h1 className="h1">How old<br />are you?</h1>
          <div className="sub" style={{ margin: '6px 0 20px' }}>Ada tunes pacing and check-ins to your age.</div>
          <input className="input" inputMode="numeric" maxLength={3} autoFocus placeholder="Age" value={age} onChange={(e) => setAge(e.target.value.replace(/\D/g, '').slice(0, 3))} />
          <div className="small" style={{ margin: '8px 4px 0' }}>Only used to tailor your experience.</div>
          <button className="btn block" style={{ marginTop: 22 }} disabled={!(ageN >= 1 && ageN <= 120)} onClick={() => setStep(ageN < 18 ? 0 : 2)}>Continue →</button>
        </div>}
        {step === 0 && <div style={{ textAlign: 'center' }}>
          <CubeSVG size={90} tone={CUBE_TONES[2]} melt={0.2} expr="meh" bubbles={1} />
          <h1 className="h1" style={{ marginTop: 14 }}>Not just yet</h1>
          <div className="sub" style={{ margin: '10px auto 24px', maxWidth: 360 }}>Aqademiq is currently only available to students aged 18 and over. For legal and safety reasons we can't set up an account for you just yet.</div>
          <button className="btn ghost block" onClick={() => setStep(1)}>Go back</button>
        </div>}
        {step === 2 && <div>
          {dots}
          <h1 className="h1">Do we have<br />your consent?</h1>
          <div className="sub" style={{ margin: '6px 0 18px' }}>To work at its best, Aqademiq collects the info you share: study details, mood check-ins and focus patterns.</div>
          <div className="group">
            <button className="srow" onClick={() => setConsent(true)} aria-pressed={consent === true} style={{ background: consent === true ? ACCL : 'transparent' }}><Ic n={consent === true ? 'check_circle' : 'radio_button_unchecked'} fill={consent === true} style={{ fontSize: 22, color: consent === true ? ACC : DIM }} /><span>Yes, I consent<span className="d">Aqademiq can collect and use my info</span></span></button>
            <button className="srow" onClick={() => setConsent(false)} aria-pressed={consent === false} style={{ background: consent === false ? ACCL : 'transparent' }}><Ic n={consent === false ? 'check_circle' : 'radio_button_unchecked'} fill={consent === false} style={{ fontSize: 22, color: consent === false ? ACC : DIM }} /><span>No, I don't consent<span className="d">You won't be able to use Aqademiq</span></span></button>
          </div>
          {consent === true && <div className="small" style={{ margin: '10px 4px 0' }}>By continuing you agree to our <a href="https://www.aqademiq.com/privacy-policy" target="_blank" rel="noopener noreferrer">aqademiq.com/privacy-policy</a> and <a href="https://www.aqademiq.com/terms-of-use" target="_blank" rel="noopener noreferrer">aqademiq.com/terms-of-use</a>.</div>}
          {consent === false && <div className="small" style={{ margin: '10px 4px 0' }}>We need your consent to continue setting up Aqademiq. You can change your mind anytime in Settings.</div>}
          <button className="btn block" style={{ marginTop: 22 }} disabled={consent !== true} onClick={() => setStep(3)}>Continue →</button>
        </div>}
        {step === 3 && <div>
          {dots}
          <h1 className="h1">What should we<br />call you?</h1>
          <div className="sub" style={{ margin: '6px 0 20px' }}>First name is fine. Ada uses it when she talks to you.</div>
          <input className="input" autoFocus placeholder="Your first name" value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter' && name.trim()) setStep(4); }} />
          <button className="btn block" style={{ marginTop: 22 }} disabled={!name.trim()} onClick={() => setStep(4)}>Continue →</button>
        </div>}
        {step === 4 && <div>
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
          {err && <div className="autherr" role="alert" style={{ marginTop: 14 }}>{err}</div>}
          <button className="btn block" style={{ marginTop: 24 }} disabled={busy} onClick={finish}>{busy ? 'Setting up…' : subs.length || sname.trim() ? 'Finish →' : 'Skip for now →'}</button>
        </div>}
      </div>
    </div>);
}

/* ── Ada on your account (the backend's Ada: every change waits for your OK) ── */
function AccountAdaPage({ s, onPlanChanged }) {
  const ui = useUI();
  const [convs, setConvs] = React.useState([]);
  const [cid, setCid] = React.useState(null);
  const [msgs, setMsgs] = React.useState([]);
  const [text, setText] = React.useState('');
  const [busy, setBusy] = React.useState(false);
  const [listOpen, setListOpen] = React.useState(false);
  const endRef = React.useRef(null);
  const cidRef = React.useRef(null); cidRef.current = cid;
  const skipLoad = React.useRef(null); // a chat this page just created: its messages come from the send
  const merge = (l, add) => { const seen = new Set(); return [...l.filter((x) => x.id !== 'pending'), ...add].filter((x) => !seen.has(x.id) && seen.add(x.id)); };
  const loadConvs = async () => { try { const r = await api('GET', '/ada/conversations'); setConvs((r.conversations || []).filter((c) => c.is_active !== false)); return r.conversations || []; } catch (e) { return []; } };
  React.useEffect(() => { loadConvs().then((list) => { const first = list.find((c) => c.is_active !== false); if (first && !cidRef.current) setCid(first.id); }); }, []);
  React.useEffect(() => {
    if (!cid) { setMsgs([]); return; }
    if (skipLoad.current === cid) { skipLoad.current = null; return; }
    let dead = false;
    api('GET', `/ada/conversations/${cid}/messages`).then((r) => { if (!dead) setMsgs(r.messages || []); }).catch(() => {});
    return () => { dead = true; };
  }, [cid]);
  React.useEffect(() => { const box = endRef.current && endRef.current.parentElement; if (box) box.scrollTop = box.scrollHeight; }, [msgs.length, busy]);
  React.useEffect(() => { if (ui.adaDraft) { const d = ui.adaDraft; ui.clearAdaDraft(); send(d, true); } }, [ui.adaDraft]);

  async function send(raw, fresh) {
    const q = (raw || '').trim();
    if (!q || busy) return;
    setBusy(true); setText('');
    let id = fresh ? null : cid;
    try {
      if (!id) { const c = await api('POST', '/ada/conversations', { title: q.slice(0, 48) }); id = c.id; skipLoad.current = id; setMsgs([]); setCid(id); setConvs((l) => [c, ...l]); }
      setMsgs((l) => [...l, { id: 'pending', is_user: true, text: q }]);
      const r = await api('POST', `/ada/conversations/${id}/messages`, { text: q });
      // Only show the reply if this chat is still the one on screen.
      if (cidRef.current === id) setMsgs((l) => merge(l, r.messages || []));
    } catch (e) {
      if (cidRef.current === id) setMsgs((l) => merge(l, [{ id: 'err' + Date.now(), is_user: false, text: e && e.status === 429 ? 'I\'m getting a lot of questions right now. Give me a minute and ask again.' : 'I couldn\'t reach your account just now. Ask me again?' }]));
    } finally { setBusy(false); }
  }
  const setAction = (a) => setMsgs((l) => l.map((m) => m.actions ? { ...m, actions: m.actions.map((x) => x.id === a.id ? a : x) } : m));
  async function decide(a, approve) {
    setBusy(true);
    try {
      const r = await api('POST', `/ada/actions/${a.id}/${approve ? 'approve' : 'reject'}`);
      if (r.action) setAction(r.action);
      if (r.message) setMsgs((l) => [...l, r.message]);
      if (approve) onPlanChanged();
    } catch (e) { ui.toast(e && e.status === 409 ? 'That one was already decided.' : 'Couldn\'t reach your account. Try again.'); }
    finally { setBusy(false); }
  }
  async function decideAll(approve) {
    setBusy(true);
    try {
      const r = await api('POST', `/ada/conversations/${cid}/actions/decide`, { approve });
      (r.actions || []).forEach(setAction);
      if (r.messages && r.messages.length) setMsgs((l) => [...l, ...r.messages]);
      if (approve) onPlanChanged();
    } catch (e) { ui.toast('Couldn\'t reach your account. Try again.'); }
    finally { setBusy(false); }
  }
  async function undo(a) {
    const tid = a.result && (a.result.id || (a.result.task && a.result.task.id));
    if (!tid) return;
    try { await api('DELETE', '/tasks/' + tid); setAction({ ...a, status: 'rejected', _undone: true }); onPlanChanged(); } catch (e) { ui.toast('Couldn\'t undo that.'); }
  }
  const chatList = (onPick) => convs.map((c) => <button key={c.id} className={c.id === cid ? 'on' : ''} onClick={() => onPick(c.id)}><small>{shortDate(String(c.last_message_at || c.created_at || todayKey()).slice(0, 10)).toUpperCase()}</small><b>{c.title || 'Chat with Ada'}</b></button>);
  const pendingCount = msgs.reduce((n, m) => n + (m.actions || []).filter((a) => a.status === 'pending').length, 0);

  return (
    <div className="ada">
      <aside className="chatlist">
        <div className="spread" style={{ padding: '0 4px 10px' }}><h2 className="h2">Chats</h2><button className="iconbtn" onClick={() => setCid(null)} aria-label="New chat"><Ic n="edit" style={{ fontSize: 20 }} /></button></div>
        {chatList(setCid)}
        {!convs.length && <div className="small" style={{ padding: '0 12px' }}>Your chats with Ada, on your phone and here, show up together.</div>}
      </aside>
      <section className="chat">
        <div className="spread" style={{ marginBottom: 8 }}>
          <div className="row"><AdaNavFace size={36} /><h1 className="h2">Ada</h1></div>
          <div className="row" style={{ gap: 6 }}>
            {convs.length > 0 && <button className="pill mob-only" onClick={() => setListOpen(true)}><Ic n="chats" style={{ fontSize: 16 }} />Chats</button>}
            {cid && <button className="pill" onClick={() => setCid(null)}><Ic n="add" style={{ fontSize: 16 }} />New chat</button>}
          </div>
        </div>
        {listOpen && <Sheet title="Chats" onClose={() => setListOpen(false)}><div className="chatlist sheet-list">{chatList((id) => { setCid(id); setListOpen(false); })}</div></Sheet>}
        <div className="msgs">
          {!cid && <div className="empty" style={{ paddingTop: 40 }}>
            <CubeSVG size={96} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
            <h2 className="h2" style={{ marginTop: 14 }}>Hi{s.profile.name ? ' ' + s.profile.name.split(' ')[0] : ''}, I'm Ada.</h2>
            <div className="sub" style={{ maxWidth: 420, margin: '6px auto 20px' }}>I build your week from your real workload. Every change I suggest waits for your OK.</div>
            <div className="chips" style={{ justifyContent: 'center' }}>{ADA_STARTERS.map(([q, ic]) => <button key={q} className="chip" onClick={() => send(q, true)}><Ic n={ic} style={{ fontSize: 18, color: ACC }} />{q}</button>)}</div>
          </div>}
          {msgs.map((m) => m.is_user ?
          <div key={m.id} className="msg me">{m.text}</div> :
          <div key={m.id} className="msg bot">
              <AdaNavFace size={30} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div>{m.text}</div>
                {m.actions && m.actions.length > 0 &&
              <div className="card" style={{ marginTop: 10, overflow: 'hidden' }}>
                    {m.actions.map((a) =>
                <div key={a.id} className="prop" style={{ opacity: a.status === 'rejected' || a.status === 'superseded' ? 0.45 : 1, alignItems: 'flex-start' }}>
                        <Ic n={a.operation === 'delete' ? 'delete' : a.operation === 'update' ? 'edit' : 'add'} style={{ fontSize: 20, color: ACC, marginTop: 2 }} />
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ fontSize: 15, fontWeight: 800 }}>{a.title}</div>
                          {(a.fields || []).slice(0, 4).map((f, i) => <div key={i} className="small">{f.label}: {f.from ? <s>{String(f.from)}</s> : null}{f.from ? ' → ' : ''}{f.to != null ? String(f.to) : ''}</div>)}
                          {a.warning && <div className="small" style={{ color: WARN }}>{a.warning}</div>}
                          {a.status === 'failed' && <div className="small" style={{ color: '#e85476' }}>{a.error || 'That didn\'t work.'}</div>}
                        </div>
                        {a.status === 'pending' && <><button className="quiet" style={{ fontSize: 14 }} disabled={busy} onClick={() => decide(a, false)}>Decline</button><button className="btn sm" style={{ height: 34 }} disabled={busy} onClick={() => decide(a, true)}>Approve</button></>}
                        {(a.status === 'executed' || a.status === 'approved') && <><span className="small" style={{ color: SUCC, fontWeight: 800 }}>Done</span>{a.operation === 'create' && a.resource === 'task' && <button className="link" style={{ fontSize: 14 }} onClick={() => undo(a)}>Undo</button>}</>}
                        {a.status === 'rejected' && <span className="small">{a._undone ? 'Undone' : 'Declined'}</span>}
                      </div>)}
                  </div>}
              </div>
            </div>)}
          {busy && <div className="msg bot"><AdaNavFace size={30} /><div className="row small" style={{ gap: 6 }}><span style={{ display: 'inline-block', animation: 'aqPulse 1s infinite' }}>●</span>Ada is thinking…</div></div>}
          <div ref={endRef} />
        </div>
        {pendingCount > 1 && <div className="row" style={{ justifyContent: 'flex-end', gap: 8, marginBottom: 8 }}>
          <span className="small" style={{ fontWeight: 800, marginRight: 'auto' }}>{pendingCount} WAITING</span>
          <button className="quiet" style={{ fontSize: 14 }} disabled={busy} onClick={() => decideAll(false)}>Decline all</button>
          <button className="btn sm" style={{ height: 34 }} disabled={busy} onClick={() => decideAll(true)}>Approve all</button>
        </div>}
        <div className="composer">
          <textarea rows={1} placeholder={cid ? 'Ask Ada anything…' : "What's on your mind?"} value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(text); } }} />
          <button className="send" disabled={!text.trim() || busy} onClick={() => send(text)} aria-label="Send"><Ic n="send" style={{ fontSize: 20, color: '#fff' }} /></button>
        </div>
      </section>
    </div>);
}

/* ── guest plan → account, offered once after signing in ── */
function BringOver({ guest, onBring, onClose }) {
  const [busy, setBusy] = React.useState(false);
  const n = guest.tasks.length, m = guest.subjects.length;
  return (
    <Sheet title="Bring your plan with you?" onClose={() => !busy && onClose()}>
      <div className="sub" style={{ marginTop: -6 }}>This browser has a plan from before you signed in: {n} {n === 1 ? 'task' : 'tasks'}{m ? ` and ${m} ${m === 1 ? 'subject' : 'subjects'}` : ''}. Add {n + m === 1 ? 'it' : 'them'} to your account, and {n + m === 1 ? 'it shows' : 'they show'} on your phone too.</div>
      <div className="row" style={{ marginTop: 18 }}>
        <button className="btn ghost" disabled={busy} onClick={onClose}>Not now</button>
        <button className="btn" style={{ flex: 1 }} disabled={busy} onClick={async () => { setBusy(true); try { await onBring(); } finally { setBusy(false); } }}>{busy ? 'Adding…' : 'Add to my account'}</button>
      </div>
    </Sheet>);
}
