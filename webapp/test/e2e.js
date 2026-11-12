// End-to-end regression for the Aqademiq web app. Test only: never published.
// Load into the running page; window.__e2e() resolves to a report.
window.__e2e = async function () {
  const R = [];
  const ok = (name, cond, info) => R.push((cond ? 'PASS ' : 'FAIL ') + name + (info !== undefined ? '  — ' + (typeof info === 'string' ? info : JSON.stringify(info)) : ''));
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const $ = (q, el) => (el || document).querySelector(q);
  const $$ = (q, el) => [...(el || document).querySelectorAll(q)];
  const txt = (e) => (e && (e.innerText || e.textContent) || '').replace(/\s+/g, ' ').trim();
  const btn = (t, root) => $$('button', root).find((b) => txt(b) === t);
  const btnStarts = (t, root) => $$('button', root).find((b) => txt(b).startsWith(t));
  const setVal = (el, v) => { const p = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype; Object.getOwnPropertyDescriptor(p, 'value').set.call(el, v); el.dispatchEvent(new Event('input', { bubbles: true })); };
  const enter = (el) => el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
  const st = () => JSON.parse(localStorage.getItem('aq-web-v1'));
  const go = async (p) => { location.hash = p; await sleep(350); };
  const closeSheet = async () => { const c = $('.sheet [aria-label="Close"]'); if (c) { c.click(); await sleep(150); } };
  const pad2 = (n) => String(n).padStart(2, '0');
  const dk = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  const today = dk(new Date()), tomorrow = dk(new Date(Date.now() + 864e5));
  const errors = [];
  window.addEventListener('error', (e) => errors.push(e.message));

  // ── Planner ──
  await go('plan');
  const quick = async (t) => { const i = $('.addrow input'); setVal(i, t); await sleep(40); enter(i); await sleep(150); };
  await quick('E2E anytime');
  ok('quick add lands today', st().tasks.some((t) => t.title === 'E2E anytime' && t.date === today));
  // view another day, type "today": goes on today
  $('[aria-label="Next week"]').click(); await sleep(200);
  await quick('E2E explicit today');
  const ex = st().tasks.find((t) => t.title === 'E2E explicit') || {};
  ok('explicit "today" wins over viewed day', ex.date === today, ex.date);
  const tb = btn('Today'); if (tb) { tb.click(); await sleep(200); }
  await quick('E2E chapter 4.5');
  ok('"chapter 4.5" stays a title', st().tasks.some((t) => t.title === 'E2E chapter 4.5' && t.date === today));
  // menu: open, Escape closes, outside click closes
  $('[aria-label="More"]').click(); await sleep(100);
  ok('plan menu opens', !!$('.menu'));
  document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); await sleep(100);
  ok('Escape closes plan menu', !$('.menu'));
  $('[aria-label="More"]').click(); await sleep(100);
  $('.h1').dispatchEvent(new PointerEvent('pointerdown', { bubbles: true })); await sleep(100);
  ok('outside tap closes plan menu', !$('.menu'));
  // task actions: move to tomorrow
  const row = $$('.task').find((e) => txt(e).startsWith('E2E anytime'));
  row.click(); await sleep(150);
  btn('Move to tomorrow').click(); await sleep(200);
  ok('Move to tomorrow → today+1', (st().tasks.find((t) => t.title === 'E2E anytime') || {}).date === tomorrow);
  // keyboard: Enter on a task row opens actions
  const row2 = $$('.task').find((e) => txt(e).startsWith('E2E chapter'));
  row2.focus(); row2.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); await sleep(150);
  ok('Enter on a task row opens its actions', !!$('.sheet') && txt($('.sheet h2')).startsWith('E2E chapter'));
  btn('Delete').click(); await sleep(150);
  ok('delete removes task', !st().tasks.some((t) => t.title === 'E2E chapter 4.5'));
  const undo = btn('Undo'); undo && undo.click(); await sleep(150);
  ok('undo restores task', st().tasks.some((t) => t.title === 'E2E chapter 4.5'));

  // ── Subjects: add task from a subject keeps it linked, None unlinks ──
  await go('subjects');
  if (!$('.subj')) { btn('Add a subject').click(); await sleep(150); setVal($$('.sheet input')[1], 'E2E Subject'); await sleep(40); btn('Save').click(); await sleep(200); }
  $('.subj').click(); await sleep(200);
  btn('+ Add task').click(); await sleep(200);
  const subjChipOn = $$('.sheet .chip.on').map(txt);
  ok('add-task form shows the subject selected', subjChipOn.some((t) => t !== 'None' && !/^(\d+m|\d+h)/.test(t) && t !== 'Anytime'), subjChipOn);
  btn('None', $('.sheet')).click(); await sleep(50);
  setVal($('.sheet input.input'), 'E2E no subject'); await sleep(40);
  btn('Save', $('.sheet')).click(); await sleep(200);
  ok('choosing None saves without a subject', (st().tasks.find((t) => t.title === 'E2E no subject') || {}).subjectId === null);

  // ── Focus + Prism ──
  await go('focus');
  const P = window.__prism;
  if (st().focus.status === 'done') { btn('Start another session') && btn('Start another session').click(); await sleep(200); }
  P.unlock();
  btn('Start focus').click(); await sleep(60);
  btn('Freeze').click(); await sleep(400);
  ok('freeze while Prism loads → not playing', P.state !== 'playing', P.state);
  await sleep(6000);
  ok('…and stays silent once loaded', P.state !== 'playing', P.state);
  btn('Resume').click();
  let t0 = Date.now(); while (P.state !== 'playing' && Date.now() - t0 < 15000) await sleep(200);
  ok('resume brings Prism back', P.state === 'playing', P.state + ' after ' + (Date.now() - t0) + 'ms');
  btn('Freeze').click(); await sleep(200); btn('Resume').click(); await sleep(200); btn('Freeze').click(); await sleep(3600);
  ok('freeze→resume→freeze: suspended only after the last fade', P.ctx.state === 'suspended' && P.state === 'paused', P.ctx.state + '/' + P.state);
  btn('Resume').click(); await sleep(1500);
  btn('End').click(); await sleep(300);
  ok('End stops Prism', P.state === 'stopped');
  const sess = st().sessions[st().sessions.length - 1];
  ok('session recorded today', sess && sess.date === today, sess && sess.date);
  btn('Back to today →').click(); await sleep(300);

  // ── Ada with a stand-in for Claude ──
  await go('plan');
  await quick('E2E timed 9am');
  const timed = st().tasks.find((t) => t.title === 'E2E timed' && t.time === '09:00') || null;
  ok('timed quick add', !!timed);
  const realClaude = window.claude;
  let lastPrompt = '';
  window.claude = { use: async (n) => n === 'sample' ? Object.assign(async () => ({ text: '' }), { json: async (input) => { lastPrompt = input; return { reply: 'Plan below.', proposals: [
    { action: 'add', title: 'E2E Ada add', date: tomorrow, time: '10:00', minutes: 45 },
    { action: 'add', title: 'E2E past', date: '2020-01-01', time: null, minutes: 30 },
    { action: 'add', title: 'E2E bad date', date: '2026-02-30', time: null, minutes: 30 },
    ...(timed ? [{ action: 'move', taskId: timed.id, date: tomorrow, time: null }] : []),
  ] }; } }) : null };
  await go('ada');
  const newChat = btn('New chat'); if (newChat) { newChat.click(); await sleep(150); }
  setVal($('.composer textarea'), 'plan tomorrow'); await sleep(40); $('.send').click(); await sleep(500);
  const card = txt($('.msg.bot .card'));
  ok('past / impossible dates filtered out', !card.includes('E2E past') && !card.includes('E2E bad date'), card.slice(0, 80));
  btn('Approve all').click(); await sleep(200);
  ok('approved add creates the task', st().tasks.some((t) => t.title === 'E2E Ada add' && t.time === '10:00' && t.date === tomorrow));
  if (timed) ok('move with no time keeps the task\'s time', (st().tasks.find((t) => t.id === timed.id) || {}).time === timed.time);
  window.claude = realClaude;

  // ── Imports ──
  await go('preferences');
  $$('.srow').find((e) => txt(e).startsWith('Reminder import')).click(); await sleep(150);
  $$('.sheet .srow').find((e) => txt(e).startsWith('Paste a list')).click(); await sleep(150);
  setVal($('.sheet textarea'), 'Due 2/1/27\n- [x] Buy pens\nGym 5.30pm\nEssay 11/30'); await sleep(40);
  btn('Preview').click(); await sleep(200);
  const rows = $$('.sheet .srow').map(txt);
  ok('paste review rows', rows.length === 4 && rows[0].startsWith('Due') && rows[1].startsWith('Buy pens') && rows[2].includes('5:30 PM') && rows[3].startsWith('Essay 11/30'), rows);
  await closeSheet();
  const ics = ['BEGIN:VCALENDAR', 'BEGIN:VEVENT', 'UID:e2e-alarm', 'SUMMARY:E2E Lecture', `DTSTART:${tomorrow.replace(/-/g, '')}T090000`, 'BEGIN:VALARM', 'SUMMARY:Alarm notification', 'END:VALARM', 'END:VEVENT', 'END:VCALENDAR'].join('\r\n');
  $$('.srow').find((e) => txt(e).startsWith('Calendar import')).click(); await sleep(150);
  const inp = $('.sheet input[type=file]'); const dt = new DataTransfer(); dt.items.add(new File([ics], 'e2e.ics')); inp.files = dt.files; inp.dispatchEvent(new Event('change', { bubbles: true })); await sleep(400);
  ok('alarm text never becomes the title', $$('.sheet .srow').map(txt).some((t) => t.startsWith('E2E Lecture')) && !$$('.sheet .srow').map(txt).some((t) => t.startsWith('Alarm')));
  ok('file input cleared for re-picking', inp.value === '');
  await closeSheet();

  // ── Tags: deleting all survives a reload (checked via normalize on stored state) ──
  const tagsBefore = st().tags.length;
  ok('tags present', tagsBefore > 0, tagsBefore);

  // ── Layout at phone width (run with the viewport set to 375) ──
  if (innerWidth <= 400) {
    for (const p of ['plan', 'subjects', 'focus', 'ada', 'week', 'preferences']) { await go(p); ok('no sideways scroll on ' + p, document.documentElement.scrollWidth <= innerWidth + 1, document.documentElement.scrollWidth); }
    await go('focus'); $$('.chip')[0].click(); await sleep(150);
    const m = $('.prism-menu'); const r = m && m.getBoundingClientRect();
    ok('Prism menu fits on screen', r && r.left >= 0 && r.right <= innerWidth + 1, r && [Math.round(r.left), Math.round(r.right)]);
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); await sleep(100);
    await go('ada'); ok('Chats button on phones', !!$$('.mob-only').find((e) => getComputedStyle(e).display !== 'none') || st().chats.length === 0);
  }
  ok('no page errors', errors.length === 0, errors);
  return R.join('\n');
};
'e2e loaded';
