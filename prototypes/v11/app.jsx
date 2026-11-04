






















/* ─── TWEAK DEFAULTS ──────────────────────────────────────────────────── */
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#6b5cf0",
  "warmth": "Cool",
  "subjectsLayout": "List",
  "focusTimer": "Ice melt",
  "darkMode": true
}/*EDITMODE-END*/;

/* ─── MUTABLE TOKENS ──────────────────────────────────────────────────── */
let BG = '#efefee';   // fill on white surfaces (inputs, chips, tiles)
let PAGE = '#fcfcfc'; // screen background
let NAV_ON = '#ececec'; // selected tab capsule
let IS_DARK = false;
let ACC = '#6b5cf0';
let ACCL = '#edeafd';
let HILITE = '#ececec'; // stronger fill - visible on white (option rows, ring track, ✕ circles)
let PILL = '#f5f5f4';   // fill directly on the page (section pills, date tile, segments)
let INK = '#111717';
let SUBJ_LAYOUT = 'List';
let FOCUS_STYLE = 'Ice melt';
let WHITE = '#ffffff';
let TEXT = '#111717';
let MED = '#646464';
let DIM = '#a7a7a7';
let BORDER = 'rgba(0,0,0,0.07)';
let SHADOW = '0 4px 22px rgba(0,0,0,0.06)';
let FRAME_BG = '#e4e4e3';

const PALETTE_LIGHT = {
  '#6b5cf0': '#edeafd',
  '#e85476': '#fde8ed',
  '#2a9d6b': '#e8fdf3'
};
const PALETTE_DARK = {
  '#6b5cf0': '#2a2340',
  '#e85476': '#3a1422',
  '#2a9d6b': '#0d2b1d'
};

function applyTweaks(t) {
  ACC = t.accent;
  SUBJ_LAYOUT = t.subjectsLayout || 'List';
  FOCUS_STYLE = t.focusTimer || 'Ice melt';
  if (t.darkMode) {
    BG = '#0e0e0e';
    WHITE = '#1b1b1b';
    TEXT = '#efefef';
    MED = '#888888';
    DIM = '#505050';
    BORDER = 'rgba(255,255,255,0.07)';
    SHADOW = '0 2px 20px rgba(0,0,0,0.55)';
    FRAME_BG = '#e4e4e3'; // canvas around the phones stays light in both modes
    HILITE = '#33333a';
    INK = ACC;
    ACCL = PALETTE_DARK[t.accent] || ACC + '28';
    PAGE = BG; PILL = HILITE; NAV_ON = ACC; IS_DARK = true;
  } else {
    // Light, from the reference build: a near-white page; white raised surfaces
    // told apart by soft shadow rather than fill; stone fills one step down -
    // lighter on the page (HILITE), a touch deeper on white (BG).
    const W8 = { Neutral: ['#fcfcfc', '#f5f5f4', '#efefee', '#ececec'], Warm: ['#faf9f7', '#f3f2ef', '#edebe7', '#e9e7e3'], Cool: ['#fbfcfd', '#f2f4f7', '#eceff3', '#e8ebf0'] };
    [PAGE, PILL, BG, HILITE] = W8[t.warmth] || W8.Neutral;
    NAV_ON = HILITE;
    IS_DARK = false;
    WHITE = '#ffffff';
    TEXT = '#111717';
    MED = '#646464';
    DIM = '#a7a7a7';
    BORDER = 'rgba(0,0,0,0.07)';
    SHADOW = '0 4px 22px rgba(0,0,0,0.06)';
    FRAME_BG = '#e4e4e3';
    INK = '#111717';
    ACCL = PALETTE_LIGHT[t.accent] || '#ede9fe';
  }
}
applyTweaks(TWEAK_DEFAULTS);

/* ─── STATIC TOKENS ───────────────────────────────────────────────────── */
const SUCC = '#2a9d6b';
const WARN = '#e8a430';
const SERIF = '"Playfair Display", Georgia, serif';
const SANS = '"Plus Jakarta Sans", system-ui, sans-serif';
const MONO = '"JetBrains Mono", "Courier New", monospace';
const NUMSERIF = '"Playfair Display", Georgia, serif'; // numerals keep their serif

/* ─── AQADEMIQ ICON PACK v1 ───────────────────────────────────────────────
   Geometry lives in assets/aq-icons (aq-icons.js, aq-tasks.js): 24 grid,
   1.75 stroke, round caps, currentColor. Outline by default, fill only when
   selected or active. Material names still in data resolve through AQ_MAP so
   the swap is one auditable table; null = a gap in the pack, the Material
   glyph stays until one lands. 'mi:name' forces Material for one call site. */
const AQ_ICE = '#6B5CF0';         // --aq-ice, pinned: never follows the accent swap
const AQ_ICE_ON_DARK = '#CBBCFD'; // --aq-ice-on-dark, hero on OLED black
const AQ_ICE_GLYPHS = new Set(['freeze', 'thaw', 'never_open', 'shield']);
const AQ_TAG = { Lecture: 'lecture', Class: 'class', Exam: 'exam', Assignment: 'assignment', Report: 'report', Presentation: 'presentation', Reading: 'reading' };
const AQ_TAG_INK = { lecture: '#1F6FAE', class: '#4F3FD6', exam: '#C23358', assignment: '#1D7A52', report: '#A8680A', presentation: '#A3346A', reading: '#556073' }; // --aq-tag-*-ink
const AQ_MAP = {
  arrow_back: 'back', chevron_left: 'back', chevron_right: 'chevron_right', expand_more: 'chevron_down', expand_less: 'chevron_up', arrow_drop_up: 'chevron_up',
  arrow_forward: 'forward', arrow_upward: 'send', close: 'close', more_horiz: 'more', more_vert: 'more_vertical', search: 'search',
  add: 'add', remove: 'remove', edit: 'edit', edit_note: 'note', edit_calendar: 'edit', delete_outline: 'delete', ios_share: 'share', check: 'check',
  check_circle: 'check_circle:fill', check_circle_outline: 'check_circle', radio_button_unchecked: 'aqx_ring',
  sort: 'sort', swap_vert: 'sort', sort_by_alpha: 'sort', drag_indicator: 'drag', tune: 'adjust', format_list_bulleted: 'list_view', view_agenda: 'list_view',
  account_tree: 'list_view', auto_awesome: 'list_view', refresh: 'sync', notes: 'note', description: 'file', picture_as_pdf: 'file', folder_open: 'folder',
  document_scanner: 'scan', attach_file: 'attach', slideshow: 'task_presentation', quiz: 'task_exam', school: 'task_lecture',
  schedule: 'time', today: 'date', event: 'date', calendar_today: 'date', calendar_month: 'date', date_range: 'date', event_repeat: 'repeat', repeat: 'repeat',
  event_note: 'carry_forward', timer: 'focus', center_focus_strong: 'focus', hourglass_empty: 'duration', hourglass_top: 'duration', history_toggle_off: 'history',
  alarm: 'reminder', bedtime: 'wind_down', wb_twilight: 'morning', nights_stay: 'evening', wb_sunny: 'light_mode', light_mode: 'light_mode', dark_mode: 'dark_mode',
  brightness_auto: 'auto_mode', all_inclusive: 'always_open', play_arrow: 'play', pause: 'pause', stop_circle: 'end', play_circle_outline: 'ice_breakers',
  music_note: 'prism', graphic_eq: 'prism', vibration: 'haptics', mic: 'mic', mic_none: 'mic', notifications_none: 'notifications', notifications_off: 'notifications_off',
  ac_unit: 'freeze', waves: 'thaw', lock_open: 'thaw', lock: 'guest', block: 'remove', shield: 'shield', gpp_good: 'shield', bolt: 'shield', spa: 'shield',
  battery_alert: 'battery', query_stats: 'insights', error_outline: 'info', cancel: 'info', menu_book: 'subjects', bar_chart: 'insights', settings: 'settings',
  person_outline: 'profile', logout: 'sign_out', help_outline: 'help', info: 'info', visibility_off: 'hidden', star_outline: 'rate', grade: 'goal',
  track_changes: 'goal', workspace_premium: 'grade', trending_up: 'trend', lightbulb: 'suggestion', bug_report: 'bug',
  /* gaps in the pack: the Material glyph stays until one lands */
  sell: null, view_week: null, swipe_left: null, layers: null, self_improvement: null, sentiment_satisfied: null, favorite_border: null,
  chat_bubble_outline: null, forum: null, do_not_disturb_on: null, work_outline: null
};
// Derived: the ring of aq_check_circle, for unselected radios.
window.AQ.ICONS.aqx_ring = { layers: [{ id: 'ring', d: 'M12 3A9 9 0 1 1 12 21A9 9 0 1 1 12 3Z' }] };
const AQ_SVG = {}, AQ_WARNED = {};
let AQ_UID = 0;
const aqMasked = (ic, variant) => variant === 'fill' && ic.fill ? (ic.fillLayers || ic.layers).some((l) => l.role === 'knock') : ic.layers.some((l) => l.role === 'cut');
const Ic = ({ n, fill, sw = 1.75, style }) => {
  const uid = React.useRef(null);
  const { fontSize, ...rest } = style || {};
  let a = n in AQ_MAP ? AQ_MAP[n] : n;
  const task = typeof a === 'string' && a.startsWith('task_');
  if (a && !a.startsWith('mi:') && !task && !window.AQ.ICONS[a.replace(':fill', '')]) {
    if (!AQ_WARNED[n]) { AQ_WARNED[n] = 1; console.warn('[aq] no glyph for "' + n + '"'); }
    a = null;
  }
  if (!a || a.startsWith('mi:')) return <span className="material-icons-outlined" style={style}>{a ? a.slice(3) : n}</span>;
  const s = fontSize == null ? 24 : parseFloat(fontSize);
  const name = a.replace(':fill', ''), variant = fill || a.endsWith(':fill') ? 'fill' : null;
  let html;
  if (task) html = AQ_SVG[a + sw] || (AQ_SVG[a + sw] = window.AQT.svg(name.slice(5), 'both', { stroke: sw }));
  else if (aqMasked(window.AQ.ICONS[name], variant)) html = window.AQ.svg(name, { variant, stroke: sw, uid: uid.current || (uid.current = 'aqm' + ++AQ_UID) });
  else { const k = name + variant + sw; html = AQ_SVG[k] || (AQ_SVG[k] = window.AQ.svg(name, { variant, stroke: sw })); }
  const color = rest.color === ACC && AQ_ICE_GLYPHS.has(name) ? AQ_ICE : rest.color;
  return <span aria-hidden="true" style={{ display: 'inline-block', width: s, height: s, flexShrink: 0, lineHeight: 0, verticalAlign: 'middle', ...rest, color }} dangerouslySetInnerHTML={{ __html: html }} />;
};


/* ─── ADA BLOB MASCOT ─────────────────────────────────────────────────── */
/* ─── ADA ICE-CUBE MASCOT ─────────────────────────────────────────────── */
// One parametric cube powers both Ada's avatar and the 5 melt-rating states.
// melt m: 0 = crisp frozen cube (best) → 1 = pale melted puddle (worst).

function cubeBodyPath(tL, tY, tR, bL, bR, bY, rTop, rBot, sag) {
  return [
  `M ${tL + rTop} ${tY}`,
  `L ${tR - rTop} ${tY}`,
  `Q ${tR} ${tY} ${tR} ${tY + rTop}`,
  `L ${bR} ${bY - rBot}`,
  `Q ${bR} ${bY} ${bR - rBot} ${bY}`,
  `Q 30 ${bY + sag} ${bL + rBot} ${bY}`,
  `Q ${bL} ${bY} ${bL} ${bY - rBot}`,
  `L ${tL} ${tY + rTop}`,
  `Q ${tL} ${tY} ${tL + rTop} ${tY} Z`].
  join(' ');
}

const CUBE_MOUTHS = {
  happy: (cx, my) => `M ${cx - 7} ${my - 1} Q ${cx} ${my + 6} ${cx + 7} ${my - 1}`,
  smile: (cx, my) => `M ${cx - 6} ${my} Q ${cx} ${my + 4.5} ${cx + 6} ${my}`,
  neutral: (cx, my) => `M ${cx - 6} ${my} L ${cx + 6} ${my}`,
  focused: (cx, my) => `M ${cx - 5} ${my} Q ${cx} ${my + 3} ${cx + 5} ${my}`,
  meh: (cx, my) => `M ${cx - 6} ${my + 2} Q ${cx} ${my - 2} ${cx + 6} ${my + 2}`,
  sad: (cx, my) => `M ${cx - 7} ${my + 3} Q ${cx} ${my - 3.5} ${cx + 7} ${my + 3}` };

// Periwinkle ramp - vivid & frozen (best) paling to washed-out (worst)
const CUBE_TONES = [
{ border: '#a79fc4', body: '#eae8f2', ink: '#938eac' }, // 0 worst - palest
{ border: '#9286d2', body: '#e4ddf3', ink: '#787299' },
{ border: '#7d70d9', body: '#dcd3f7', ink: '#5c5499' },
{ border: '#6a5ce4', body: '#d2c5fa', ink: '#41358f' },
{ border: '#5a44f1', body: '#cbbcfd', ink: '#31237c' } // 4 best - vivid
];

const Sparkle = ({ x, y, r, fill }) =>
<path d={`M ${x} ${y - r} Q ${x + r * 0.2} ${y - r * 0.2} ${x + r} ${y} Q ${x + r * 0.2} ${y + r * 0.2} ${x} ${y + r} Q ${x - r * 0.2} ${y + r * 0.2} ${x - r} ${y} Q ${x - r * 0.2} ${y - r * 0.2} ${x} ${y - r} Z`} fill={fill} />;

const CubeSVG = ({ size = 60, tone = CUBE_TONES[4], melt = 0, expr = 'happy', mouth, bubbles = 3, cheeks = false, sparkles = false, sweat = false }) => {
  const m = melt;
  const tY = 8 + 15 * m,bY = 50 + 2 * m;
  const tL = 11 + 7 * m,tR = 49 - 7 * m;
  const bL = 11 - 6 * m,bR = 49 + 6 * m;
  const rTop = 9 + 3 * m,rBot = 9 + 13 * m,sag = 2.5 * m;
  const body = cubeBodyPath(tL, tY, tR, bL, bR, bY, rTop, rBot, sag);
  const inner = cubeBodyPath(tL + 5, tY + 5, tR - 5, bL + 5, bR - 5, bY - 5, rTop * 0.55, rBot * 0.6, sag * 0.6);
  const faceCY = (tY + bY) / 2 + 1;
  const eyeY = faceCY - 2,eyeR = 2.7 - 0.5 * m,eyeDX = 6 - 1.2 * m,mY = faceCY + 5;
  const gloss = 0.5 * (1 - 0.55 * m);
  const bub = [[21, tY + 9, 2.7], [26.5, tY + 6, 1.5], [19.5, tY + 15.5, 1.9]];
  const ink = tone.ink;
  let eyes;
  if (expr === 'happy') {
    eyes =
    <g stroke={ink} strokeWidth="2.1" fill="none" strokeLinecap="round">
        <path d={`M ${30 - eyeDX - 3} ${eyeY + 1.2} Q ${30 - eyeDX} ${eyeY - 3} ${30 - eyeDX + 3} ${eyeY + 1.2}`} />
        <path d={`M ${30 + eyeDX - 3} ${eyeY + 1.2} Q ${30 + eyeDX} ${eyeY - 3} ${30 + eyeDX + 3} ${eyeY + 1.2}`} />
      </g>;
  } else if (expr === 'sad') {
    eyes =
    <g stroke={ink} strokeWidth="2" fill="none" strokeLinecap="round">
        <path d={`M ${30 - eyeDX - 2.5} ${eyeY - 1.5} L ${30 - eyeDX + 2.5} ${eyeY + 1.5}`} />
        <path d={`M ${30 + eyeDX + 2.5} ${eyeY - 1.5} L ${30 + eyeDX - 2.5} ${eyeY + 1.5}`} />
      </g>;
  } else {
    eyes =
    <g fill={ink}>
        <circle cx={30 - eyeDX} cy={eyeY} r={eyeR} />
        <circle cx={30 + eyeDX} cy={eyeY} r={eyeR} />
      </g>;
  }
  const mouthSvg = (mouth || expr) === 'happy' ?
  <g>
      <path d={`M ${30 - 6.5} ${mY - 1} Q 30 ${mY + 8.5} ${30 + 6.5} ${mY - 1} Q 30 ${mY + 1.5} ${30 - 6.5} ${mY - 1} Z`} fill={ink} />
      <path d={`M ${30 - 3.3} ${mY + 3.4} Q 30 ${mY + 6.4} ${30 + 3.3} ${mY + 3.4} Q 30 ${mY + 5} ${30 - 3.3} ${mY + 3.4} Z`} fill="#e8607f" />
    </g> :

  <path d={CUBE_MOUTHS[mouth || expr](30, mY)} stroke={ink} strokeWidth={2.4 - 0.4 * m} fill="none" strokeLinecap="round" />;
  return (
    <svg width={size} height={size} viewBox="0 0 60 60" style={{ flexShrink: 0, overflow: 'visible' }}>
      {sparkles &&
      <g>
          <Sparkle x={46} y={9} r={4.2} fill={tone.border} />
          <Sparkle x={53} y={17} r={2.6} fill={tone.border} />
          <circle cx={40} cy={6} r={1.6} fill={tone.border} />
          <circle cx={50} cy={5} r={1.2} fill={tone.border} />
          <circle cx={56} cy={12} r={1.4} fill={tone.border} />
        </g>
      }
      <ellipse cx="30" cy={bY + 3} rx={16 + 4 * m} ry="3.2" fill={tone.border} opacity="0.16" />
      <path d={body} fill={tone.body} stroke={tone.border} strokeWidth={3.4 - 1.2 * m} strokeLinejoin="round" />
      <path d={inner} fill="#fff" opacity={0.32 * (1 - 0.5 * m)} />
      <path d={`M ${tL + rTop + 1} ${tY + 2.5} Q ${tL + 3} ${tY + 3} ${tL + 3.2} ${tY + rTop + 5}`} stroke="#fff" strokeWidth="2.4" fill="none" strokeLinecap="round" opacity={gloss} />
      {bub.slice(0, bubbles).map(([cx, cy, r], i) => <circle key={i} cx={cx} cy={cy} r={r} fill="#fff" opacity={(0.85 - i * 0.15) * (1 - 0.5 * m)} />)}
      {cheeks &&
      <g fill="#f0a0b6" opacity="0.72">
          <ellipse cx={30 - eyeDX - 2} cy={eyeY + 5.5} rx="3" ry="2" />
          <ellipse cx={30 + eyeDX + 2} cy={eyeY + 5.5} rx="3" ry="2" />
        </g>
      }
      {eyes}
      {mouthSvg}
      {sweat && <path d={`M ${30 + eyeDX + 6} ${eyeY - 3} q -2.4 4 0 6 q 2.4 -2 0 -6 Z`} fill="#8fd0ef" stroke="#6bb8e0" strokeWidth="0.5" />}
    </svg>);

};

// Ada's avatar - always the crisp, vivid happy cube. mood picks the mouth.
const AdaBlob = ({ size = 32, mood = 'happy' }) =>
<CubeSVG size={size} tone={CUBE_TONES[4]} melt={0} expr={mood} bubbles={3} />;

// Circular Ada face - used ONLY in the bottom nav. Round ice that nearly fills
// the nav slot, leaving a tiny ring gap so selected/unselected reads clearly.
const AdaNavFace = ({ size = 31 }) =>
<div style={{ width: size, height: size, borderRadius: '50%', background: `radial-gradient(circle at 36% 30%, ${CUBE_TONES[4].body} 0%, #b7a6f5 46%, ${ACC} 100%)`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, boxShadow: 'inset 0 -2px 5px rgba(40,25,90,0.18)' }}>
    <svg width={size} height={size} viewBox="0 0 40 40" style={{ overflow: 'visible' }}>
      <g stroke={CUBE_TONES[4].ink} strokeWidth="2.4" fill="none" strokeLinecap="round">
        <path d="M 12.5 18.5 Q 15.5 14.5 18.5 18.5" />
        <path d="M 21.5 18.5 Q 24.5 14.5 27.5 18.5" />
      </g>
      <path d="M 15 23 Q 20 30.5 25 23 Q 20 25.5 15 23 Z" fill={CUBE_TONES[4].ink} />
    </svg>
  </div>;


/* ─── PHONE SHELL ─────────────────────────────────────────────────────── */
const PhoneBgCtx = React.createContext(null);
const Phone = ({ children, bg, dark = false }) =>
<div data-phone="1" style={{
  width: 402, height: 874, borderRadius: 55, background: bg || PAGE,
  overflow: 'hidden', position: 'relative', fontFamily: SANS,
  color: TEXT, fontSize: 17, flexShrink: 0,
  boxShadow: '0 14px 52px rgba(0,0,0,0.14), 0 0 0 1px rgba(0,0,0,0.06)'
}}>
    <div style={{ height: 58, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 34px 0 40px', fontSize: 17, fontWeight: 700 }}>
      <span style={{ color: dark ? 'rgba(255,255,255,0.9)' : TEXT }}>9:41</span>
      <div style={{ position: 'absolute', left: '50%', top: 11, marginLeft: -62, width: 124, height: 36, background: dark ? 'rgba(255,255,255,0.5)' : '#111', borderRadius: 20 }} />
      <span style={{ color: dark ? 'rgba(255,255,255,0.9)' : TEXT, letterSpacing: -1, fontSize: 14 }}>●▊</span>
    </div>
    <PhoneBgCtx.Provider value={bg || PAGE}>{children}</PhoneBgCtx.Provider>
  </div>;


/* ─── BAR CONTROLS ──────────────────────────────────────────────────────
   One size for everything in a screen's top bar, a sheet's toolbar row or a
   dialog's action row: 44pt - the iOS minimum target, and the size Ada's
   header ships at. Circles 44⌀ · capsules 44 tall, r 22 · grouped capsules
   44 (36 slots). Labels 15/700, icons 19 in pills, 22 in circles. The fill
   follows the surface: page = white + shadow on the page · well = BG on white
   screens, cards and sheets · ink = the primary action · glass = over colour.
   Content chips (tags, filters, task links) keep their own smaller scale. */
const HEAD_BTN = 44;
const barFill = (f) => ({
  page: { background: WHITE, boxShadow: SHADOW, color: TEXT },
  well: { background: BG, color: TEXT },
  hilite: { background: HILITE, color: TEXT },
  ink: { background: INK, color: '#fff' },
  glass: { background: 'rgba(255,255,255,0.24)', color: '#fff' }
})[f];
const BarCircle = ({ icon, glyph, fill = 'page', color, style }) =>
<div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', ...barFill(fill), display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, cursor: 'pointer', ...style }}>
    {icon ?
    <Ic n={icon} style={{ fontSize: 22, color: color || 'inherit' }} /> :
    glyph ? <span style={{ fontSize: 20, fontWeight: 700, lineHeight: 1, color: color || MED }}>{glyph}</span> : <Ic n="close" style={{ fontSize: 22, color: color || MED }} />}
  </div>;
const BarPill = ({ icon, glyph, label, fill = 'page', color, iconColor, children, style }) =>
<div style={{ height: HEAD_BTN, boxSizing: 'border-box', borderRadius: HEAD_BTN / 2, padding: icon || glyph ? '0 18px 0 15px' : '0 18px', ...barFill(fill), ...(color ? { color } : null), display: 'flex', alignItems: 'center', gap: 6, fontSize: 17, fontWeight: 700, whiteSpace: 'nowrap', flexShrink: 0, cursor: 'pointer', ...style }}>
    {icon && <Ic n={icon} style={{ fontSize: 19, color: iconColor || 'inherit' }} />}
    {glyph && <span style={{ fontSize: 17, lineHeight: 1, color: iconColor || ACC }}>{glyph}</span>}
    {label}{children}
  </div>;
// Dismiss (✕) is the exception: quiet by design - a bare 20 glyph, no fill,
// so leaving never out-shouts the task. The 44 target stays; it bleeds 12 past
// the content edge so the glyph lines up with the padding, and `tight` lets it
// overhang a title line without making the row any taller.
const BarDismiss = ({ edge = 'right', tight, color = MED, style }) =>
<div style={{ width: HEAD_BTN, height: HEAD_BTN, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, cursor: 'pointer', margin: `${tight ? -10 : 0}px ${edge === 'right' ? -12 : 0}px ${tight ? -10 : 0}px ${edge === 'left' ? -12 : 0}px`, ...style }}>
    <Ic n="close" style={{ fontSize: 20, color }} />
  </div>;


/* ─── BOTTOM NAV ──────────────────────────────────────────────────────── */
const BNav = ({ active = 0, guest = false }) => {
  // visual order: Subjects · Planner · Ada (center) · Timer · Stats - each entry
  // carries its semantic index so screens' `active` props stay unchanged.
  const tabs = [
  ['subjects', 0],
  ['planner', 1],
  [null, 4],
  ['focus', 2],
  ['insights', 3]];

  const locked = (i) => guest && (i === 3 || i === 4); // Stats + Ada need onboarding
  // Scroll fade: the screen's own background, solid up to the nav's midline
  // (22 + 61/2 ≈ 52), easing out 64 above it. Ada (4) runs its own fades.
  const fadeBg = React.useContext(PhoneBgCtx) || PAGE;
  const fadeMask = `linear-gradient(0deg, ${[[0, 1], [0.22, 0.86], [0.48, 0.58], [0.74, 0.24], [1, 0]].map(([p, a]) => `rgba(0,0,0,${a}) ${Math.round(52 + p * 64)}px`).join(', ')})`;
  return (
    <>
    {active !== 4 && <div aria-hidden="true" style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 116, pointerEvents: 'none', background: fadeBg, backgroundSize: '100% 874px', backgroundPosition: 'center bottom', backgroundRepeat: 'no-repeat', maskImage: fadeMask, WebkitMaskImage: fadeMask }} />}
    <div style={{
      position: 'absolute', bottom: 22, left: 22, right: 22, height: 61, boxSizing: 'border-box',
      background: WHITE, borderRadius: 30.5,
      boxShadow: '0 4px 28px rgba(0,0,0,0.13)',
      display: 'flex', alignItems: 'stretch',
      padding: 3.5
    }}>
      {tabs.map(([icon, i]) => {
        const isActive = active === i;
        if (!icon) return (
          <div key={i} style={{ position: 'relative', flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{
              width: 44, height: 44, borderRadius: '50%',
              background: isActive ? INK : WHITE,
              border: isActive ? 'none' : `1.5px solid ${BORDER}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              opacity: locked(i) ? 0.55 : 1
            }}>
              <AdaNavFace size={34} />
            </div>
            {locked(i) && <LockDot />}
          </div>);

        return (
          <div key={i} style={{ position: 'relative', flex: 1, display: 'flex' }}>
            <div style={{
              flex: 1, borderRadius: 27,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              background: isActive ? NAV_ON : 'transparent'
            }}>
              <Ic n={icon} fill={isActive} style={{ fontSize: 24, color: isActive ? IS_DARK ? '#fff' : TEXT : MED }} />
            </div>
            {locked(i) && <LockDot />}
          </div>);

      })}
    </div>
    </>);

};

/* ─── PRIMITIVE COMPONENTS ────────────────────────────────────────────── */

// Guest badge for gated tabs: aq_guest replaces the padlock
const LockDot = () =>
<div style={{ position: 'absolute', top: -1, right: 2, width: 14, height: 14, borderRadius: '50%', background: WARN, border: `2px solid ${WHITE}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <Ic n="guest" sw={2.4} style={{ fontSize: 10, color: '#fff' }} />
  </div>;

const PBtn = ({ children, ghost, style }) =>
<button style={{
  width: '100%', height: 50, padding: '0 16px', background: ghost ? WHITE : INK,
  border: ghost ? `1.5px solid ${BORDER}` : 'none',
  borderRadius: 100, color: ghost ? TEXT : '#fff', fontSize: 17,
  cursor: 'pointer', fontFamily: SANS, letterSpacing: '0.01em', ...style, fontWeight: "800"
}}>{children}</button>;


const Chip = ({ active, children, color, style }) =>
<span style={{
  height: 36, boxSizing: 'border-box', padding: '0 14px', borderRadius: 100, fontSize: 15, fontWeight: 600,
  border: `1.5px solid ${active ? color || ACC : BORDER}`,
  background: active ? color ? color + '18' : ACCL : WHITE,
  color: active ? color || ACC : MED,
  display: 'inline-flex', alignItems: 'center', cursor: 'pointer', whiteSpace: 'nowrap',
  ...style
}}>{children}</span>;


const SLabel = ({ children }) =>
<div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: DIM, marginBottom: 7 }}>{children}</div>;


const Card = ({ children, style }) =>
<div style={{ background: WHITE, borderRadius: 16, padding: '12px 14px', boxShadow: SHADOW, ...style }}>{children}</div>;


/* Student task tags - shared by the add-task form and Settings */
const TASK_TAGS = [
{ label: 'Lecture', color: '#5cbbff' },
{ label: 'Class', color: '#6b5cf0' },
{ label: 'Exam', color: '#e85476' },
{ label: 'Assignment', color: '#2a9d6b' },
{ label: 'Report', color: '#e8a430' },
{ label: 'Presentation', color: '#c0497b' },
{ label: 'Reading', color: '#7a8699' }];


// A tag pill led by its Tier 2 task glyph (custom tags: a dot). dashed = the "add custom" affordance.
const TagChip = ({ label, color, active, dashed, style }) =>
<span style={{
  height: 36, boxSizing: 'border-box', padding: AQ_TAG[label] && !dashed ? '0 14px 0 11px' : '0 14px', borderRadius: 100, fontSize: 15, fontWeight: 600,
  border: dashed ? `1.5px dashed ${color || DIM}` : `1.5px solid ${active ? color : BORDER}`,
  background: active ? color + '18' : WHITE,
  color: dashed ? color || MED : active ? color : MED,
  display: 'inline-flex', alignItems: 'center', gap: 6, cursor: 'pointer', whiteSpace: 'nowrap', ...style
}}>
    {!dashed && (AQ_TAG[label] ? <Ic n={'task_' + AQ_TAG[label]} style={{ fontSize: 18, color: IS_DARK ? color : AQ_TAG_INK[AQ_TAG[label]] }} /> : <span style={{ width: 7, height: 7, borderRadius: '50%', background: color, flexShrink: 0 }} />)}
    {label}
  </span>;




const SectionPill = ({ icon, label, count }) =>
<div style={{ display: 'flex', justifyContent: 'center' }}>
  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: INK, borderRadius: 100, padding: '5px 12px', marginBottom: 10 }} data-comment-anchor="306ef3fa8c-div-333-1">
    <Ic n={icon} style={{ fontSize: 15, color: 'rgba(255,255,255,0.5)' }} />
    <span style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#fff' }}>{label} ({count})</span>
    <Ic n="chevron_down" style={{ fontSize: 17, color: 'rgba(255,255,255,0.4)' }} />
  </div>
</div>;


const DateStrip = ({ active = 0 }) => {
  const days = [['M', '18'], ['T', '19'], ['W', '20'], ['T', '21'], ['F', '22'], ['S', '23'], ['S', '24']];
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 14 }}>
      {days.map(([d, n], i) =>
      <div key={i} style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
        width: 44, padding: '6px 0', borderRadius: 10,
        background: i === active ? INK : 'transparent'
      }}>
          <span style={{ fontSize: 12, fontWeight: 700, color: i === active ? 'rgba(255,255,255,0.55)' : DIM }}>{d}</span>
          <span style={{ fontSize: 17, fontWeight: 700, color: i === active ? '#fff' : i < active ? DIM : TEXT }}>{n}</span>
          {i === active && <div style={{ width: 4, height: 4, borderRadius: '50%', background: 'rgba(255,255,255,0.4)' }} />}
        </div>
      )}
    </div>);

};

/* ─── FOCUS RING ──────────────────────────────────────────────────────── */
const FocusRing = ({ mins = 15, maxMins = 60, size = 168 }) => {
  const cx = size / 2,cy = size / 2;
  const TRACK_R = 58;
  const pct = mins / maxMins;
  const TICK_N = 60;
  const ticks = Array.from({ length: TICK_N }, (_, i) => {
    const frac = i / TICK_N;
    const angle = frac * 2 * Math.PI - Math.PI / 2;
    const major = i % 15 === 0;
    const rO = TRACK_R + 11;const rI = rO - (major ? 9 : 5);
    return {
      x1: cx + Math.cos(angle) * rO, y1: cy + Math.sin(angle) * rO,
      x2: cx + Math.cos(angle) * rI, y2: cy + Math.sin(angle) * rI,
      on: frac < pct, major
    };
  });
  const endAngle = pct * 2 * Math.PI - Math.PI / 2;
  const ex = cx + Math.cos(endAngle) * TRACK_R;
  const ey = cy + Math.sin(endAngle) * TRACK_R;
  const sx = cx,sy = cy - TRACK_R;
  const large = pct > 0.5 ? 1 : 0;
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size}>
        <circle cx={cx} cy={cy} r={TRACK_R} fill="none" stroke={ACCL} strokeWidth={10} />
        {pct > 0.01 &&
        <path d={`M${sx},${sy} A${TRACK_R},${TRACK_R} 0 ${large} 1 ${ex},${ey}`}
        fill="none" stroke={ACC} strokeWidth={10} strokeLinecap="round" />
        }
        {ticks.map((t, i) =>
        <line key={i} x1={t.x1} y1={t.y1} x2={t.x2} y2={t.y2}
        stroke={t.on ? ACC : '#dedede'} strokeWidth={t.major ? 2 : 1} strokeLinecap="round" />
        )}
        {pct > 0.01 && <circle cx={ex} cy={ey} r={7} fill={ACC} />}
        {[['15', cx + TRACK_R - 3, cy], ['30', cx, cy + TRACK_R - 3], ['45', cx - TRACK_R + 3, cy], ['60', cx, cy - TRACK_R + 3]].map(([l, x, y]) =>
        <text key={l} x={x} y={y} textAnchor="middle" dominantBaseline="middle"
        fontSize="9" fontFamily={SANS} fill={DIM} fontWeight="700">{l}</text>
        )}
      </svg>
      <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', textAlign: 'center', pointerEvents: 'none' }}>
        <div style={{ fontFamily: NUMSERIF, fontSize: 46, fontWeight: 800, lineHeight: 1, letterSpacing: -2, color: TEXT }}>{mins}</div>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.14em', color: MED }}>MINS</div>
      </div>
    </div>);

};

/* ─── 00 ENTRY ────────────────────────────────────────────────────────── */
const SPLASH = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
      <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 150, height: 150, objectFit: 'contain' }} />
      <div style={{ ...{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -1, marginTop: 20, marginBottom: 6 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Aqademiq</div>
      <div style={{ fontSize: 15, color: DIM, letterSpacing: '0.07em' }}>Your focus sanctuary.</div>
      <div role="status" aria-label="Loading" style={{ position: 'absolute', bottom: 34, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}><ThinkMark size={26} /></div>
    </div>
  </Phone>;


const WELCOME = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '0 22px', position: 'relative' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 124, height: 124, objectFit: 'contain' }} />
        <div style={{ ...{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.5, lineHeight: 1.2, marginTop: 18, marginBottom: 8 }, fontFamily: "\"Plus Jakarta Sans\"", fontWeight: "800" }}>Welcome to<br />Aqademiq</div>
      </div>
      <div style={{ width: '100%', paddingBottom: 18 }}>
        <PBtn style={{ marginBottom: 9 }}>Sign in / Sign up</PBtn>
        <PBtn ghost style={{ marginBottom: 12 }}>Jump right in!</PBtn>
        <div style={{ textAlign: 'center', fontSize: 13, color: DIM, lineHeight: 1.5, padding: '0 8px' }}>Jumping in as a guest? Your progress saves the moment you create an account.</div>
      </div>
    </div>
  </Phone>;


/* Native SSO logos + buttons (Apple & Google brand guidelines) */
const AppleLogo = ({ size = 16, color = '#fff' }) =>
<svg width={size} height={size} viewBox="0 0 814 1000" fill={color} aria-hidden="true" style={{ display: 'block' }}>
    <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57-155.5-127C46.7 790.7 0 663 0 541.8c0-194.4 126.4-297.5 250.8-297.5 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z" />
  </svg>;

const GoogleLogo = ({ size = 18 }) =>
<svg width={size} height={size} viewBox="0 0 48 48" aria-hidden="true" style={{ display: 'block' }}>
    <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
    <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
    <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
    <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
  </svg>;

const SSOButtons = () =>
<div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 18 }}>
    <div style={{ background: '#000', borderRadius: 100, height: 50, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
      <AppleLogo size={17} color="#fff" />
      <span style={{ fontFamily: '-apple-system, "SF Pro Text", "Helvetica Neue", sans-serif', fontSize: 17, fontWeight: 600, color: '#fff' }}>Sign in with Apple</span>
    </div>
    <div style={{ background: '#fff', borderRadius: 100, height: 50, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, border: '1.5px solid #747775' }}>
      <GoogleLogo size={18} />
      <span style={{ fontFamily: '"Roboto", arial, sans-serif', fontSize: 17, fontWeight: 500, color: '#1f1f1f' }}>Sign in with Google</span>
    </div>
  </div>;


const AUTH = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '10px 22px 0', height: 792 }}>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 4 }}>Welcome.</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 22 }}>Sign in to continue</div>
      <SSOButtons />
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
        <div style={{ flex: 1, height: 1, background: BORDER }} />
        <span style={{ fontSize: 15, color: DIM }}>or email</span>
        <div style={{ flex: 1, height: 1, background: BORDER }} />
      </div>
      <SLabel>Email</SLabel>
      <div style={{ background: BG, borderRadius: 14, padding: '12px 16px', fontSize: 17, color: TEXT, marginBottom: 12, border: `1.5px solid ${BORDER}` }}>ridhwan@bits.ac.in</div>
      <SLabel>Password</SLabel>
      <div style={{ background: BG, borderRadius: 14, padding: '12px 16px', display: 'flex', alignItems: 'center', marginBottom: 8, border: `1.5px solid ${ACC}` }}>
        <span style={{ flex: 1, fontSize: 17, fontWeight: 700, letterSpacing: 3, color: TEXT }}>••••••••</span>
        <Ic n="hidden" style={{ fontSize: 21, color: MED }} />
      </div>
      <div style={{ fontSize: 15, fontWeight: 700, color: ACC, textAlign: 'right', marginBottom: 14 }}>Forgot password?</div>
      <PBtn style={{ marginBottom: 14 }}>Sign in →</PBtn>
      <div style={{ fontSize: 15, color: MED, textAlign: 'center' }}>New here? <span style={{ fontWeight: 700, color: TEXT }}>Create an account</span></div>
    </div>
  </Phone>;


// Create an account: email + password + confirm, then → OTP verification.
const AUTH_SIGNUP = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '10px 22px 0', height: 792 }}>
      <div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 16 }}>
        <Ic n="back" style={{ fontSize: 22, color: TEXT }} />
      </div>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 4 }}>Create account</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 22 }}>Save your streak, grades &amp; plan</div>
      <SLabel>Email</SLabel>
      <div style={{ background: BG, borderRadius: 14, padding: '12px 16px', fontSize: 17, color: TEXT, marginBottom: 14, border: `1.5px solid ${ACC}` }}>ridhwan@bits.ac.in</div>
      <SLabel>Password</SLabel>
      <div style={{ background: BG, borderRadius: 14, padding: '12px 16px', display: 'flex', alignItems: 'center', marginBottom: 14, border: `1.5px solid ${BORDER}` }}>
        <span style={{ flex: 1, fontSize: 17, fontWeight: 700, letterSpacing: 3, color: TEXT }}>••••••••</span>
        <Ic n="hidden" style={{ fontSize: 21, color: MED }} />
      </div>
      <SLabel>Confirm password</SLabel>
      <div style={{ background: BG, borderRadius: 14, padding: '12px 16px', display: 'flex', alignItems: 'center', marginBottom: 22, border: `1.5px solid ${BORDER}` }}>
        <span style={{ flex: 1, fontSize: 17, fontWeight: 700, letterSpacing: 3, color: TEXT }}>••••••••</span>
        <Ic n="hidden" style={{ fontSize: 21, color: MED }} />
      </div>
      <PBtn style={{ marginBottom: 14 }}>Create account →</PBtn>
      <div style={{ fontSize: 15, color: MED, textAlign: 'center' }}>Already have an account? <span style={{ fontWeight: 700, color: TEXT }}>Sign in</span></div>
    </div>
  </Phone>;


const AUTH_OTP = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '10px 22px 0', height: 792 }}>
      <div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 20 }}>
        <Ic n="back" style={{ fontSize: 22, color: TEXT }} />
      </div>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 6 }}>Verify it's you</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 28 }}>We sent a 6-digit code to<br /><span style={{ fontWeight: 700, color: TEXT }}>ridhwan@bits.ac.in</span></div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
        {['4', '1', '9', '', '', ''].map((d, i) =>
      <div key={i} style={{ flex: 1, aspectRatio: '1', borderRadius: 14, background: d ? ACCL : BG, border: `2px solid ${i === 3 ? ACC : d ? ACC + '55' : BORDER}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 28, fontWeight: 800, color: TEXT }}>
            {d || (i === 3 ? <span style={{ width: 2, height: 22, background: ACC }} /> : '')}
          </div>
      )}
      </div>
      <PBtn style={{ marginBottom: 16 }}>Verify →</PBtn>
      <div style={{ fontSize: 15, color: MED, textAlign: 'center', lineHeight: 1.7 }}>Didn't get a code? <span style={{ fontWeight: 700, color: ACC }}>Resend in 0:24</span></div>
    </div>
  </Phone>;


/* ─── 01 ONBOARDING ───────────────────────────────────────────────────── */
const Dots = ({ total = 5, active = 0 }) =>
<div style={{ display: 'flex', gap: 5, marginBottom: 20 }}>
    {Array.from({ length: total }, (_, i) =>
  <div key={i} style={{ height: 4, borderRadius: 2, background: i === active ? ACC : '#e0e0e0', width: i === active ? 22 : 6 }} />
  )}
  </div>;


// Referral codes are 8 characters, shown and typed as 4 + 4.
const REF_CODE = 'ADA7K42Q';
const OB_REFERRAL = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={2} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 20 }}>Got a referral<br />code?</div>
      <SLabel>Referral code</SLabel>
      <div style={{ display: 'flex', gap: 5, marginBottom: 16 }}>
        {['A', 'D', 'A', '', '', '', '', ''].map((c, i) =>
      <div key={i} style={{ flex: 1, aspectRatio: '1', marginLeft: i === 4 ? 7 : 0, borderRadius: 11, background: c ? ACCL : BG, border: `2px solid ${i === 3 ? ACC : c ? ACC + '55' : BORDER}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 20, fontWeight: 800, color: TEXT }}>
            {c || (i === 3 ? <span style={{ width: 2, height: 20, background: ACC }} /> : '')}
          </div>
      )}
      </div>
      <Card style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginBottom: 22, background: ACCL, boxShadow: 'none' }}>
        <AdaBlob size={28} mood="happy" />
        <span style={{ fontSize: 15, color: TEXT, lineHeight: 1.6 }}>A friend invited you? Pop in their code and you both earn Aqademiq Pro perks.</span>
      </Card>
      <PBtn>Continue →</PBtn>
      <div style={{ textAlign: 'center', fontSize: 15, color: MED, fontWeight: 600, marginTop: 12, cursor: 'pointer' }}>I don't have one</div>
    </div>
  </Phone>;


// How they heard about us - right after the referral step. Skipped when a referral code was used.
const OB_SOURCES = ['A friend or classmate', 'TikTok', 'Instagram', 'YouTube', 'Reddit', 'ChatGPT, Claude or Gemini', 'App Store', 'Google search', 'School or uni', 'Discord', 'Other'];
const OB_SOURCE = ({ pick = 'TikTok' }) =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={3} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>How did you hear<br />about us?</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 18 }}>Pick the main one. It helps us reach more students like you.</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: pick === 'Other' ? 14 : 24 }}>
        {OB_SOURCES.map((s) => <Chip key={s} active={s === pick}>{s}</Chip>)}
      </div>
      {pick === 'Other' && <>
        <div style={{ background: BG, borderRadius: 14, padding: '13px 16px', fontSize: 17, fontWeight: 600, color: TEXT, marginBottom: 6, border: `2px solid ${ACC}` }}>A podcast<span style={{ opacity: 0.35 }}>|</span></div>
        <div style={{ fontSize: 15, color: DIM, marginBottom: 24 }}>Optional. A word or two is plenty.</div>
      </>}
      <PBtn>Continue →</PBtn>
      <div style={{ textAlign: 'center', fontSize: 15, color: MED, fontWeight: 600, marginTop: 12, cursor: 'pointer' }}>Skip</div>
    </div>
  </Phone>;


// Consent - asked right after referral, before any personal info is typed.
const OB_CONSENT = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={1} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>Do we have<br />your consent?</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 16 }}>To work at its best, Aqademiq collects the info you share: study details, mood check-ins and focus patterns.</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: ACCL, border: `2px solid ${ACC}`, borderRadius: 14, padding: '11px 14px', cursor: 'pointer' }}>
          <div style={{ width: 18, height: 18, borderRadius: '50%', background: ACC, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ic n="check" style={{ fontSize: 15, color: '#fff' }} />
          </div>
          <div>
            <div style={{ fontSize: 17, fontWeight: 800, color: TEXT }}>Yes, I consent</div>
            <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>Aqademiq can collect and use my info</div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: BG, border: `2px solid transparent`, borderRadius: 14, padding: '11px 14px', cursor: 'pointer' }}>
          <div style={{ width: 18, height: 18, borderRadius: '50%', border: `2px solid ${DIM}`, flexShrink: 0 }} />
          <div>
            <div style={{ fontSize: 17, fontWeight: 800, color: TEXT }}>No, I don't consent</div>
            <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>You won't be able to use Aqademiq</div>
          </div>
        </div>
      </div>
      <div style={{ fontSize: 15, color: MED, lineHeight: 1.7, marginBottom: 18 }}>By continuing you agree to our <a href="https://aqademiq.com/privacy-policy" style={{ color: ACC, fontWeight: 700, textDecoration: 'underline' }}>aqademiq.com/privacy-policy</a> and <a href="https://aqademiq.com/terms-of-use" style={{ color: ACC, fontWeight: 700, textDecoration: 'underline' }}>aqademiq.com/terms-of-use</a>.</div>
      <PBtn>Continue →</PBtn>
    </div>
  </Phone>;


// Consent declined - "No" selected → Continue is disabled (greyed out).
const OB_CONSENT_DECLINED = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={1} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>Do we have<br />your consent?</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 16 }}>To work at its best, Aqademiq collects the info you share: study details, mood check-ins and focus patterns.</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: BG, border: `2px solid transparent`, borderRadius: 14, padding: '11px 14px', cursor: 'pointer' }}>
          <div style={{ width: 18, height: 18, borderRadius: '50%', border: `2px solid ${DIM}`, flexShrink: 0 }} />
          <div>
            <div style={{ fontSize: 17, fontWeight: 800, color: TEXT }}>Yes, I consent</div>
            <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>Aqademiq can collect and use my info</div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: ACCL, border: `2px solid ${ACC}`, borderRadius: 14, padding: '11px 14px', cursor: 'pointer' }}>
          <div style={{ width: 18, height: 18, borderRadius: '50%', background: ACC, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ic n="check" style={{ fontSize: 15, color: '#fff' }} />
          </div>
          <div>
            <div style={{ fontSize: 17, fontWeight: 800, color: TEXT }}>No, I don't consent</div>
            <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>You won't be able to use Aqademiq</div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 7, alignItems: 'flex-start', marginBottom: 14 }}>
        <Ic n="info" style={{ fontSize: 19, color: WARN, flexShrink: 0, marginTop: 1 }} />
        <span style={{ fontSize: 15, color: MED, lineHeight: 1.6 }}>We need your consent to continue setting up Aqademiq. You can change your mind anytime in Settings.</span>
      </div>
      <button style={{ width: '100%', height: 50, boxSizing: 'border-box', padding: '0 16px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: HILITE, border: 'none', borderRadius: 100, color: DIM, fontSize: 17, fontWeight: 800, fontFamily: SANS, letterSpacing: '0.01em', cursor: 'not-allowed' }} disabled>Continue →</button>
    </div>
  </Phone>;


const OB1 = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={4} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>What should we<br />call you?</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 20 }}>First name is fine</div>
      <div style={{ background: BG, borderRadius: 14, padding: '13px 16px', fontSize: 20, fontWeight: 700, marginBottom: 6, border: `2px solid ${ACC}` }}>Ridhwan<span style={{ opacity: 0.35 }}>|</span></div>
      <div style={{ fontSize: 15, color: DIM, marginBottom: 20 }}>Ada uses this in sessions and check-ins</div>
      <Card style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginBottom: 24, background: ACCL, boxShadow: 'none' }}>
        <AdaBlob size={28} mood="happy" />
        <span style={{ fontSize: 15, color: TEXT, lineHeight: 1.6 }}>Hi, I'm Ada, your focus companion. I'll learn how you work and help you build your week accordingly.</span>
      </Card>
      <PBtn>Continue →</PBtn>
    </div>
  </Phone>;


// Age - number-pad entry, right after the name step.
const OB_AGE = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 816, position: 'relative' }}>
      <Dots total={11} active={0} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>How old<br />are you?</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 22 }}>Ada tunes pacing and check-ins to your age</div>
      <div style={{ width: 110, margin: '0 auto 8px', background: BG, border: `2px solid ${ACC}`, borderRadius: 14, padding: '11px 0', textAlign: 'center', fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 34, fontWeight: 800, color: TEXT }}>19<span style={{ opacity: 0.35, fontWeight: 400 }}>|</span></div>
      <div style={{ fontSize: 15, color: DIM, textAlign: 'center', marginBottom: 16 }}>Only used to tailor your experience</div>
      <PBtn>Continue →</PBtn>
      {/* number pad */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, background: HILITE, padding: '8px 6px 10px', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
        {['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'].map((k, i) =>
      k === '' ? <div key={i} /> :
      k === '⌫' ?
      <div key={i} style={{ height: 34, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-icons-outlined" style={{ fontSize: 18, color: MED }}>backspace</span>
            </div> :
      <div key={i} style={{ height: 34, borderRadius: 8, background: WHITE, boxShadow: '0 1px 0 rgba(0,0,0,0.10)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 17, fontWeight: 700, color: TEXT, cursor: 'pointer' }}>{k}</div>
      )}
      </div>
    </div>
  </Phone>;


// Under-18 gate - shown when the entered age is below 18. Blocks onboarding.
const OB_AGE_GATE = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792, display: 'flex', flexDirection: 'column' }}>
      <Dots total={11} active={0} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <div style={{ width: 76, height: 76, borderRadius: '50%', background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 20 }}>
          <Ic n="duration" style={{ fontSize: 38, color: ACC }} />
        </div>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 10 }}>We're not ready<br />for you just yet</div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.65, marginBottom: 14 }}>Aqademiq is currently only available to students aged 18 and over. For legal and safety reasons we can't set up an account for you just yet.</div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.65 }}>We're actively working on a safe, age-appropriate experience for under-18s. Hang tight, we'd love to have you soon. 💜</div>
      </div>
      <div style={{ marginBottom: 24 }}>
        <PBtn><span style={{ display: 'inline-flex', alignItems: 'center', gap: 7 }}><Ic n="back" style={{ fontSize: 21 }} />Go back</span></PBtn>
      </div>
    </div>
  </Phone>;


const OB2 = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={5} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>What are you<br />studying?</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 16 }}>Ada shapes your plan around your workload</div>
      <SLabel>Level</SLabel>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 14 }}>
        <Chip active>Undergraduate</Chip><Chip>Postgraduate</Chip><Chip>School</Chip><Chip>Self-taught</Chip>
      </div>
      <SLabel>Subjects</SLabel>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 24 }}>
        <Chip active>Engineering</Chip><Chip active>CS</Chip><Chip>Medicine</Chip><Chip>Business</Chip><Chip>Law</Chip>
        <span style={{ display: 'inline-flex', alignItems: 'center', height: 36, boxSizing: 'border-box', padding: '0 12px', borderRadius: 100, fontSize: 15, fontWeight: 600, border: `1.5px dashed ${ACC}88`, color: ACC, cursor: 'pointer' }} data-comment-anchor="fa1de78f94-span-546-9">+ More</span>
      </div>
      <PBtn>Continue →</PBtn>
    </div>
  </Phone>;


// Step 2 with the New Subject popup open (same form as the Subjects section,
// reached via the "+ More" chip) - presented as a modal sheet over dimmed Step 2.
const OB2_ADD_SUBJECT = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792, opacity: 0.26, pointerEvents: 'none' }}>
      <Dots total={11} active={5} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>What are you<br />studying?</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 16 }}>Ada shapes your plan around your workload</div>
      <SLabel>Level</SLabel>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 14 }}>
        <Chip active>Undergraduate</Chip><Chip>Postgraduate</Chip><Chip>School</Chip><Chip>Self-taught</Chip>
      </div>
      <SLabel>Subjects</SLabel>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        <Chip active>Engineering</Chip><Chip active>CS</Chip><Chip>Medicine</Chip><Chip>Business</Chip>
      </div>
    </div>
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.34)' }} />
    <div style={{ position: 'absolute', left: 0, right: 0, top: 58, bottom: 0, background: PAGE, borderRadius: '24px 24px 0 0', boxShadow: '0 -10px 44px rgba(0,0,0,0.28)', overflow: 'hidden' }}>
      <AddSubjectBody />
    </div>
  </Phone>;


// Step 3 - how the student feels about each subject they picked (low-friction tap scale)
const SUBJECT_MOODS = [
{ subject: 'Engineering', pre: 2 },
{ subject: 'Computer Science', pre: 4 }];


const OB_MOOD = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={6} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 14 }}>How do you feel<br />about each?</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 10 }}>
        {SUBJECT_MOODS.map(({ subject, pre }) =>
      <Card key={subject} style={{ padding: '9px 14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ fontSize: 17, fontWeight: 700 }}>{subject}</span>
              <span style={{ fontSize: 13, fontWeight: 700, color: MOODS[pre].color }}>{MOODS[pre].label}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
              {MOODS.map((m, i) => {
            const active = i === pre;
            return (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                    <div style={{ padding: 3, borderRadius: '50%', border: active ? `2px solid ${m.color}` : '2px solid transparent', background: active ? m.color + '1c' : 'transparent' }}>
                      <MoodBlob idx={i} size={26} />
                    </div>
                  </div>);

          })}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 5, padding: '0 2px' }}>
              <span style={{ fontSize: 12, color: DIM }}>Dread it</span>
              <span style={{ fontSize: 12, color: DIM }}>Love it</span>
            </div>
          </Card>
      )}
      </div>
      <Card style={{ display: 'flex', gap: 9, alignItems: 'flex-start', marginBottom: 12, background: ACCL, boxShadow: 'none', padding: '10px 12px' }}>
        <AdaBlob size={24} mood="happy" />
        <span style={{ fontSize: 15, color: TEXT, lineHeight: 1.5 }}>I'll schedule the subjects you dread in shorter, gentler sessions, and pair them with Prism focus audio.</span>
      </Card>
      <PBtn>Continue →</PBtn>
    </div>
  </Phone>;




const OB5 = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }} data-comment-anchor="3c6839d058-div-606-5">
      <Dots total={11} active={10} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 4 }}>Meet Prism</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 22 }}>Psychoacoustic audio that deepens focus. Auto-plays in sessions.</div>
      <SLabel>Prism modes</SLabel>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginBottom: 24 }}>
        {[[ACC, 'Deep Work', 'Low-freq focus carrier. Hard cognitive tasks.'], [SUCC, 'Flow', 'Smooth ambient. Sustained concentration.'], [WARN, 'Review', 'Steady midtempo. Reading, flashcards, revision.'], [MED, 'Wind-down', 'Slow, calming. End-of-session decompression.']].map(([color, name, desc]) =>
      <Card key={name} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '11px 13px' }}>
            <div style={{ width: 30, height: 30, borderRadius: 10, background: color + '18', border: `1.5px solid ${color}44`, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <PrismGlyph mode={name} color={color} />
            </div>
            <div><div style={{ fontSize: 17, fontWeight: 700, marginBottom: 1 }}>{name}</div><div style={{ fontSize: 13, color: MED }}>{desc}</div></div>
          </Card>
      )}
      </div>
      <PBtn>Let's go →</PBtn>
    </div>
  </Phone>;


const ADA_LOAD = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 28px' }}>
      <AdaBlob size={76} mood="focused" />
      <div style={{ fontFamily: "\"Plus Jakarta Sans\"", fontWeight: 800, marginTop: 18, marginBottom: 6, fontSize: "20px" }}>Ada's getting ready</div>
      <div style={{ fontSize: 17, color: MED, marginBottom: 30 }}>Building your first plan...</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, textAlign: 'left', width: 200 }}>
        {[[true, 'Reading your materials'], [true, 'Mapping your deadlines'], [false, 'Building your week']].map(([done, label], i) =>
      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 22, height: 22, borderRadius: '50%', background: done ? ACC : 'transparent', border: done ? 'none' : `1.5px solid ${DIM}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              {done ? <Ic n="check" style={{ fontSize: 15, color: '#fff' }} /> :
          <div style={{ width: 10, height: 10, borderRadius: '50%', border: `2px solid ${ACC}`, borderTopColor: 'transparent' }} />}
            </div>
            <span style={{ fontSize: 17, color: done ? DIM : TEXT, fontWeight: done ? 400 : 700, textDecoration: done ? 'line-through' : 'none' }}>{label}</span>
          </div>
      )}
      </div>
    </div>
  </Phone>;


/* ─── 02 HOME ─────────────────────────────────────────────────────────── */
const HOME = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ cursor: 'pointer' }}>
          <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.1 }}>Monday</div>
          <div style={{ fontSize: 12, fontWeight: 700, color: MED, marginTop: 1, display: 'flex', alignItems: 'center', gap: 1 }}>MAY 2026<Ic n="chevron_right" style={{ fontSize: 14 }} /></div>
        </div>
        <div style={{ display: 'flex', gap: 7 }}>
          <div style={{ background: WHITE, borderRadius: 100, padding: '6px 12px', boxShadow: SHADOW, fontSize: 17, fontWeight: 700, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 20 }} /></div>
          <div style={{ background: WHITE, borderRadius: 100, padding: '6px 12px', boxShadow: SHADOW, fontSize: 20, fontWeight: 400, lineHeight: 1 }}><Ic n="add" style={{ fontSize: 20 }} /></div>
        </div>
      </div>
      <DateStrip active={0} />
      <div style={{ marginBottom: 6 }}><SectionPill icon="schedule" label="Anytime" count={0} /></div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 2px', marginBottom: 14 }}>
        <span style={{ fontSize: 17, color: DIM }}>Add a task for anytime</span>
        <span style={{ fontSize: 20, color: DIM }}>+</span>
      </div>
      <div style={{ marginBottom: 6 }}><SectionPill icon="today" label="Planned" count={2} /></div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
        <div style={{ width: 38, flexShrink: 0 }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: MED, textAlign: 'right', marginBottom: 4 }}>1 PM</div>
          <div style={{ width: 1, height: 38, background: BORDER, marginLeft: 'auto', marginRight: 4, marginBottom: 4 }} />
          <div style={{ fontSize: 12, fontWeight: 700, color: MED, textAlign: 'right' }}>2 PM</div>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
          <Card style={{ padding: '9px 11px', border: `1.5px solid ${ACC}22` }}>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 4 }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: ACC }} />
              <span style={{ fontSize: 12, fontWeight: 800, color: ACC }}>CC 401</span>
              <span style={{ fontSize: 12, color: DIM, marginLeft: 'auto' }}>35 min</span>
            </div>
            <div style={{ fontSize: 17, fontWeight: 700, marginBottom: 6 }}>LL(1) parsing notes</div>
            <div style={{ background: BG, borderRadius: 100, padding: '3px 10px', display: 'inline-flex', fontSize: 13, fontWeight: 600, gap: 4, alignItems: 'center' }}><Ic n="play" style={{ fontSize: 14 }} />Start session</div>
          </Card>
          <Card style={{ padding: '9px 11px' }}>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 4 }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#5cbbff' }} />
              <span style={{ fontSize: 12, fontWeight: 800, color: '#5cbbff' }}>NLP 302</span>
              <span style={{ fontSize: 12, color: DIM, marginLeft: 'auto' }}>45 min</span>
            </div>
            <div style={{ fontSize: 17, fontWeight: 700 }}>Assignment 3 draft</div>
          </Card>
        </div>
      </div>
    </div>
    <BNav active={1} />
  </Phone>;


/* ─── 02 PLAN - shared helpers ────────────────────────────────────────── */

// Day + month-picker trigger (tappable - opens the month view) + ··· / + actions
// pill. `today` adds a jump-back Today pill beside the actions.
const PlanHeader = ({ day = 'Wednesday', month = 'JUN 2026', calOpen, today, dim }) =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10, opacity: dim ? 0.4 : 1 }}>
    <div style={{ cursor: 'pointer' }}>
      <div style={{ fontFamily: SANS, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.1, fontSize: 17 }}>{day}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 1, fontSize: 12, fontWeight: 800, color: MED, letterSpacing: '0.04em', marginTop: 1 }}>{month}
        <Ic n={calOpen ? 'expand_more' : 'chevron_right'} style={{ fontSize: 14 }} />
      </div>
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
      {today && <BarPill label="Today" />}
      <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
        <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 800, color: TEXT, letterSpacing: 0.5, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 24 }} /></div>
        <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Ic n="add" style={{ fontSize: 24, color: TEXT }} />
        </div>
      </div>
    </div>
  </div>;


const PlanTitle = ({ day = 'Wednesday', month = 'JUN 2026', calOpen }) =>
<div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 8 }}>
    <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -1 }}>{day}</div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 1, fontSize: 13, fontWeight: 800, color: MED, letterSpacing: '0.04em', paddingBottom: 6 }}>{month}
      <Ic n={calOpen ? 'expand_more' : 'chevron_right'} style={{ fontSize: 16 }} />
    </div>
  </div>;


const PlanDateStrip = ({ selected = 2, today = 2 }) => {
  const days = [['M', 1], ['T', 2], ['W', 3], ['T', 4], ['F', 5], ['S', 6], ['S', 7]];
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
      {days.map(([d, n], i) => {
        const sel = i === selected,isToday = i === today,past = n < 3;
        return (
          <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, width: 34, padding: '5px 0', borderRadius: 14, background: sel ? PILL : 'transparent' }}>
            <span style={{ fontSize: 13, fontWeight: 700, color: isToday && !sel ? ACC : DIM }}>{n}</span>
            <span style={{ fontSize: 22, fontWeight: 800, fontFamily: SANS, color: sel ? TEXT : isToday ? ACC : DIM }}>{d}</span>
            {sel && <div style={{ width: 14, height: 3, borderRadius: 2, background: IS_DARK ? '#c4c1bb' : '#e5e3e0' }} />}
          </div>);

      })}
    </div>);

};


// Collapsible section header pill, centered. open → down chevron, closed → up chevron.
const CollapseHead = ({ icon, label, count, open }) =>
<div style={{ display: 'flex', justifyContent: 'center' }}>
  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, background: PILL, borderRadius: 100, padding: icon ? '6px 13px 6px 7px' : '7px 15px' }}>
    {icon && <Ic n={icon} style={{ fontSize: 19, color: MED }} />}
    <span style={{ fontSize: 13, fontWeight: 800, letterSpacing: '0.05em', color: TEXT }}>{label} ({count})</span>
    <Ic n={open ? 'expand_more' : 'expand_less'} style={{ fontSize: 18, color: TEXT }} />
  </div>
</div>;


// Task card - colored left bar (timed), subject tag, duration, completion circle.
const PlanTask = ({ title, dur, time, tag, color, bar, done, dim }) =>
<div style={{ display: 'flex', alignItems: 'stretch', gap: 11, background: WHITE, borderRadius: 16, boxShadow: SHADOW, padding: '11px 13px', opacity: dim ? 0.5 : 1 }}>
    {bar && <div style={{ width: 4, borderRadius: 4, background: color, flexShrink: 0 }} />}
    <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
      <div style={{ fontSize: 17, fontWeight: 800, lineHeight: 1.25 }}>{title}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4, flexWrap: 'wrap' }}>
        {time && <span style={{ fontSize: 13, fontWeight: 800, color: TEXT }}>{time}</span>}
        {tag && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 800, color }}><span style={{ width: 6, height: 6, borderRadius: '50%', background: color }} />{tag}</span>}
        <span style={{ fontSize: 13, color: DIM, fontWeight: 600 }}>{dur}</span>
      </div>
    </div>
    <div style={{ alignSelf: 'center', width: 22, height: 22, borderRadius: '50%', border: `2px solid ${done ? ACC : IS_DARK ? '#d6d3ce' : TEXT}`, background: done ? ACC : 'transparent', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{done && <Ic n="check" style={{ fontSize: 16, color: '#fff' }} />}</div>
  </div>;


const AddRow = ({ label = 'Add a task for anytime' }) =>
<div style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 11, padding: '0 2px' }}>
    <div style={{ width: 6, height: 6, borderRadius: '50%', background: IS_DARK ? '#d6d3ce' : '#ecebe9' }} />
    <span style={{ flex: 1, fontSize: 17, color: DIM, fontWeight: 600 }}>{label}</span>
    <div style={{ width: 24, height: 24, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', color: DIM, fontSize: 17, lineHeight: 1, paddingBottom: 2 }}>+</div>
  </div>;


const TimeLabel = ({ children }) =>
<div style={{ fontSize: 15, fontWeight: 800, color: TEXT, margin: '10px 0 7px' }}>{children}</div>;


const GapRow = ({ label, end }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
    <div style={{ width: 6, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '6px 0' }}>
      {end ?
    <><span style={{ width: 6, height: 6, borderRadius: '50%', background: ACC }} /><Ic n="wind_down" style={{ fontSize: 16, color: ACC }} /></> :

    [0, 1, 2].map((k) => <div key={k} style={{ width: 5, height: 5, borderRadius: '50%', background: '#d6d3ce' }} />)
    }
    </div>
    <span style={{ flex: 1, fontSize: 15, color: DIM, fontWeight: 600 }}>{label}</span>
    <div style={{ width: 24, height: 24, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', color: DIM, fontSize: 17, lineHeight: 1, paddingBottom: 2 }}>+</div>
  </div>;


// Mini month calendar grid. firstCol = weekday offset of day 1 (Mon=0). accent = filled day.
const CalGrid = ({ firstCol, total, accent }) => {
  const cells = [];
  for (let i = 0; i < firstCol; i++) cells.push(null);
  for (let d = 1; d <= total; d++) cells.push(d);
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', rowGap: 3 }}>
      {['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((w) =>
      <div key={w} style={{ textAlign: 'center', fontSize: 11, fontWeight: 800, color: DIM, marginBottom: 4 }}>{w}</div>
      )}
      {cells.map((d, i) =>
      <div key={i} style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 28 }}>
          {d &&
        <div style={{ width: 26, height: 26, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 700, background: d === accent ? ACC : 'transparent', color: d === accent ? '#fff' : TEXT }}>{d}</div>
        }
        </div>
      )}
    </div>);

};


// Shared task data (consistent with the Tasks page vocabulary)
const PLAN_ANYTIME = [
{ title: 'Read chapter 4', dur: '10m', tag: 'CC 401', color: ACC },
{ title: 'Review lecture slides', dur: '5m', tag: 'NLP 302', color: '#5cbbff' },
{ title: 'Submit lab report', dur: '5m', tag: 'NET 305', color: SUCC }];


/* ─── 02 PLAN - frames ────────────────────────────────────────────────── */

// Default: both sections expanded, timeline grouping
const PLAN_TIMELINE = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <PlanHeader />
      <PlanDateStrip />
      <div style={{ marginBottom: 10 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open /></div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <PlanTask title="Read chapter 4" dur="10m" tag="CC 401" color={ACC} />
        <PlanTask title="Review lecture slides" dur="5m" tag="NLP 302" color="#5cbbff" />
      </div>
      <div style={{ margin: '8px 0 2px' }}><CollapseHead label="PLANNED" count={3} open /></div>
      <TimeLabel>11:30 AM</TimeLabel>
      <PlanTask title="LL(1) parsing notes" dur="30m" tag="CC 401" color={ACC} bar />
      <TimeLabel>12:00 PM</TimeLabel>
      <PlanTask title="Assignment 3 draft" dur="30m" tag="NLP 302" color="#5cbbff" bar />
    </div>
    <BNav active={1} />
  </Phone>;


// A planned task Ada has broken into microtasks - shown expanded inline in the
// timeline with a connector rail + completion progress.
const PLAN_BREAKDOWN = () => {
  const micro = [[true, 'Read lecture 9 slides', '10m'], [false, 'Build the parsing table', '15m'], [false, 'Solve 2 practice problems', '10m']];
  return (
    <Phone>
      <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
        <PlanHeader />
        <PlanDateStrip />
        <div style={{ margin: '2px 0 8px' }}><CollapseHead label="PLANNED" count={3} open /></div>
        <TimeLabel>11:30 AM</TimeLabel>
        <div style={{ background: WHITE, borderRadius: 16, boxShadow: SHADOW, overflow: 'hidden', marginBottom: 8 }}>
          <div style={{ display: 'flex', alignItems: 'stretch', gap: 11, padding: '11px 13px 9px' }}>
            <div style={{ width: 4, borderRadius: 4, background: ACC, flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5, flexWrap: 'wrap' }}>
                <span style={{ fontSize: 17, fontWeight: 800 }}>LL(1) parsing notes</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, background: ACCL, color: ACC, fontSize: 12, fontWeight: 800, padding: '2px 7px', borderRadius: 100 }}><span style={{ fontSize: 12 }}>✦</span>Ada · 3 steps</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 13, fontWeight: 800, color: TEXT }}>11:30 AM</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 800, color: ACC }}><span style={{ width: 6, height: 6, borderRadius: '50%', background: ACC }} />CC 401</span>
                <span style={{ fontSize: 13, color: DIM, fontWeight: 600 }}>35m</span>
              </div>
            </div>
            <div style={{ alignSelf: 'center', textAlign: 'center', flexShrink: 0 }}>
              <div style={{ fontSize: 17, fontWeight: 800, color: ACC, fontFamily: '"Plus Jakarta Sans"', lineHeight: 1 }}>1<span style={{ color: DIM }}>/3</span></div>
              <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.06em', color: DIM, marginTop: 2 }}>DONE</div>
            </div>
          </div>
          <div style={{ height: 3, background: BG, margin: '0 13px', borderRadius: 2 }}>
            <div style={{ width: '33%', height: '100%', background: ACC, borderRadius: 2 }} />
          </div>
          <div style={{ padding: '8px 14px 10px 20px' }}>
            {micro.map(([done, text, t], i, a) =>
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 0' }}>
                <div style={{ position: 'relative', width: 16, alignSelf: 'stretch', display: 'flex', justifyContent: 'center', flexShrink: 0 }}>
                  <div style={{ position: 'absolute', top: i === 0 ? '50%' : 0, bottom: i === a.length - 1 ? '50%' : 0, left: '50%', width: 1.5, background: BORDER, transform: 'translateX(-50%)' }} />
                  <div style={{ position: 'relative', width: 15, height: 15, borderRadius: '50%', background: done ? ACC : WHITE, border: `1.5px solid ${done ? ACC : '#cfcbc4'}`, alignSelf: 'center', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 0 3px ${WHITE}` }}>
                    {done && <Ic n="check" sw={2.4} style={{ fontSize: 12, color: '#fff' }} />}
                  </div>
                </div>
                <span style={{ flex: 1, fontSize: 15, fontWeight: 600, color: done ? DIM : TEXT, textDecoration: done ? 'line-through' : 'none' }}>{text}</span>
                <span style={{ fontSize: 13, color: DIM, fontWeight: 700 }}>{t}</span>
              </div>
            )}
          </div>
        </div>
      </div>
      <BNav active={1} />
    </Phone>);

};


// ANYTIME collapsed → reveals more of the planned timeline
const PLAN_ANYTIME_COLLAPSED = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <PlanHeader />
      <PlanDateStrip />
      <div style={{ marginBottom: 12 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open={false} /></div>
      <div style={{ marginBottom: 2 }}><CollapseHead label="PLANNED" count={3} open /></div>
      <TimeLabel>11:30 AM</TimeLabel>
      <PlanTask title="LL(1) parsing notes" dur="30m" tag="CC 401" color={ACC} bar />
      <TimeLabel>12:00 PM</TimeLabel>
      <PlanTask title="Assignment 3 draft" dur="30m" tag="NLP 302" color="#5cbbff" bar />
    </div>
    <BNav active={1} />
  </Phone>;


// PLANNED collapsed → just the anytime tasks
const PLAN_PLANNED_COLLAPSED = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <PlanHeader />
      <PlanDateStrip />
      <div style={{ marginBottom: 10 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open /></div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {PLAN_ANYTIME.map((t) => <PlanTask key={t.title} {...t} />)}
      </div>
      <div style={{ margin: '8px 0 2px' }}><CollapseHead label="PLANNED" count={3} open={false} /></div>
    </div>
    <BNav active={1} />
  </Phone>;


// List grouping - tasks bucketed by time-of-day, emoji avatars, no timeline rail
const ListGroupHead = ({ icon, label, count, tint }) =>
<div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 7 }}>
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, background: tint ? tint + '2e' : PILL, borderRadius: 100, padding: '6px 13px 6px 11px' }}>
      <Ic n={icon} style={{ fontSize: 18, color: MED }} />
      <span style={{ fontSize: 13, fontWeight: 800, letterSpacing: '0.04em', color: TEXT }}>{label} ({count})</span>
      <Ic n="chevron_down" style={{ fontSize: 21, color: TEXT }} />
    </div>
    <Ic n="add" style={{ position: 'absolute', right: 0, fontSize: 19, color: DIM }} />
  </div>;

const PLAN_LIST = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <PlanHeader />
      <PlanDateStrip />
      <ListGroupHead icon="schedule" label="ANYTIME" count={2} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 12 }}>
        <PlanTask title="Find faults visually or logically in front end frames" dur="5m" />
        <PlanTask title="Get DPIIT Certification" dur="5m" />
      </div>
      <ListGroupHead icon="wb_twilight" label="MORNING" count={2} tint={WARN} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 12 }}>
        <PlanTask title="Add Ada AI logo to frames" dur="10m" />
        <PlanTask title="List out what all frames we need to add after brainstorming" time="11:30 AM → 12:00 PM" color={ACC} bar />
      </div>
      <ListGroupHead icon="wb_sunny" label="AFTERNOON" count={3} tint={ACC} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
        <PlanTask title="Ensure every section, frame, text and button is consistent" time="12:00 PM → 12:30 PM" color="#5cbbff" bar />
        <PlanTask title="Find out what has been done regarding KT videos" time="4:00 PM → 4:30 PM" color={SUCC} bar />
      </div>
    </div>
    <BNav active={1} />
  </Phone>;


// Month calendar popup (tap JUN 2026)
const PLAN_MONTH = () =>
<Phone>
    <div style={{ height: 742, position: 'relative', padding: '0 16px' }}>
      <PlanHeader dim calOpen />
      <div style={{ position: 'absolute', top: 92, left: 12, right: 12, background: WHITE, borderRadius: 22, boxShadow: '0 14px 44px rgba(0,0,0,0.16)', padding: '15px 15px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>June 2026 <Ic n="chevron_right" style={{ fontSize: 20, color: ACC }} /></div>
          <div style={{ display: 'flex', gap: 16 }}>
            <Ic n="back" style={{ fontSize: 20, color: TEXT }} />
            <Ic n="chevron_right" style={{ fontSize: 20, color: TEXT }} />
          </div>
        </div>
        <CalGrid firstCol={0} total={30} accent={3} />
      </div>
    </div>
    <BNav active={1} />
  </Phone>;


// Navigated forward to July
const PLAN_MONTH_NEXT = () =>
<Phone>
    <div style={{ height: 742, position: 'relative', padding: '0 16px' }}>
      <PlanHeader dim calOpen />
      <div style={{ position: 'absolute', top: 92, left: 12, right: 12, background: WHITE, borderRadius: 22, boxShadow: '0 14px 44px rgba(0,0,0,0.16)', padding: '15px 15px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>July 2026 <Ic n="chevron_right" style={{ fontSize: 20, color: ACC }} /></div>
          <div style={{ display: 'flex', gap: 16 }}>
            <Ic n="back" style={{ fontSize: 20, color: TEXT }} />
            <Ic n="chevron_right" style={{ fontSize: 20, color: TEXT }} />
          </div>
        </div>
        <CalGrid firstCol={2} total={31} accent={null} />
      </div>
    </div>
    <BNav active={1} />
  </Phone>;


// Month + year wheel picker
const PLAN_MONTHYEAR = () => {
  const months = ['April', 'May', 'June', 'July', 'August'];
  const years = ['2024', '2025', '2026', '2027', '2028'];
  const op = [0.28, 0.5, 1, 0.5, 0.28];
  return (
    <Phone>
      <div style={{ height: 742, position: 'relative', padding: '0 16px' }}>
        <PlanHeader dim calOpen />
        <div style={{ position: 'absolute', top: 92, left: 12, right: 12, background: WHITE, borderRadius: 22, boxShadow: '0 14px 44px rgba(0,0,0,0.16)', padding: '15px 15px 22px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontFamily: SANS, fontSize: 20, fontWeight: 800, color: ACC, marginBottom: 10 }}>June 2026 <Ic n="chevron_down" style={{ fontSize: 20 }} /></div>
          <div style={{ position: 'relative' }}>
            <div style={{ position: 'absolute', top: '50%', left: -4, right: -4, height: 42, transform: 'translateY(-50%)', background: HILITE, borderRadius: 12 }} />
            <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', padding: '0 6px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                {months.map((m, i) =>
                <div key={m} style={{ height: 42, display: 'flex', alignItems: 'center', fontSize: i === 2 ? 28 : 22, fontWeight: i === 2 ? 800 : 600, opacity: op[i] }}>{m}</div>
                )}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 0, alignItems: 'flex-end' }}>
                {years.map((y, i) =>
                <div key={y} style={{ height: 42, display: 'flex', alignItems: 'center', fontSize: i === 2 ? 28 : 22, fontWeight: i === 2 ? 800 : 600, opacity: op[i] }}>{y}</div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
      <BNav active={1} />
    </Phone>);

};


// A different day (Tuesday) with the Today button
const PLAN_OTHERDAY = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <PlanHeader today day="Tuesday" />
      <PlanDateStrip selected={1} today={2} />
      <div style={{ marginBottom: 4 }}><CollapseHead icon="schedule" label="ANYTIME" count={0} open /></div>
      <AddRow />
      <div style={{ margin: '6px 0 2px' }}><CollapseHead label="PLANNED" count={0} open /></div>
      <TimeLabel>12:00 AM</TimeLabel>
      <div style={{ display: 'flex', gap: 11, alignItems: 'stretch' }}>
        <div style={{ width: 6, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'space-between', padding: '1px 0' }}>
          <Ic n="light_mode" style={{ fontSize: 19, color: WARN }} />
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5, padding: '5px 0' }}>
            {[0, 1, 2].map((k) => <div key={k} style={{ width: 5, height: 5, borderRadius: '50%', background: '#d6d3ce' }} />)}
          </div>
          <Ic n="wind_down" style={{ fontSize: 19, color: ACC }} />
        </div>
        <span style={{ flex: 1, fontSize: 15, color: DIM, fontWeight: 600, alignSelf: 'center' }}>23h 59m → No plans</span>
        <div style={{ width: 24, height: 24, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', color: DIM, fontSize: 17, lineHeight: 1, paddingBottom: 2, alignSelf: 'center' }}>+</div>
      </div>
      <TimeLabel>11:59 PM</TimeLabel>
    </div>
    <BNav active={1} />
  </Phone>;


// Quick-add task (keyboard + Speak) - opened by the + button. No bottom nav (keyboard owns the bottom).
// iOS 26 keyboard at iPhone 17 size: 335pt including the QuickType bar,
// measured on device. The sheet rides on top of it; on Android the same sheet
// rides whatever inset the OS reports, so nothing here is hard-wired.
const IOS_KB_H = 335;
const KB_KEY = { flex: 1, height: 42, borderRadius: 8.5, background: '#fff', boxShadow: '0 1px 0 rgba(0,0,0,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: '-apple-system, "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif', fontSize: 23, color: '#111' };
const KB_FN = { ...KB_KEY, flex: 'none', background: '#abb1ba' };
const IOSKeyboard = ({ words = ['I', 'The', 'I’m'] }) =>
<div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: IOS_KB_H, background: '#d1d4da', borderRadius: '28px 28px 0 0', padding: '0 6px' }}>
    <div style={{ height: 50, display: 'flex', alignItems: 'center' }}>
      {words.map((w, i) => <div key={w} style={{ flex: 1, textAlign: 'center', fontFamily: KB_KEY.fontFamily, fontSize: 17, color: '#1c1c1e', borderLeft: i ? '1px solid #b4b9c1' : 'none' }}>{w}</div>)}
    </div>
    <div style={{ display: 'flex', gap: 6.3, marginTop: 3 }}>{'qwertyuiop'.split('').map((k) => <div key={k} style={KB_KEY}>{k}</div>)}</div>
    <div style={{ display: 'flex', gap: 6.3, marginTop: 12, padding: '0 20px' }}>{'asdfghjkl'.split('').map((k) => <div key={k} style={KB_KEY}>{k}</div>)}</div>
    <div style={{ display: 'flex', gap: 6.3, marginTop: 12 }}>
      <div style={{ ...KB_FN, width: 45, marginRight: 8.2, fontSize: 21 }}>⇧</div>
      {'zxcvbnm'.split('').map((k) => <div key={k} style={KB_KEY}>{k}</div>)}
      <div style={{ ...KB_FN, width: 45, marginLeft: 8.2 }}><span className="material-icons-outlined" style={{ fontSize: 21 }}>backspace</span></div>
    </div>
    <div style={{ display: 'flex', gap: 6.3, marginTop: 12 }}>
      <div style={{ ...KB_FN, width: 43.5, fontSize: 16 }}>123</div>
      <div style={{ ...KB_FN, width: 43.5 }}><span className="material-icons-outlined" style={{ fontSize: 22 }}>emoji_emotions</span></div>
      <div style={KB_KEY}></div>
      <div style={{ ...KB_FN, width: 92, background: '#007aff', color: '#fff' }}><Ic n="check" style={{ fontSize: 24 }} /></div>
    </div>
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0 24px', marginTop: 25, color: '#1c1c1e' }}>
      <span className="material-icons-outlined" style={{ fontSize: 26 }}>language</span>
      <Ic n="mic" style={{ fontSize: 26 }} />
    </div>
  </div>;

const PLAN_QUICKADD = () =>
<Phone>
    <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
      <div style={{ padding: '0 16px', opacity: 0.4, pointerEvents: 'none' }}>
        <PlanHeader /><PlanDateStrip />
        <div style={{ marginBottom: 10 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open /></div>
        <PlanTask title="Read chapter 4" dur="10m" tag="CC 401" color={ACC} />
      </div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.28)' }} />
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: WHITE, borderRadius: '22px 22px 0 0', padding: `12px 16px ${IOS_KB_H + 18}px`, boxShadow: '0 -8px 40px rgba(0,0,0,0.16)' }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: BG, borderRadius: 14, padding: '12px 14px', marginBottom: 12 }}>
          <span style={{ flex: 1, fontSize: 17, fontWeight: 600, color: DIM }}>Just one thing to do…<span style={{ color: ACC, fontWeight: 400 }}>|</span></span>
          <Ic n="mic" style={{ fontSize: 19, color: ACC }} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ flex: 1, display: 'flex', gap: 6, overflow: 'hidden' }}>
            {[['schedule', 'Anytime'], ['sell', 'Tag'], ['repeat', 'No repeat']].map(([icon, label]) =>
          <div key={label} style={{ background: BG, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 12px', fontSize: 13, fontWeight: 700, color: MED, display: 'flex', alignItems: 'center', gap: 4, whiteSpace: 'nowrap', flexShrink: 0 }}>
                <Ic n={icon} style={{ fontSize: 16 }} />{label}
              </div>
          )}
          </div>
          <div style={{ background: BG, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 12px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }} title="More options: full task form">
            <Ic n="more" style={{ fontSize: 19, color: MED }} />
          </div>
          <div style={{ width: 38, height: 38, borderRadius: '50%', background: INK, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ic n="send" style={{ fontSize: 18, color: '#fff' }} />
          </div>
        </div>
      </div>
      <IOSKeyboard />
    </div>
  </Phone>;


// "..." overflow menu
const PLAN_MENU = () =>
<Phone>
    <div style={{ height: 742, position: 'relative', padding: '0 16px' }}>
      <div style={{ opacity: 0.35, pointerEvents: 'none' }}>
        <PlanHeader /><PlanDateStrip />
        <div style={{ marginBottom: 10 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open /></div>
        <PlanTask title="Read chapter 4" dur="10m" tag="CC 401" color={ACC} />
      </div>
      <div style={{ position: 'absolute', top: 40, right: 12, width: 220, background: WHITE, borderRadius: 20, boxShadow: '0 14px 44px rgba(0,0,0,0.18)', padding: '8px 0', overflow: 'hidden' }}>
        {[['event_note', 'Reschedule tasks'], ['favorite_border', 'Log mood']].map(([icon, label]) =>
      <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '11px 18px' }}>
            <Ic n={icon} style={{ fontSize: 19, color: TEXT }} />
            <span style={{ fontSize: 17, fontWeight: 600 }}>{label}</span>
          </div>
      )}
        <div style={{ borderTop: `1px solid ${BORDER}`, margin: '6px 0' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 18px' }}>
          <span style={{ fontSize: 17, fontWeight: 800 }}>Grouping options</span>
          <Ic n="chevron_right" style={{ fontSize: 18, color: TEXT }} />
        </div>
      </div>
    </div>
    <BNav active={1} />
  </Phone>;


// Grouping submenu (List / Timeline)
const PLAN_GROUPING = () =>
<Phone>
    <div style={{ height: 742, position: 'relative', padding: '0 16px' }}>
      <div style={{ opacity: 0.35, pointerEvents: 'none' }}>
        <PlanHeader /><PlanDateStrip />
        <div style={{ marginBottom: 10 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open /></div>
        <PlanTask title="Read chapter 4" dur="10m" tag="CC 401" color={ACC} />
      </div>
      <div style={{ position: 'absolute', top: 40, right: 12, width: 220, background: WHITE, borderRadius: 20, boxShadow: '0 14px 44px rgba(0,0,0,0.18)', padding: '8px 0', overflow: 'hidden' }}>
        {[['event_note', 'Reschedule tasks'], ['favorite_border', 'Log mood']].map(([icon, label]) =>
      <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '10px 18px', opacity: 0.4 }}>
            <Ic n={icon} style={{ fontSize: 19, color: TEXT }} />
            <span style={{ fontSize: 17, fontWeight: 600 }}>{label}</span>
          </div>
      )}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 18px' }}>
          <span style={{ fontSize: 17, fontWeight: 800 }}>Grouping options</span>
          <Ic n="chevron_down" style={{ fontSize: 18, color: TEXT }} />
        </div>
        <div style={{ borderTop: `1px solid ${BORDER}`, margin: '4px 0' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 18px' }}>
          <Ic n="list_view" style={{ fontSize: 19, color: TEXT }} />
          <span style={{ fontSize: 17, fontWeight: 600 }}>List</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 18px' }}>
          <Ic n="check" style={{ fontSize: 18, color: ACC }} />
          <Ic n="planner" style={{ fontSize: 19, color: TEXT }} />
          <span style={{ fontSize: 17, fontWeight: 800 }}>Timeline</span>
        </div>
      </div>
    </div>
    <BNav active={1} />
  </Phone>;


// Reschedule - Remaining tasks review
const RESCHEDULE_REMAINING = () =>
<Phone bg={WHITE}>
    <div style={{ height: 816, position: 'relative' }}>
      <div style={{ padding: '4px 18px 0', height: 744, overflow: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <BarDismiss />
        </div>
        <div style={{ display: 'inline-block', background: ACCL, borderRadius: 100, padding: '4px 13px', fontFamily: SANS, fontSize: 17, fontWeight: 700, color: ACC, marginBottom: 8 }}>Wednesday, 3 Jun</div>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 5 }}>Remaining tasks</div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.5, marginBottom: 14 }}>These are the remaining tasks. Anything you want to move to another day?</div>
        <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 10 }}>Move 6 to tomorrow?</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[['Read chapter 4', '10m', 'CC 401', ACC], ['Review lecture slides', '5m', 'NLP 302', '#5cbbff'], ['LL(1) parsing notes', '11:30 AM → 12:00 PM', 'CC 401', ACC]].map(([title, meta, tag, color]) =>
        <div key={title} style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
              <div style={{ width: 24, height: 24, borderRadius: '50%', background: INK, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n="check" style={{ fontSize: 18, color: '#fff' }} /></div>
              <div style={{ flex: 1, background: WHITE, borderRadius: 14, boxShadow: SHADOW, padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 9 }}>
                <div style={{ width: 6, height: 6, borderRadius: '50%', background: color, flexShrink: 0 }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 17, fontWeight: 800 }}>{title}</div>
                  <div style={{ fontSize: 13, color: DIM, fontWeight: 600 }}>{meta}</div>
                </div>
              </div>
            </div>
        )}
        </div>
      </div>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: WHITE, padding: '10px 18px 14px', boxShadow: '0 -6px 20px rgba(0,0,0,0.06)' }}>
        <div style={{ background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff', marginBottom: 8 }}>Move to tomorrow (6)</div>
        <div style={{ border: `1.5px solid ${BORDER}`, borderRadius: 100, height: 50, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: TEXT }}>More options to move (6)</div>
      </div>
    </div>
  </Phone>;


// Reschedule - Move date picker sheet
const RESCHEDULE_MOVE = () =>
<Phone>
    <div style={{ height: 816, position: 'relative' }}>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.28)' }} />
      <div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0, background: WHITE, borderRadius: '22px 22px 0 0', boxShadow: '0 -8px 40px rgba(0,0,0,0.2)', padding: '12px 18px 24px', overflow: 'hidden' }}>
        <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 4 }}>
      <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800 }}>Move (6)</div>
      <BarDismiss tight />
    </div>
    <div style={{ fontSize: 17, color: MED, marginBottom: 14 }}>When do you want to move this to?</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7, marginBottom: 16 }}>
          {[['Read chapter 4', '10m', ACC], ['Review lecture slides', '5m', '#5cbbff']].map(([t, d, c]) =>
        <div key={t} style={{ background: WHITE, borderRadius: 13, boxShadow: SHADOW, padding: '9px 12px', display: 'flex', alignItems: 'center', gap: 9 }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: c }} />
              <div style={{ flex: 1 }}><div style={{ fontSize: 17, fontWeight: 800 }}>{t}</div><div style={{ fontSize: 12, color: DIM, fontWeight: 600 }}>{d}</div></div>
            </div>
        )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontFamily: SANS, fontSize: 17, fontWeight: 800 }}>June 2026 <Ic n="chevron_right" style={{ fontSize: 19, color: ACC }} /></div>
          <div style={{ display: 'flex', gap: 14 }}><Ic n="back" style={{ fontSize: 18, color: DIM }} /><Ic n="chevron_right" style={{ fontSize: 18, color: TEXT }} /></div>
        </div>
        <CalGrid firstCol={0} total={30} accent={4} />
      </div>
      <div style={{ position: 'absolute', bottom: 38, left: 18, right: 18, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff' }}>Move (6) to Thursday, 4 Jun</div>
    </div>
  </Phone>;


// Log mood - opens as a popup over the plan
const PLAN_LOGMOOD = () => {
  const set = [0, 1, 2, 3, 4];
  return (
    <Phone>
      <div style={{ height: 816, position: 'relative' }}>
        <div style={{ padding: '0 16px', opacity: 0.32, pointerEvents: 'none' }}>
          <PlanHeader />
        </div>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.26)' }} />
        <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -8px 40px rgba(0,0,0,0.2)', padding: '12px 18px 38px' }}>
          <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 16px' }} />
          <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, textAlign: 'center', marginBottom: 4 }}>How are you feeling?</div>
          <div style={{ fontSize: 15, color: MED, textAlign: 'center', marginBottom: 20 }}>A quick check-in helps Ada tune your day</div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0 2px', marginBottom: 22 }}>
            {set.map((idx) => {
              const active = idx === 3;
              return (
                <div key={idx} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7, width: 40 }}>
                  <div style={{ padding: 3, borderRadius: '50%', border: active ? `2px solid ${MOODS[idx].color}` : '2px solid transparent', background: active ? MOODS[idx].color + '1e' : 'transparent' }}>
                    <MoodBlob idx={idx} size={34} />
                  </div>
                  <span style={{ fontSize: 12, fontWeight: active ? 800 : 600, color: active ? MOODS[idx].color : MED }}>{MOODS[idx].label}</span>
                </div>);

            })}
          </div>
          <div style={{ width: '100%', height: 50, boxSizing: 'border-box', padding: 0, background: INK, borderRadius: 100, color: '#fff', fontSize: 17, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>Log mood</div>
          <div style={{ textAlign: 'center', fontSize: 15, color: MED, fontWeight: 600 }}>Skip for now</div>
        </div>
      </div>
    </Phone>);

};


/* ─── 03 SUBJECTS ─────────────────────────────────────────────────────── */

const SUBJECTS = [
{ name: 'Compiler Construction', code: 'CC 401', prof: 'Prof. S. Rao', grade: 'A', credits: 4, color: ACC, mood: 1, files: 3, next: 'Viva · 3 days', focus: '4.5h' },
{ name: 'Natural Language Processing', code: 'NLP 302', prof: 'Dr. A. Mehta', grade: 'A−', credits: 3, color: '#5cbbff', mood: 3, files: 2, next: 'Assignment · Fri', focus: '2h' },
{ name: 'Computer Networks', code: 'NET 305', prof: 'Prof. K. Iyer', grade: 'B+', credits: 4, color: SUCC, mood: 2, files: 4, next: 'Lab · tomorrow', focus: '3h' },
{ name: 'Database Systems', code: 'DBS 310', prof: 'Dr. N. Khan', grade: 'A', credits: null, color: WARN, mood: 3, files: 1, next: null, focus: '1.5h' }];


// Shared Subjects header: Share pill (left) + combined ··· / + pill (right). + = add subject.
const SubjHeader = () =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
    <BarPill icon="ios_share" label="Share" />
    <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
      <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 800, color: TEXT, letterSpacing: 0.5, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 24 }} /></div>
      <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Ic n="add" style={{ fontSize: 24, color: TEXT }} />
      </div>
    </div>
  </div>;


// Small tinted grade chip
const GradeChip = ({ grade, color }) =>
<span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, background: color + '1c', color, borderRadius: 7, padding: '2px 7px', fontSize: 13, fontWeight: 800 }}>
    <Ic n="goal" style={{ fontSize: 14 }} />{grade}
  </span>;


// Subject card - list row
const SubjectRow = ({ s }) =>
<div style={{ display: 'flex', alignItems: 'stretch', gap: 11, background: WHITE, borderRadius: 16, boxShadow: SHADOW, padding: '11px 13px' }}>
    <div style={{ width: 4, borderRadius: 4, background: s.color, flexShrink: 0 }} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
        <span style={{ fontSize: 12, fontWeight: 800, color: s.color }}>{s.code}</span>
        {s.credits && <span style={{ fontSize: 12, color: DIM, fontWeight: 700 }}>· {s.credits} cr</span>}
        <span style={{ marginLeft: 'auto' }}><GradeChip grade={s.grade} color={s.color} /></span>
      </div>
      <div style={{ fontSize: 17, fontWeight: 800, lineHeight: 1.2, marginBottom: 3 }}>{s.name}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, fontSize: 13, color: DIM, fontWeight: 600 }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><Ic n="profile" style={{ fontSize: 15 }} />{s.prof}</span>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><Ic n="attach" style={{ fontSize: 15 }} />{s.files}</span>
        {s.next && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, color: s.color }}><span style={{ width: 5, height: 5, borderRadius: '50%', background: s.color }} />{s.next}</span>}
      </div>
    </div>
  </div>;


// Subject card - grid tile
const SubjectTile = ({ s }) =>
<div style={{ background: WHITE, borderRadius: 16, boxShadow: SHADOW, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
    <div style={{ background: s.color, padding: '9px 11px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <span style={{ fontSize: 12, fontWeight: 800, color: '#fff', letterSpacing: '0.04em' }}>{s.code}</span>
      <span style={{ background: 'rgba(255,255,255,0.28)', color: '#fff', borderRadius: 6, padding: '1px 6px', fontSize: 12, fontWeight: 800 }}>{s.grade}</span>
    </div>
    <div style={{ padding: '9px 11px 11px' }}>
      <div style={{ fontSize: 17, fontWeight: 800, lineHeight: 1.2, marginBottom: 4, minHeight: 29 }}>{s.name}</div>
      <div style={{ fontSize: 12, color: DIM, fontWeight: 600, marginBottom: 6 }}>{s.prof}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: MED, fontWeight: 700 }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 2 }}><Ic n="attach" style={{ fontSize: 14 }} />{s.files}</span>
        {s.credits && <span>{s.credits} cr</span>}
      </div>
    </div>
  </div>;


// The Subjects page body - reused dimmed behind the sheets raised from it.
const SubjectsListBody = () =>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <SubjHeader />
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 7 }}>
          <span style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.5 }}>Subjects</span>
          <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>{SUBJECTS.length}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', fontSize: 15, fontWeight: 800, color: MED }}>Spring '26
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, background: ACCL, borderRadius: 14, padding: '9px 12px', marginBottom: 12 }}>
        <AdaBlob size={24} mood="focused" />
        <span style={{ flex: 1, fontSize: 13, color: TEXT, lineHeight: 1.4 }}>2 subjects are missing a syllabus. Add files so I can plan better.</span>
        <span style={{ fontSize: 15, color: ACC, fontWeight: 800 }}>Add →</span>
      </div>
      {SUBJ_LAYOUT === 'Grid' ?
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 9 }}>
          {SUBJECTS.map((s) => <SubjectTile key={s.code} s={s} />)}
        </div> :

    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {SUBJECTS.slice(0, 3).map((s) => <SubjectRow key={s.code} s={s} />)}
        </div>
    }
    </div>;

const SUBJECTS_LIST = () =>
<Phone>
    <SubjectsListBody />
    <BNav active={0} />
  </Phone>;


// Subject detail - info + files bucket + linked tasks + stats
const SUBJECT_DETAIL = () => {
  const s = SUBJECTS[0];
  const files = [
  ['picture_as_pdf', 'Course syllabus.pdf', '420 KB', '#e85476'],
  ['slideshow', 'Lecture 1–9 slides.pdf', '8.2 MB', '#e8a430'],
  ['note', 'My parsing notes.md', '12 KB', '#5cbbff']];

  return (
    <Phone>
      <div style={{ height: 742, overflow: 'hidden' }}>
        {/* hero */}
        <div style={{ background: `linear-gradient(180deg, ${s.color} 0%, ${s.color}b0 55%, ${s.color}55 100%)`, borderRadius: 22, margin: '6px 10px 0', padding: '10px 12px 16px', color: '#fff' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }} data-comment-anchor="1a791bbf92-div-1442-11">
            <BarCircle fill="glass" icon="arrow_back" />
            <BarPill fill="glass" icon="edit" label="Edit" />
          </div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.06em', opacity: 0.85, marginBottom: 3 }}>{s.code}{s.credits ? ` · ${s.credits} CREDITS` : ''}</div>
          <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, lineHeight: 1.15, marginBottom: 8 }}>{s.name}</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontSize: 15, fontWeight: 600, opacity: 0.92, display: 'inline-flex', alignItems: 'center', gap: 4 }}><Ic n="profile" style={{ fontSize: 18 }} />{s.prof}</span>
            <span style={{ background: 'rgba(255,255,255,0.22)', borderRadius: 7, padding: '2px 8px', fontSize: 13, fontWeight: 800, display: 'inline-flex', alignItems: 'center', gap: 3 }}><Ic n="goal" style={{ fontSize: 14 }} />Target {s.grade}</span>
          </div>
        </div>
        <div style={{ padding: '12px 16px', height: 280, overflow: 'hidden' }}>
          {/* emotion + stats row */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
            <div style={{ flex: 1, background: WHITE, borderRadius: 14, boxShadow: SHADOW, padding: '9px 11px', display: 'flex', alignItems: 'center', gap: 8 }}>
              <MoodBlob idx={s.mood} size={26} />
              <div><div style={{ fontSize: 12, color: DIM, fontWeight: 700 }}>You feel</div><div style={{ fontSize: 15, fontWeight: 800, color: MOODS[s.mood].color }}>{MOODS[s.mood].label}</div></div>
            </div>
            <div style={{ flex: 1, background: WHITE, borderRadius: 14, boxShadow: SHADOW, padding: '9px 11px', display: 'flex', alignItems: 'center', gap: 8 }}>
              <Ic n="focus" style={{ fontSize: 20, color: s.color }} />
              <div><div style={{ fontSize: 12, color: DIM, fontWeight: 700 }}>This week</div><div style={{ fontSize: 15, fontWeight: 800 }}>{s.focus} focus</div></div>
            </div>
          </div>
          {/* files bucket */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 7 }}>
            <SLabel>Materials ({s.files})</SLabel>
            <span style={{ fontSize: 13, fontWeight: 800, color: ACC, display: 'inline-flex', alignItems: 'center', gap: 2 }}><Ic n="add" style={{ fontSize: 16 }} />Add file</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {files.map(([icon, name, size, c]) =>
            <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 10, background: WHITE, borderRadius: 12, boxShadow: SHADOW, padding: '8px 11px' }}>
                <div style={{ width: 30, height: 30, borderRadius: 9, background: c + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n={icon} style={{ fontSize: 20, color: c }} /></div>
                <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 15, fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{name}</div><div style={{ fontSize: 12, color: DIM, fontWeight: 600 }}>{size}</div></div>
                <Ic n="more_vertical" style={{ fontSize: 18, color: DIM }} />
              </div>
            )}
          </div>
        </div>
      </div>
      <BNav active={0} />
    </Phone>);

};


// Add file - bottom sheet with source options
const ADD_FILE_SHEET = () =>
<Phone>
    <div style={{ opacity: 0.35, pointerEvents: 'none' }}><SubjectsListBody /></div>
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.3)' }} />
    <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -10px 44px rgba(0,0,0,0.22)', padding: '12px 18px 38px' }}>
      <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 16px' }} />
      <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800, marginBottom: 2 }}>Add to Compiler Construction</div>
      <div style={{ fontSize: 15, color: MED, marginBottom: 16 }}>Ada can read these to plan smarter</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
        {[['description', 'Syllabus', 'PDF or doc. Ada builds your plan from it', ACC], ['slideshow', 'Lecture slides', 'Decks and handouts', '#e8a430'], ['edit_note', 'Notes', 'Your own notes & summaries', '#5cbbff'], ['quiz', 'Past papers', 'Previous exams to practice', SUCC]].map(([icon, label, sub, c]) =>
      <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 12, background: BG, borderRadius: 14, padding: '11px 13px' }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: c + '1c', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n={icon} style={{ fontSize: 19, color: c }} /></div>
            <div style={{ flex: 1 }}><div style={{ fontSize: 17, fontWeight: 800 }}>{label}</div><div style={{ fontSize: 12, color: DIM, fontWeight: 600 }}>{sub}</div></div>
            <Ic n="chevron_right" style={{ fontSize: 18, color: DIM }} />
          </div>
      )}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, border: `1.5px solid ${BORDER}`, borderRadius: 100, padding: '11px 0', textAlign: 'center', fontSize: 17, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}><Ic n="folder" style={{ fontSize: 20 }} />Browse</div>
        <div style={{ flex: 1, border: `1.5px solid ${BORDER}`, borderRadius: 100, padding: '11px 0', textAlign: 'center', fontSize: 17, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}><Ic n="scan" style={{ fontSize: 20 }} />Scan</div>
      </div>
    </div>
  </Phone>;


// Add / edit subject - full form
// Add / edit subject - full form. `fmt` selects the Target-grade input mode
// (Letter chips / GPA field / % field), exposed as separate frames below.
const AddSubjectBody = ({ fmt = 'Letter' }) =>
<div style={{ height: 792, overflow: 'hidden' }}>
      <div style={{ background: WHITE, borderRadius: 22, padding: '12px 16px 13px', margin: '4px 10px 8px', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 11 }}>
          <BarDismiss edge="left" />
          <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 800 }}>New subject</div>
          <BarPill fill="ink" label="Save" />
        </div>
        <div style={{ background: BG, borderRadius: 12, padding: '12px 14px', fontSize: 17, fontWeight: 700, color: TEXT }}>Compiler Construction<span style={{ color: ACC }}>|</span></div>
      </div>
      <div style={{ padding: '0 16px' }}>
        {/* code + credits row */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 9 }}>
          <div style={{ flex: 1 }}><SLabel>Code</SLabel><div style={{ background: WHITE, borderRadius: 12, boxShadow: SHADOW, padding: '10px 12px', fontSize: 17, fontWeight: 700 }}>CC 401</div></div>
          <div style={{ flex: 1 }}><SLabel>Credits <span style={{ color: DIM, fontWeight: 600 }}>· optional</span></SLabel><div style={{ background: WHITE, borderRadius: 12, boxShadow: SHADOW, padding: '10px 12px', fontSize: 17, fontWeight: 700, display: 'flex', justifyContent: 'space-between', color: DIM }}>Add<span style={{ color: TEXT }}>＋</span></div></div>
        </div>
        {/* professor */}
        <SLabel>Professor</SLabel>
        <div style={{ background: WHITE, borderRadius: 12, boxShadow: SHADOW, padding: '10px 12px', fontSize: 17, fontWeight: 700, marginBottom: 9 }}>Prof. S. Rao</div>
        {/* target grade with format selector */}
        <SLabel>Target grade</SLabel>
        <div style={{ display: 'flex', gap: 6, marginBottom: 7 }}>
          {['Letter', 'GPA', '%'].map((f) =>
      <div key={f} style={{ flex: 1, textAlign: 'center', padding: '6px 0', borderRadius: 9, fontSize: 15, fontWeight: 800, background: f === fmt ? INK : WHITE, color: f === fmt ? '#fff' : MED, boxShadow: SHADOW }}>{f}</div>
      )}
        </div>
        {fmt === 'Letter' &&
    <div style={{ display: 'flex', gap: 6, marginBottom: 9 }}>
            {['A+', 'A', 'A−', 'B+', 'B'].map((g, i) =>
      <div key={g} style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderRadius: 9, fontSize: 17, fontWeight: 800, background: i === 1 ? ACCL : WHITE, color: i === 1 ? ACC : TEXT, border: `1.5px solid ${i === 1 ? ACC : BORDER}` }}>{g}</div>
      )}
          </div>
    }
        {fmt === 'GPA' &&
    <div style={{ background: WHITE, borderRadius: 12, boxShadow: SHADOW, border: `1.5px solid ${ACC}`, padding: '11px 14px', marginBottom: 9, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: -0.5 }}>3.7<span style={{ color: ACC, fontWeight: 400 }}>|</span></span>
            <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>out of 4.0</span>
          </div>
    }
        {fmt === '%' &&
    <div style={{ background: WHITE, borderRadius: 12, boxShadow: SHADOW, border: `1.5px solid ${ACC}`, padding: '11px 14px', marginBottom: 9, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: -0.5 }}>85<span style={{ fontSize: 17, color: MED }}>%</span><span style={{ color: ACC, fontWeight: 400 }}>|</span></span>
            <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>target %</span>
          </div>
    }
        {/* color */}
        <SLabel>Colour</SLabel>
        <div style={{ display: 'flex', gap: 9, marginBottom: 9 }}>
          {[ACC, '#5cbbff', SUCC, WARN, '#e85476', '#c0497b'].map((c, i) =>
      <div key={c} style={{ width: 26, height: 26, borderRadius: '50%', background: c, border: i === 0 ? `2.5px solid ${TEXT}` : '2.5px solid transparent', boxShadow: i === 0 ? `0 0 0 2px ${WHITE}` : 'none' }} />
      )}
        </div>
        {/* emotion */}
        <SLabel>How do you feel about it?</SLabel>
        <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0 2px' }}>
          {MOODS.map((m, i) =>
      <div key={i} style={{ padding: 2.5, borderRadius: '50%', border: i === 1 ? `2px solid ${m.color}` : '2px solid transparent', background: i === 1 ? m.color + '20' : 'transparent' }}>
              <MoodBlob idx={i} size={i === 1 ? 32 : 29} />
            </div>
      )}
        </div>
      </div>
    </div>;

const ADD_SUBJECT = () => <Phone bg={PAGE}><AddSubjectBody /></Phone>;
const ADD_SUBJECT_GPA = () => <Phone bg={PAGE}><AddSubjectBody fmt="GPA" /></Phone>;
const ADD_SUBJECT_PCT = () => <Phone bg={PAGE}><AddSubjectBody fmt="%" /></Phone>;


// "···" overflow - semester selector + manage
const SUBJECT_MENU = () =>
<Phone>
    <div style={{ height: 742, position: 'relative', padding: '0 16px' }}>
      <div style={{ opacity: 0.35, pointerEvents: 'none' }}>
        <SubjHeader />
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 7, marginBottom: 12 }}>
          <span style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800 }}>Subjects</span>
          <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>4</span>
        </div>
        <SubjectRow s={SUBJECTS[0]} />
      </div>
      <div style={{ position: 'absolute', top: 44, right: 12, width: 224, background: WHITE, borderRadius: 20, boxShadow: '0 14px 44px rgba(0,0,0,0.18)', padding: '10px 0', overflow: 'hidden' }}>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', color: DIM, padding: '4px 18px 8px' }}>SEMESTER</div>
        {[["Spring '26", true], ["Fall '25", false], ["Spring '25", false]].map(([t, on]) =>
      <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 18px' }}>
            <Ic n="check" style={{ fontSize: 21, color: on ? ACC : 'transparent' }} />
            <span style={{ fontSize: 17, fontWeight: on ? 800 : 600, color: on ? TEXT : MED }}>{t}</span>
          </div>
      )}
        <div style={{ borderTop: `1px solid ${BORDER}`, margin: '6px 0' }} />
        {[['add', 'Add semester'], ['edit_calendar', 'Edit semesters'], ['sort', 'Sort subjects']].map(([icon, label]) =>
      <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 18px' }}>
            <Ic n={icon} style={{ fontSize: 18, color: TEXT }} />
            <span style={{ fontSize: 17, fontWeight: 600 }}>{label}</span>
          </div>
      )}
      </div>
    </div>
    <BNav active={0} />
  </Phone>;


// Shared shell for the semester-menu action sheets: dimmed Subjects list
// behind a bottom sheet, matching the picker-sheet language used in 02 - Plan.
const SubjSheet = ({ title, sub, children, cta }) =>
<Phone>
    <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
      <div style={{ opacity: 0.3, pointerEvents: 'none', padding: '0 16px' }}>
        <SubjHeader />
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 7, marginBottom: 12 }}>
          <span style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800 }}>Subjects</span>
          <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>4</span>
        </div>
        <SubjectRow s={SUBJECTS[0]} />
        <SubjectRow s={SUBJECTS[1]} />
      </div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.30)' }} />
      <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -8px 40px rgba(0,0,0,0.22)', padding: '12px 18px 34px' }}>
        <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: sub ? 3 : 14 }}>
      <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>{title}</div>
      <BarDismiss tight />
    </div>
    {sub && <div style={{ fontSize: 15, color: MED, marginBottom: 14 }}>{sub}</div>}
        {children}
        {cta && <div style={{ marginTop: 16, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff' }}>{cta}</div>}
      </div>
    </div>
  </Phone>;

// Add semester
const SUBJECT_ADD_SEM = () =>
<SubjSheet title="Add semester" cta="Create semester">
    <SLabel>Name</SLabel>
    <div style={{ background: BG, borderRadius: 12, padding: '11px 14px', fontSize: 17, fontWeight: 700, marginBottom: 12 }}>Fall '26<span style={{ color: ACC, fontWeight: 400 }}>|</span></div>
    <SLabel>Term</SLabel>
    <div style={{ display: 'flex', gap: 7, marginBottom: 12 }}>
      {[['Spring', false], ['Summer', false], ['Fall', true]].map(([t, a]) =>
    <div key={t} style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderRadius: 11, fontSize: 17, fontWeight: 800, background: a ? ACCL : BG, color: a ? ACC : MED, border: `1.5px solid ${a ? ACC : 'transparent'}` }}>{t}</div>
    )}
    </div>
    <div style={{ display: 'flex', gap: 10 }}>
      <div style={{ flex: 1 }}><SLabel>Starts</SLabel><div style={{ background: BG, borderRadius: 12, padding: '11px 14px', fontSize: 17, fontWeight: 700, color: TEXT }}>1 Sep 2026</div></div>
      <div style={{ flex: 1 }}><SLabel>Ends</SLabel><div style={{ background: BG, borderRadius: 12, padding: '11px 14px', fontSize: 17, fontWeight: 700, color: TEXT }}>20 Dec 2026</div></div>
    </div>
  </SubjSheet>;

// Edit semesters
const SUBJECT_EDIT_SEM = () =>
<SubjSheet title="Edit semesters" sub="Rename, reorder or remove a term">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {[["Spring '26", '4 subjects', true], ["Fall '25", '5 subjects', false], ["Spring '25", '4 subjects', false]].map(([t, n, cur]) =>
    <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 11, background: BG, borderRadius: 14, padding: '11px 14px' }}>
          <Ic n="drag" style={{ fontSize: 18, color: DIM }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 800 }}>{t}{cur && <span style={{ fontSize: 12, fontWeight: 800, color: ACC, background: ACCL, borderRadius: 100, padding: '2px 7px', marginLeft: 7 }}>Current</span>}</div>
            <div style={{ fontSize: 13, color: DIM, fontWeight: 600, marginTop: 1 }}>{n}</div>
          </div>
          <Ic n="edit" style={{ fontSize: 21, color: MED }} />
          <Ic n="delete" style={{ fontSize: 21, color: '#e85476' }} />
        </div>
    )}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, border: `1.5px dashed ${BORDER}`, borderRadius: 14, minHeight: 52, boxSizing: 'border-box', color: ACC, fontSize: 17, fontWeight: 800 }}>
        <Ic n="add" style={{ fontSize: 21 }} />Add semester
      </div>
    </div>
  </SubjSheet>;

// Sort subjects
const SUBJECT_SORT = () =>
<SubjSheet title="Sort subjects" sub="Choose how your subjects are ordered">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
      <OptRow icon="drag_indicator" label="Manual order" sub="Drag to arrange" active />
      <OptRow icon="sort_by_alpha" label="Alphabetical" sub="A → Z" />
      <OptRow icon="grade" label="Grade" sub="Highest target first" />
      <OptRow icon="workspace_premium" label="Credits" sub="Most credits first" />
      <OptRow icon="sentiment_satisfied" label="Mood" sub="How you feel about each" />
    </div>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 12, padding: '0 6px' }}>
      <span style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>Reverse order</span>
      <div style={{ width: 40, height: 23, borderRadius: 100, background: BG, position: 'relative' }}><div style={{ width: 19, height: 19, borderRadius: '50%', background: WHITE, boxShadow: '0 1px 3px rgba(0,0,0,0.2)', position: 'absolute', top: 2, left: 2 }} /></div>
    </div>
  </SubjSheet>;


/* ─── 03 TASKS (legacy, unused) ───────────────────────────────────────── */
const TK_LIST = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ background: WHITE, borderRadius: 100, padding: '6px 13px', boxShadow: SHADOW, display: 'flex', alignItems: 'center', gap: 6 }}>
          <Ic n="share" style={{ fontSize: 19, color: TEXT }} />
          <span style={{ fontSize: 17, fontWeight: 800 }}>Share</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 800, color: TEXT, letterSpacing: 0.5, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 24 }} /></div>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ic n="add" style={{ fontSize: 24, color: TEXT }} />
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', background: BG, borderRadius: 10, padding: 2, marginBottom: 10 }}>
        {['Today', 'This week', 'All'].map((t, i) =>
      <div key={t} style={{ flex: 1, textAlign: 'center', padding: '5px 0', fontSize: 15, fontWeight: 700, borderRadius: 8, background: i === 0 ? WHITE : 'transparent', color: i === 0 ? TEXT : DIM, boxShadow: i === 0 ? '0 1px 4px rgba(0,0,0,0.08)' : 'none' }}>{t}</div>
      )}
      </div>
      <Card style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10, background: ACCL, boxShadow: 'none', padding: '8px 12px' }}>
        <AdaBlob size={22} mood="focused" />
        <span style={{ flex: 1, fontSize: 15, color: TEXT }}>"Networks deadline in 3 days. Schedule revision?"</span>
        <span style={{ fontSize: 15, color: ACC, fontWeight: 700 }}>Yes →</span>
      </Card>
      <Card style={{ marginBottom: 7, border: `1.5px solid ${ACC}22`, padding: '10px 12px' }}>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 4 }}>
          <Chip active style={{ fontSize: 12, padding: '2px 8px' }}>CC 401</Chip>
          <span style={{ fontSize: 12, color: DIM, marginLeft: 'auto' }}>35 min</span>
        </div>
        <div style={{ fontSize: 17, fontWeight: 700, marginBottom: 2 }}>LL(1) parsing notes</div>
        <div style={{ fontSize: 13, color: DIM, marginBottom: 8 }}>3 microtasks · Due today · Ada generated</div>
        <div style={{ borderTop: `1px solid ${BORDER}`, paddingTop: 8 }}>
          <SLabel>Microtasks</SLabel>
          {[[true, 'Read lecture 9 slides', '10m'], [false, 'Build parsing table', '15m'], [false, 'Solve 2 practice problems', '10m']].map(([done, text, t], i) =>
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '3px 0' }}>
              <div style={{ width: 14, height: 14, borderRadius: '50%', background: done ? ACC : 'transparent', border: `1.5px solid ${done ? ACC : DIM}`, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {done && <Ic n="check" sw={2.8} style={{ fontSize: 10, color: '#fff' }} />}
              </div>
              <span style={{ flex: 1, fontSize: 15, color: done ? DIM : TEXT, textDecoration: done ? 'line-through' : 'none' }}>{text}</span>
              <span style={{ fontSize: 13, color: DIM }}>{t}</span>
            </div>
        )}
        </div>
      </Card>
      {[['NLP 302', 'Assignment 3 draft', '45 min', '#5cbbff'], ['NET 305', 'Packet Tracer lab 4', '30 min · Due tomorrow', WARN]].map(([tag, name, info, color]) =>
    <Card key={name} style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 6, padding: '10px 12px' }}>
          <div style={{ width: 7, height: 7, borderRadius: '50%', background: color, flexShrink: 0 }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 700 }}>{name}</div>
            <div style={{ fontSize: 13, color: DIM }}>{tag} · {info}</div>
          </div>
        </Card>
    )}
    </div>
    <BNav active={0} />
  </Phone>;


/* ─── ADD TASK (QUICK) ────────────────────────────────────────────────── */
const ADD_TASK_QUICK = () =>
<Phone>
    {/* dimmed real Tasks page behind - consistent with the other task sheets */}
    <div style={{ padding: '0 16px', opacity: 0.4, pointerEvents: 'none' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ background: WHITE, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 13px', boxShadow: SHADOW, display: 'flex', alignItems: 'center', gap: 6 }}>
          <Ic n="share" style={{ fontSize: 19, color: TEXT }} />
          <span style={{ fontSize: 17, fontWeight: 800 }}>Share</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 12px', boxShadow: SHADOW }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 800, color: TEXT, letterSpacing: 0.5, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 24 }} /></div>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ic n="add" style={{ fontSize: 24, color: TEXT }} />
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', background: BG, borderRadius: 10, padding: 2, marginBottom: 10 }}>
        {['Today', 'This week', 'All'].map((t, i) =>
      <div key={t} style={{ flex: 1, textAlign: 'center', padding: '5px 0', fontSize: 15, fontWeight: 700, borderRadius: 8, background: i === 0 ? WHITE : 'transparent', color: i === 0 ? TEXT : DIM }}>{t}</div>
      )}
      </div>
      {[['CC 401', ACC, 'LL(1) parsing notes', 'Due today'], ['NLP 302', '#5cbbff', 'Assignment 3 draft', '45 min']].map(([tag, color, name, info]) =>
    <Card key={name} style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 6, padding: '10px 12px' }}>
          <div style={{ width: 7, height: 7, borderRadius: '50%', background: color, flexShrink: 0 }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 700 }}>{name}</div>
            <div style={{ fontSize: 13, color: DIM }}>{tag} · {info}</div>
          </div>
        </Card>
    )}
    </div>
    {/* scrim */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.28)' }} />
    {/* quick-add sheet */}
    <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, padding: '12px 16px 34px', boxShadow: '0 -8px 40px rgba(0,0,0,0.16)' }}>
      <div style={{ width: 36, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
      {/* text input with mic */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: BG, borderRadius: 14, padding: '12px 14px', marginBottom: 12 }}>
        <span style={{ flex: 1, fontSize: 17, fontWeight: 600, color: DIM }}>Just one thing to do…<span style={{ color: ACC, fontWeight: 400 }}>|</span></span>
        <Ic n="mic" style={{ fontSize: 19, color: ACC }} />
      </div>
      {/* options scroll-row + send button (won't overlap) */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ flex: 1, display: 'flex', gap: 6, overflow: 'hidden' }}>
          {[['schedule', 'Anytime'], ['sell', 'Tag'], ['repeat', 'No repeat']].map(([icon, label]) =>
        <div key={label} style={{ background: BG, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 12px', fontSize: 13, fontWeight: 700, color: MED, display: 'flex', alignItems: 'center', gap: 4, whiteSpace: 'nowrap', flexShrink: 0 }}>
              <Ic n={icon} style={{ fontSize: 16 }} />{label}
            </div>
        )}
        </div>
        <div style={{ width: 38, height: 38, borderRadius: '50%', background: INK, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Ic n="send" style={{ fontSize: 18, color: '#fff' }} />
        </div>
      </div>
    </div>
  </Phone>;


/* ─── ADD TASK (FULL FORM) ────────────────────────────────────────────── */
// Body of the Add task form, factored out so the field-pickers below can show
// it dimmed behind their sheets. `hi` highlights the row currently being edited
// and `vals` overrides the detail-row values shown.
const AddTaskBody = ({ hi, vals = {} }) =>
<div style={{ height: 792, overflow: 'hidden' }}>
      {/* header */}
      <div style={{ background: WHITE, borderRadius: 22, padding: '12px 16px 13px', margin: '4px 10px 6px', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <BarDismiss edge="left" />
          <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 800 }}>Add task</div>
          <BarPill fill="ink" label="Save" />
        </div>
        <div style={{ background: BG, borderRadius: 12, padding: '12px 14px', fontSize: 17, fontWeight: 600, color: DIM }}>What do you need to do?</div>
      </div>
      {/* tag picker */}
      <div style={{ marginBottom: 6 }}>
        <div style={{ padding: '0 16px' }}><SLabel>Tag · what's this for?</SLabel></div>
        <div style={{ display: 'flex', gap: 6, overflow: 'hidden', padding: '0 16px' }}>
          {TASK_TAGS.map((t, i) => <TagChip key={t.label} label={t.label} color={t.color} active={i === 2} style={{ flexShrink: 0 }} />)}
          <TagChip label="+ New" color={ACC} dashed style={{ flexShrink: 0 }} />
        </div>
      </div>
      {/* subject link */}
      <div style={{ marginBottom: 6 }}>
        <div style={{ padding: '0 16px' }}><SLabel>Subject · link it (optional)</SLabel></div>
        <div style={{ display: 'flex', gap: 6, overflow: 'hidden', padding: '0 16px' }}>
          {SUBJECTS.map((s, i) => <TagChip key={s.code} label={s.code} color={s.color} active={i === 0} style={{ flexShrink: 0 }} />)}
          <TagChip label="+ None" color={MED} dashed style={{ flexShrink: 0 }} />
        </div>
      </div>
      {/* details */}
      <div style={{ padding: '0 16px' }}>
        <Card style={{ marginBottom: 8, padding: '2px 14px' }}>
          {[['schedule', 'Time of day', 'Anytime'], ['event', 'Date', '18 May 2026'], ['hourglass_empty', 'Duration', '30 min'], ['repeat', 'Repeat', 'No repeat']].map(([icon, label, val], i, a) => {
        const on = hi === label;
        return (
          <div key={label} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', backgroundImage: i < a.length - 1 ? `linear-gradient(${BORDER}, ${BORDER})` : 'none', backgroundSize: `calc(100% - 30px) 1px`, backgroundPosition: '100% 100%', backgroundRepeat: 'no-repeat' }}>
              <Ic n={icon} style={{ fontSize: 20, color: on ? ACC : MED }} />
              <span style={{ flex: 1, fontSize: 17, fontWeight: on ? 800 : 600, color: on ? ACC : TEXT }}>{label}</span>
              <div style={{ background: on ? ACC : BG, borderRadius: 100, display: 'inline-flex', alignItems: 'center', height: 36, boxSizing: 'border-box', padding: '0 12px', fontSize: 15, fontWeight: on ? 800 : 600, color: on ? '#fff' : MED }}>{vals[label] || val}</div>
            </div>);

      })}
        </Card>
        {/* Ada auto-breakdown */}
        <Card style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
          <AdaBlob size={28} mood="focused" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 700 }}>Let Ada break this down</div>
          </div>
          <div style={{ width: 38, height: 22, borderRadius: 11, background: ACC, display: 'flex', alignItems: 'center', padding: 2, justifyContent: 'flex-end', flexShrink: 0 }}>
            <div style={{ width: 18, height: 18, borderRadius: '50%', background: WHITE }} />
          </div>
        </Card>
        <Card style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Ic n="note" style={{ fontSize: 20, color: MED }} />
          <span style={{ fontSize: 17, color: DIM }}>Add a note…</span>
        </Card>
      </div>
    </div>;

const ADD_TASK_FULL = () => <Phone bg={PAGE}><AddTaskBody /></Phone>;


/* ─── ADD TASK - field picker sheets ──────────────────────────────────── */

// One menu row inside a picker sheet.
const OptRow = ({ icon, label, sub, active, right }) =>
<div style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 12, padding: '8px 10px', borderRadius: 12, background: active ? ACCL : 'transparent' }}>
    {icon && <Ic n={icon} style={{ fontSize: 19, color: active ? ACC : MED }} />}
    <div style={{ flex: 1 }}>
      <div style={{ fontSize: 17, fontWeight: active ? 800 : 600, color: active ? ACC : TEXT }}>{label}</div>
      {sub && <div style={{ fontSize: 13, color: DIM, fontWeight: 600, marginTop: 1 }}>{sub}</div>}
    </div>
    {right || active && <Ic n="check" style={{ fontSize: 20, color: ACC }} />}
  </div>;

// A small "Set →" pill used as the trailing affordance on some rows.
const SetPill = () =>
<div style={{ background: BG, borderRadius: 100, display: 'inline-flex', alignItems: 'center', height: 36, boxSizing: 'border-box', padding: '0 12px', fontSize: 15, fontWeight: 700, color: MED }}>Set →</div>;

// Shared sheet shell: dimmed Add-task form behind + bottom sheet.
const PickerSheet = ({ hi, vals, title, sub, children, cta }) =>
<Phone bg={PAGE}>
    <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
      <div style={{ opacity: 0.28, pointerEvents: 'none' }}><AddTaskBody hi={hi} vals={vals} /></div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.30)' }} />
      <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -8px 40px rgba(0,0,0,0.22)', padding: '12px 18px 34px' }}>
        <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: sub ? 3 : 12 }}>
      <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>{title}</div>
      <BarDismiss tight />
    </div>
    {sub && <div style={{ fontSize: 15, color: MED, marginBottom: 12 }}>{sub}</div>}
        {children}
        {cta && <div style={{ marginTop: 14, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff' }}>{cta}</div>}
      </div>
    </div>
  </Phone>;

// Time-of-day selector
const PICK_TIMEOFDAY = () =>
<PickerSheet hi="Time of day" title="Time of day" sub="When should this land in your day?">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
      <OptRow icon="all_inclusive" label="Anytime" sub="Ada slots it into a free moment" active />
      <OptRow icon="wb_twilight" label="Morning" sub="Before 12 PM" />
      <OptRow icon="light_mode" label="Afternoon" sub="12 – 5 PM" />
      <OptRow icon="nights_stay" label="Evening" sub="After 5 PM" />
      <OptRow icon="schedule" label="Specific time" right={<SetPill />} />
    </div>
  </PickerSheet>;

// Date selector - calendar
const PICK_DATE = () =>
<PickerSheet hi="Date" vals={{ Date: 'Mon, 18 May' }} title="Pick a date" cta="Set date · Mon, 18 May">
    <div style={{ display: 'flex', gap: 6, marginBottom: 14, overflow: 'hidden' }}>
      {[['Today', false], ['Tomorrow', false], ['18 May', true], ['Next week', false]].map(([t, a]) =>
    <div key={t} style={{ flexShrink: 0, background: a ? ACC : BG, color: a ? '#fff' : MED, borderRadius: 100, display: 'inline-flex', alignItems: 'center', height: 36, boxSizing: 'border-box', padding: '0 12px', fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap' }}>{t}</div>
    )}
    </div>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
      <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 800 }}>May 2026</div>
      <div style={{ display: 'flex', gap: 14 }}><Ic n="back" style={{ fontSize: 18, color: DIM }} /><Ic n="chevron_right" style={{ fontSize: 18, color: TEXT }} /></div>
    </div>
    <CalGrid firstCol={4} total={31} accent={18} />
  </PickerSheet>;

// Duration selector
const PICK_DURATION = () =>
<PickerSheet hi="Duration" title="Duration" sub="How long do you expect this to take?">
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8, marginBottom: 10 }}>
      {[['15 min', false], ['25 min', false], ['30 min', true], ['45 min', false], ['1 hr', false], ['1.5 hr', false]].map(([t, a]) =>
    <div key={t} style={{ textAlign: 'center', padding: '14px 0', borderRadius: 14, background: a ? ACC : BG, color: a ? '#fff' : TEXT, fontSize: 17, fontWeight: a ? 800 : 700 }}>{t}</div>
    )}
    </div>
    <OptRow icon="tune" label="Custom duration" right={<SetPill />} />
  </PickerSheet>;

// Repeat selector
const PICK_REPEAT = () =>
<PickerSheet hi="Repeat" title="Repeat" sub="Make this a recurring task">
    <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
      <OptRow icon="block" label="No repeat" active />
      <OptRow icon="today" label="Every day" />
      <OptRow icon="work_outline" label="Weekdays" sub="Mon – Fri" />
      <OptRow icon="event_repeat" label="Weekly" sub="Every Monday" />
      <OptRow icon="calendar_month" label="Monthly" sub="On the 18th" />
      <OptRow icon="tune" label="Custom…" right={<SetPill />} />
    </div>
  </PickerSheet>;


/* ─── ADD TASK - custom value dialogs (floating, centered) ────────────── */
// Centered modal shell for fine-tuning a value (vs. the bottom-sheet pickers).
const CenterDialog = ({ hi, vals, title, sub, children, cta, w = 252 }) =>
<Phone bg={PAGE}>
    <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
      <div style={{ opacity: 0.26, pointerEvents: 'none' }}><AddTaskBody hi={hi} vals={vals} /></div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.40)' }} />
      <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: w, background: WHITE, borderRadius: 24, boxShadow: '0 20px 64px rgba(0,0,0,0.34)', padding: '17px 18px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: sub ? 3 : 14 }}>
      <div style={{ minWidth: 0, fontFamily: SANS, fontSize: 22, fontWeight: 800, whiteSpace: 'nowrap' }}>{title}</div>
      <BarDismiss tight />
    </div>
    {sub && <div style={{ fontSize: 15, color: MED, marginBottom: 14 }}>{sub}</div>}
        {children}
        {cta && <div style={{ marginTop: 16, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff' }}>{cta}</div>}
      </div>
    </div>
  </Phone>;

// One column of a faux time wheel: faded neighbours, bold centered value.
const TimeWheelCol = ({ rows }) =>
<div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 9 }}>
    {rows.map((r, i) =>
  <div key={i} style={{ fontSize: r.sel ? 28 : 17, lineHeight: 1, fontWeight: r.sel ? 800 : 600, color: r.sel ? TEXT : '#c8c4be', fontVariantNumeric: 'tabular-nums' }}>{r.t}</div>
  )}
  </div>;

// Time of day → Specific time (hour:minute wheel + AM/PM segmented)
const PICK_TIME_SPECIFIC = () =>
<CenterDialog hi="Time of day" vals={{ 'Time of day': '2:30 PM' }} title="Set time" sub="Pick the exact start time" cta="Set · 2:30 PM">
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ flex: 1, position: 'relative' }}>
        <div style={{ position: 'absolute', top: '50%', left: -2, right: -2, transform: 'translateY(-50%)', height: 40, background: ACCL, borderRadius: 12 }} />
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
          <TimeWheelCol rows={[{ t: '1' }, { t: '2', sel: true }, { t: '3' }]} />
          <div style={{ fontSize: 22, fontWeight: 800, color: TEXT, paddingBottom: 2 }}>:</div>
          <TimeWheelCol rows={[{ t: '15' }, { t: '30', sel: true }, { t: '45' }]} />
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ padding: '7px 13px', borderRadius: 10, background: BG, color: MED, fontSize: 17, fontWeight: 700, textAlign: 'center' }}>AM</div>
        <div style={{ padding: '7px 13px', borderRadius: 10, background: ACC, color: '#fff', fontSize: 17, fontWeight: 800, textAlign: 'center' }}>PM</div>
      </div>
    </div>
  </CenterDialog>;

// Round stepper button used by the duration dialog.
const StepBtn = ({ icon }) =>
<div style={{ width: 38, height: 38, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
    <Ic n={icon} style={{ fontSize: 20, color: TEXT }} />
  </div>;

// Duration → Custom duration (stepper + slider + quick chips)
const PICK_DURATION_CUSTOM = () =>
<CenterDialog hi="Duration" vals={{ Duration: '50 min' }} title="Custom duration" sub="Fine-tune the time you need" cta="Set · 50 min">
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18, marginBottom: 14 }}>
      <StepBtn icon="remove" />
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{ fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 50, fontWeight: 800, color: TEXT, lineHeight: 1 }}>50</span>
        <span style={{ fontSize: 17, fontWeight: 700, color: MED }}>min</span>
      </div>
      <StepBtn icon="add" />
    </div>
    <div style={{ position: 'relative', height: 6, background: BG, borderRadius: 3, marginBottom: 14 }}>
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '42%', background: ACC, borderRadius: 3 }} />
      <div style={{ position: 'absolute', left: '42%', top: '50%', transform: 'translate(-50%,-50%)', width: 18, height: 18, borderRadius: '50%', background: WHITE, boxShadow: '0 2px 8px rgba(0,0,0,0.25)', border: `2px solid ${ACC}` }} />
    </div>
    <div style={{ display: 'flex', gap: 6 }}>
      {[['45 min', false], ['1 hr', false], ['1.5 hr', false], ['2 hr', false]].map(([t, a]) =>
    <div key={t} style={{ flex: 1, height: 36, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 100, background: a ? ACC : BG, color: a ? '#fff' : MED, fontSize: 15, fontWeight: 700, whiteSpace: 'nowrap' }}>{t}</div>
    )}
    </div>
  </CenterDialog>;

// Repeat → Custom… (interval stepper + unit + weekday selector)
const PICK_REPEAT_CUSTOM = () =>
<CenterDialog hi="Repeat" vals={{ Repeat: 'Every 2 weeks' }} title="Custom repeat" sub="Set your own recurring rhythm" cta="Save · Every 2 weeks" w={344}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
      <span style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>Repeat every</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ width: 24, height: 24, margin: 2, borderRadius: '50%', border: `2px solid ${MED}`, boxSizing: 'border-box', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}><Ic n="remove" style={{ fontSize: 16, color: MED }} /></span>
        <span style={{ fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 20, fontWeight: 800, color: TEXT, minWidth: 14, textAlign: 'center' }}>2</span>
        <span style={{ width: 24, height: 24, margin: 2, borderRadius: '50%', background: ACC, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}><Ic n="add" style={{ fontSize: 17, color: '#fff' }} /></span>
      </div>
    </div>
    <div style={{ display: 'flex', gap: 6, marginBottom: 16 }}>
      {[['Days', false], ['Weeks', true], ['Months', false]].map(([t, a]) =>
    <div key={t} style={{ flex: 1, height: 36, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 10, background: a ? ACC : BG, color: a ? '#fff' : MED, fontSize: 15, fontWeight: a ? 800 : 700 }}>{t}</div>
    )}
    </div>
    <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 8 }}>ON THESE DAYS</div>
    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
      {[['M', true], ['T', false], ['W', true], ['T', false], ['F', false], ['S', false], ['S', false]].map(([d, on], i) =>
    <div key={i} style={{ width: 40, height: 40, borderRadius: '50%', background: on ? ACC : BG, color: on ? '#fff' : MED, fontSize: 15, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{d}</div>
    )}
    </div>
  </CenterDialog>;


/* ─── 04 FOCUS - melting-ice timer ────────────────────────────────────── */

// Ada-as-ice timer: slim progress ring (depletes) + the mascot cube melting with progress.
const IceTimer = ({ progress = 0, size = 184, expr = 'happy', drip = false, frost = false }) => {
  if (FOCUS_STYLE === 'Glass fill') return <GlassTimer progress={progress} size={size} expr={expr} frost={frost} />;
  const stroke = 7;
  const r = (size - stroke) / 2 - 1;
  const c = 2 * Math.PI * r;
  return (
    <div style={{ position: 'relative', width: size, height: size, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg width={size} height={size} style={{ position: 'absolute', transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={HILITE} strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={frost ? '#9fd6ef' : ACC} strokeWidth={stroke} strokeLinecap="round" strokeDasharray={c} strokeDashoffset={c * Math.min(progress, 1)} style={{ transition: 'stroke-dashoffset 0.9s linear' }} />
      </svg>
      <CubeSVG size={size * 0.6} tone={CUBE_TONES[4]} melt={Math.min(progress, 1)} expr={expr} bubbles={3} />
      {drip && progress > 0.08 && [0, 1].map((i) =>
      <div key={i} className="aq-drip" style={{ position: 'absolute', bottom: size * 0.27 - i * 4, left: `${49 + i * 7}%`, width: 5, height: 8, borderRadius: '50% 50% 60% 60%', background: '#bfe6f5', animation: `aqDrip ${1.6 + i * 0.4}s ${i * 0.6}s infinite ease-in` }} />
      )}
      {frost && <div style={{ position: 'absolute', width: size, height: size, borderRadius: '50%', boxShadow: 'inset 0 0 20px rgba(159,214,239,0.65)', animation: 'aqShimmer 2.2s infinite' }} />}
    </div>);

};

// Glass-fill timer (Tweak): ice shrinks as water rises in the glass below. Dual gauge.
const GlassTimer = ({ progress = 0, size = 184, expr = 'happy', frost = false }) => {
  const p = Math.min(progress, 1);
  const gW = size * 0.62,gH = size * 0.92;
  const water = 8 + p * 64; // % of glass filled with water
  const cubeSize = size * 0.46 * (1 - 0.45 * p); // ice shrinks as it melts
  return (
    <div style={{ position: 'relative', width: size, height: size, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
      <div style={{ position: 'relative', width: gW, height: gH, borderRadius: '10px 10px 26px 26px', border: `3px solid ${frost ? '#9fd6ef' : '#cfd9e6'}`, background: 'rgba(159,206,239,0.08)', overflow: 'hidden', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
        {/* rising water */}
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: `${water}%`, background: `linear-gradient(180deg, ${ACC}9c 0%, ${ACC}cc 100%)`, borderRadius: '40% 38% 0 0 / 12px 14px 0 0', transition: 'height 0.9s linear' }}>
          <div style={{ position: 'absolute', top: -3, left: 0, right: 0, height: 6, background: 'rgba(255,255,255,0.5)', borderRadius: '50%' }} />
        </div>
        {/* floating, shrinking ice */}
        <div style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)', bottom: `calc(${water}% - ${cubeSize * 0.42}px)`, transition: 'bottom 0.9s linear', zIndex: 2 }}>
          <CubeSVG size={cubeSize} tone={CUBE_TONES[4]} melt={p} expr={expr} bubbles={2} />
        </div>
        {/* glass gloss */}
        <div style={{ position: 'absolute', top: 6, left: 8, width: 6, height: '70%', borderRadius: 6, background: 'rgba(255,255,255,0.4)' }} />
      </div>
    </div>);

};

const FocusPill = ({ icon, glyph, label, open, tint }) =>
<BarPill fill="well" icon={icon} glyph={glyph} label={label} color={open ? ACC : TEXT} iconColor={tint || (glyph ? ACC : open ? ACC : TEXT)} style={{ border: `1px solid ${open ? ACC + '55' : 'transparent'}`, ...(open ? { background: ACCL } : null) }} />;

// Shared focus-setup body. The live screen AND the dimmed layer behind both
// config popovers render from this ONE shell, so they can never drift apart.
// The time IS the control: tap 25:00 and the duration popover drops from it.
// Digits stay centred under the cube; the chevron is balanced by a spacer.
const FocusSetupShell = ({ openPill, prismLabel = 'Prism', ice, timeOpen }) =>
<>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '4px 16px 86px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', flexShrink: 0 }}>
        <FocusPill icon="prism" tint={ACC} label={prismLabel} open={openPill === 'prism'} />
        <FocusPill icon="ac_unit" tint={ACC} label="App freeze" open={openPill === 'freeze'} />
      </div>
      {/* centred between the header row and the nav, as deployed */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', width: '100%' }}>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 10 }}>Focus</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, background: WHITE, border: `1px solid ${BORDER}`, borderRadius: 100, padding: '6px 10px 6px 12px', marginBottom: ice ? 8 : 14, boxShadow: SHADOW, cursor: 'pointer' }}>
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: ACC, flexShrink: 0 }} />
        <span style={{ fontSize: 15, fontWeight: 700, color: TEXT }}>LL(1) parsing notes</span>
        <span style={{ fontSize: 13, color: DIM }}>CC 401</span>
        <Ic n="chevron_down" style={{ fontSize: 20, color: DIM }} />
      </div>
      {/* Ice chip - mirrors the task chip exactly, one row lower (On Ice §6).
          `empty` is a bare outline: no badge, no nag, forever. */}
      {ice === 'empty' &&
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, border: `1.5px dashed ${DIM}`, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 13px', marginBottom: 14, cursor: 'pointer' }}>
          <Ic n="freeze" style={{ fontSize: 18, color: MED }} />
          <span style={{ fontSize: 15, fontWeight: 700, color: MED }}>Nothing on ice</span>
        </div>}
      {ice === 'set' &&
    <div style={{ display: 'flex', alignItems: 'center', gap: 7, background: WHITE, border: `1px solid ${BORDER}`, borderRadius: 100, padding: '6px 10px 6px 12px', marginBottom: 14, boxShadow: SHADOW, cursor: 'pointer' }}>
          <Ic n="freeze" style={{ fontSize: 18, color: ACC, flexShrink: 0 }} />
          <span style={{ fontSize: 15, fontWeight: 700, color: TEXT }}>The usual</span>
          <span style={{ fontSize: 13, color: DIM }}>9 on ice</span>
          <Ic n="chevron_down" style={{ fontSize: 20, color: DIM }} />
        </div>}
      <IceTimer progress={0} size={150} />
      <div style={{ position: 'relative', zIndex: timeOpen ? 41 : 'auto', marginTop: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '0 12px', borderRadius: 100, background: timeOpen ? WHITE : 'transparent', boxShadow: timeOpen ? '0 6px 24px rgba(0,0,0,0.18)' : 'none', cursor: 'pointer' }}>
          <span style={{ width: 30, flexShrink: 0 }}></span>
          <span style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 46, fontWeight: 800, letterSpacing: 0.5, lineHeight: 1.2, color: timeOpen ? ACC : TEXT }}>25:00</span>
          <Ic n={timeOpen ? 'expand_less' : 'expand_more'} style={{ fontSize: 26, color: timeOpen ? ACC : DIM, marginTop: 4 }} />
        </div>
        {timeOpen && <DurationPopover />}
      </div>
      <div style={{ marginTop: 21, width: '100%', display: 'flex', justifyContent: 'center' }}>
        <div style={{ background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: '0 40px', fontSize: 17, fontWeight: 800, color: '#fff', display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
          <Ic n="play" style={{ fontSize: 21 }} />Start focus
        </div>
      </div>
      </div>
    </div>
    <BNav active={2} />
    {timeOpen && <>
      <div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0, background: WHITE, opacity: 0.75, zIndex: 40 }}></div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.42)', zIndex: 40 }}></div>
    </>}
  </>;

// Dimmed live-screen + single scrim shared by BOTH config popovers, so the
// backdrop always matches reality (melting-cube timer, real pills + task chip).
const FocusConfigBackdrop = ({ openPill }) =>
<>
    <div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0, opacity: 0.25, pointerEvents: 'none' }}>
      <FocusSetupShell openPill={openPill} />
    </div>
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.42)' }} />
  </>;

// Set timer - frozen Ada, duration chosen, not yet started
const FOCUS = () =>
<Phone bg={WHITE}>
    <FocusSetupShell />
  </Phone>;

// Link-a-task picker - opened by tapping the task chip on the Focus setup screen.
// Optional by design: a clear "Focus without a task" escape sits at the top.
const FOCUS_LINK_TASK = () => {
  const tasks = [
  ['LL(1) parsing notes', 'CC 401', '35m', ACC, true],
  ['Assignment 3 draft', 'NLP 302', '30m', '#5cbbff', false],
  ['Read chapter 7', 'DBMS 304', '20m', SUCC, false],
  ['Revise normalization', 'DBMS 304', '15m', SUCC, false]];

  return (
    <Phone bg={WHITE}>
      <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
        {/* dimmed focus setup behind */}
        <div style={{ position: 'absolute', inset: 0, opacity: 0.25, pointerEvents: 'none' }}><FocusSetupShell /></div>
        {/* scrim */}
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.40)' }} />
        {/* bottom sheet */}
        <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -8px 40px rgba(0,0,0,0.20)', overflow: 'hidden', padding: '10px 0px 34px' }}>
          <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 12px' }} />
          <div style={{ padding: '0 18px 12px' }}>
            <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>Link a task</div>
            <div style={{ fontSize: 15, color: MED, marginTop: 2 }}>Optional: track this session against a task</div>
          </div>
          {/* search */}
          <div style={{ margin: '0 18px 10px', display: 'flex', alignItems: 'center', gap: 8, background: BG, borderRadius: 12, padding: '9px 12px' }}>
            <Ic n="search" style={{ fontSize: 21, color: DIM }} />
            <span style={{ fontSize: 17, color: DIM }}>Search tasks</span>
          </div>
          {/* focus without a task */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 18px', borderTop: `1px solid ${BORDER}`, borderBottom: `1px solid ${BORDER}` }}>
            <div style={{ width: 30, height: 30, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Ic n="focus" style={{ fontSize: 21, color: MED }} />
            </div>
            <span style={{ flex: 1, fontSize: 17, fontWeight: 700, color: TEXT }}>Focus without a task</span>
            <Ic n="aqx_ring" style={{ fontSize: 19, color: '#cfcbc4' }} />
          </div>
          {/* today label */}
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, padding: '11px 18px 5px' }}>TODAY</div>
          {tasks.map(([name, subj, dur, color, sel]) =>
          <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '9px 18px', background: sel ? ACCL : 'transparent' }}>
              <span style={{ width: 9, height: 9, borderRadius: '50%', background: color, flexShrink: 0 }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>{name}</div>
                <div style={{ fontSize: 13, color: DIM, marginTop: 1 }}>{subj} · {dur}</div>
              </div>
              <Ic n={sel ? 'check_circle' : 'radio_button_unchecked'} style={{ fontSize: 19, color: sel ? ACC : '#cfcbc4' }} />
            </div>
          )}
          <div style={{ margin: '14px 18px 0', background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff' }}>Link task</div>
        </div>
      </div>
    </Phone>);

};
const FOCUS_RUNNING = () => {
  const TOTAL = 1500; // 25:00
  const SPEED = 45; // session-seconds advanced per real second (preview pace)
  const [elapsed, setElapsed] = React.useState(180);
  const [paused, setPaused] = React.useState(false);
  React.useEffect(() => {
    if (paused) return undefined;
    const id = setInterval(() => setElapsed((e) => e + SPEED >= TOTAL ? 0 : e + SPEED), 1000);
    return () => clearInterval(id);
  }, [paused]);
  const rem = TOTAL - elapsed;
  const mm = String(Math.floor(rem / 60)).padStart(2, '0');
  const ss = String(Math.floor(rem % 60)).padStart(2, '0');
  const progress = elapsed / TOTAL;
  return (
    <Phone bg={WHITE}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '4px 16px 86px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', flexShrink: 0 }}>
          <FocusPill icon="prism" tint={ACC} label="Deep Work" />
          <FocusPill icon="ac_unit" tint={ACC} label="App freeze" />
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', width: '100%' }}>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 7 }}>Focus</div>
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.4, marginBottom: 12 }}>CC 401 · LL(1) parsing notes</div>
        <IceTimer progress={progress} size={150} expr="happy" drip={!paused} />
        <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 46, fontWeight: 800, letterSpacing: 0.5, lineHeight: 1.2, marginTop: 20 }}>{mm}:{ss}</div>
        <div style={{ marginTop: 20, display: 'flex', gap: 10 }}>
          <div onClick={() => setPaused((p) => !p)} style={{ background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: '0 30px', fontSize: 17, fontWeight: 800, color: '#fff', display: 'flex', alignItems: 'center', gap: 7, cursor: 'pointer' }}>
            <Ic n={paused ? 'play_arrow' : 'ac_unit'} style={{ fontSize: 21 }} />{paused ? 'Resume' : 'Freeze'}
          </div>
          <div style={{ background: WHITE, border: `1.5px solid ${BORDER}`, borderRadius: 100, padding: '13px 28px', fontSize: 17, fontWeight: 800, color: '#e85476', display: 'flex', alignItems: 'center', gap: 7, cursor: 'pointer' }}>
            <Ic n="end" style={{ fontSize: 21 }} />End
          </div>
        </div>
        </div>
      </div>
      <BNav active={2} />
    </Phone>);

};

// Paused - melt frozen mid-session, frost shimmer
const FOCUS_PAUSED = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '4px 16px 86px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', flexShrink: 0 }}>
        <FocusPill icon="prism" tint={ACC} label="Deep Work" />
        <FocusPill icon="ac_unit" tint={ACC} label="App freeze" />
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', width: '100%' }}>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 7 }}>Frozen</div>
      <div style={{ fontSize: 13, color: MED, lineHeight: 1.4, marginBottom: 12 }}>CC 401 · LL(1) parsing notes</div>
      <IceTimer progress={0.4} size={150} expr="happy" frost />
      <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 46, fontWeight: 800, letterSpacing: 0.5, lineHeight: 1.2, marginTop: 20, color: MED }}>15:00</div>
      <div style={{ marginTop: 20, display: 'flex', gap: 10 }}>
        <div style={{ background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: '0 30px', fontSize: 17, fontWeight: 800, color: '#fff', display: 'flex', alignItems: 'center', gap: 7, cursor: 'pointer' }}>
          <Ic n="play" style={{ fontSize: 21 }} />Resume
        </div>
        <div style={{ background: WHITE, border: `1.5px solid ${BORDER}`, borderRadius: 100, padding: '13px 28px', fontSize: 17, fontWeight: 800, color: '#e85476', display: 'flex', alignItems: 'center', gap: 7, cursor: 'pointer' }}>
          <Ic n="end" style={{ fontSize: 21 }} />End
        </div>
      </div>
      </div>
    </div>
    <BNav active={2} />
  </Phone>;


// Small circular timer glyph with the minute count inside (matches reference)
const DurationGlyph = ({ n }) =>
<svg width="22" height="22" viewBox="0 0 24 24" style={{ flexShrink: 0 }}>
    <path d="M12 4 A8 8 0 1 1 6.3 6.3" fill="none" stroke={MED} strokeWidth="1.6" strokeLinecap="round" />
    <path d="M12 4 l-2.4 -1.8 M12 4 l-2.4 1.8" fill="none" stroke={MED} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    <text x="12" y="13.5" textAnchor="middle" dominantBaseline="middle" fontSize="7.5" fontWeight="800" fontFamily={SANS} fill={MED}>{n}</text>
  </svg>;


// Prism mode glyph - the pack's Tier 3 state marks in the mode colour (static
// key frame; Rive animates them in-app). Review borrows Creative, the loosest fit.
const PRISM_MARK = { 'Deep Work': 'state_deep_focus', Flow: 'state_focus', Review: 'state_creative', 'Wind-down': 'state_relax', 'No sound': 'mute' };
const PrismGlyph = ({ mode, color }) => <Ic n={PRISM_MARK[mode] || 'prism'} style={{ fontSize: 22, color }} />;


// Set time - centered dialog (value-adjust pattern). Shares the live backdrop.
// Set time - drops from the 25:00 it changes (the screen stays live behind).
const DURATION_MENU = () => <Phone bg={WHITE}><FocusSetupShell timeOpen /></Phone>;

const DurationPopover = () => {
  const presets = [15, 25, 45, 60];
  return (
      <div style={{ position: 'absolute', top: 'calc(100% + 12px)', left: '50%', transform: 'translateX(-50%)', width: 320, boxSizing: 'border-box', background: WHITE, borderRadius: 24, boxShadow: '0 20px 64px rgba(0,0,0,0.34)', padding: '17px 18px 18px' }}>
        <div style={{ position: 'absolute', top: -7, left: '50%', marginLeft: -8, width: 16, height: 16, background: WHITE, borderRadius: 3, transform: 'rotate(45deg)' }}></div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 3 }}>
          <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>Set time</div>
          <BarDismiss tight />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18, marginTop: 14, marginBottom: 14 }}>
          <StepBtn icon="remove" />
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
            <span style={{ fontFamily: '"Plus Jakarta Sans", sans-serif', fontSize: 50, fontWeight: 800, color: TEXT, lineHeight: 1 }}>25</span>
            <span style={{ fontSize: 17, fontWeight: 700, color: MED }}>min</span>
          </div>
          <StepBtn icon="add" />
        </div>
        <div style={{ position: 'relative', height: 6, background: BG, borderRadius: 3, marginBottom: 14 }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '38%', background: ACC, borderRadius: 3 }} />
          <div style={{ position: 'absolute', left: '38%', top: '50%', transform: 'translate(-50%,-50%)', width: 18, height: 18, borderRadius: '50%', background: WHITE, boxShadow: '0 2px 8px rgba(0,0,0,0.25)', border: `2px solid ${ACC}` }} />
        </div>
        <div style={{ display: 'flex', gap: 6, marginBottom: 16 }}>
          {presets.map((p) => {
            const on = p === 25;
            return (
              <div key={p} style={{ flex: 1, height: 36, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 100, fontSize: 15, fontWeight: 700, background: on ? ACC : BG, color: on ? '#fff' : MED, cursor: 'pointer' }}>{p}</div>);

          })}
        </div>
        <div style={{ background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff', cursor: 'pointer' }}>Set · 25 min</div>
      </div>);

};


const PRISM_MENU = () =>
<Phone bg={WHITE}>
    <FocusConfigBackdrop openPill="prism" />
    <div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0 }}>
      {/* prism dropdown - anchored top-left under the Prism pill */}
      <div style={{ position: 'absolute', top: 58, left: 10, background: WHITE, borderRadius: 20, overflow: 'hidden', boxShadow: '0 8px 36px rgba(0,0,0,0.15)', minWidth: 184 }}>
        {[['Deep Work', ACC], ['Flow', SUCC], ['Review', WARN], ['Wind-down', MED], ['No sound', DIM]].map(([mode, color], i, a) => {
        const active = i === 0;
        return (
          <div key={mode} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 11, padding: '11px 18px', backgroundImage: i < a.length - 1 ? `linear-gradient(${BORDER}, ${BORDER})` : 'none', backgroundSize: `calc(100% - 51px) 1px`, backgroundPosition: '100% 100%', backgroundRepeat: 'no-repeat', background: active ? ACCL : WHITE }}>
              <PrismGlyph mode={mode} color={color} />
              <span style={{ fontSize: 17, fontWeight: active ? 700 : 500, color: active ? ACC : TEXT }}>{mode}</span>
              {active && <Ic n="check" style={{ marginLeft: 'auto', fontSize: 20, color: ACC }} />}
            </div>);

      })}
        <div style={{ borderTop: `1px solid ${BORDER}`, minHeight: 52, boxSizing: 'border-box', padding: '0 18px', display: 'flex', alignItems: 'center', gap: 8, background: WHITE }}>
          <Ic n="prism" style={{ fontSize: 19, color: MED }} />
          <span style={{ flex: 1, fontSize: 17, fontWeight: 600, color: TEXT }}>Autoplay Prism</span>
<Toggle on />
        </div>
      </div>
    </div>
  </Phone>;


/* Session end - full gradient like Tiimo */
const SessionEndBody = ({ bare = false }) => {
  const INK = '#1a1320'; // fixed dark ink - gradient is always light
  const INK_SUB = 'rgba(36,24,52,0.58)';
  const moodSet = [0, 1, 2, 3, 4]; // Rough, Tired, OK, Good, Great
  return (
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '14px 20px', textAlign: 'center' }}>
      <div style={{ background: 'rgba(255,255,255,0.6)', borderRadius: 100, padding: '5px 13px', fontSize: 13, fontWeight: 700, color: INK, display: 'flex', gap: 6, alignItems: 'center', marginBottom: 22, backdropFilter: 'blur(6px)' }}>
        <Ic n="prism" style={{ fontSize: 16, color: ACC }} /> Deep Work · Prism
      </div>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 5, color: INK }}>Session done</div>
      <div style={{ fontSize: 15, color: INK_SUB, marginBottom: 18 }}>LL(1) parsing notes · CC 401</div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 18 }}>
        <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 48, fontWeight: 800, letterSpacing: 0.5, color: INK, lineHeight: 1 }}>25:00</div>
        <div style={{ fontSize: 17, fontWeight: 600, color: INK_SUB, marginTop: 6 }}>Focused</div>
      </div>
      <div style={{ background: 'rgba(255,255,255,0.78)', borderRadius: 18, padding: '14px 14px', width: '100%', marginBottom: 16, backdropFilter: 'blur(8px)' }}>
        <div style={{ fontSize: 17, fontWeight: 700, marginBottom: 12, color: INK }}>How was that session?</div>
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 6 }}>
          {moodSet.map((idx) => {
              const active = idx === 3;
              return (
                <div key={idx} style={{ padding: 2.5, borderRadius: '50%', border: active ? `2px solid ${MOODS[idx].color}` : '2px solid transparent', background: active ? MOODS[idx].color + '22' : 'transparent' }}>
                  <MoodBlob idx={idx} size={active ? 32 : 29} />
                </div>);

            })}
        </div>
      </div>
      {!bare && <><div style={{ width: '100%', height: 50, boxSizing: 'border-box', padding: '0 16px', background: INK, borderRadius: 100, color: '#fff', fontSize: 17, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginBottom: 10, cursor: 'pointer' }}>Back to today →</div>
      <div style={{ fontSize: 15, color: INK_SUB, fontWeight: 600, cursor: 'pointer' }}>Start another session</div></>}
    </div>);

};
const SESSION_GRAD = `linear-gradient(160deg, #f5f2ff 0%, #c9bcf8 46%, ${ACC} 100%)`;
const SESSION_END = () => <Phone bg={SESSION_GRAD}><SessionEndBody /></Phone>;


/* ─── 05 ADA ──────────────────────────────────────────────────────────── */
const AdaMenuBtn = () =>
<div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: WHITE, boxShadow: SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flexShrink: 0 }} title="Chat history">
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke={TEXT} strokeWidth="2" strokeLinecap="round">
      <line x1="2.5" y1="4.5" x2="15.5" y2="4.5" />
      <line x1="2.5" y1="9" x2="11.5" y2="9" />
      <line x1="2.5" y1="13.5" x2="8" y2="13.5" />
    </svg>
  </div>;
const UploadPill = () =>
<div style={{ height: HEAD_BTN, borderRadius: HEAD_BTN / 2, padding: '0 18px 0 15px', background: adaTheme().speakBg, display: 'flex', alignItems: 'center', gap: 6, fontSize: 17, fontWeight: 700, color: adaTheme().speakInk, flexShrink: 0 }}>
    <Ic n="upload" style={{ fontSize: 19 }} />Upload
  </div>;
// Scroll-edge fades: a page-colour wash masked to an eased ramp, so the thread
// dissolves under the header (top) and before the tray / input / nav (bottom).
// Masking a solid PAGE fill keeps it exact in light, dark and every accent.
const ADA_EDGE_H = 28;
const ADA_RAMP = [[0, 1], [0.22, 0.86], [0.48, 0.58], [0.74, 0.24], [1, 0]];
const AdaFade = ({ side, h, solid = 0 }) => {
  const r = h - solid, stops = ADA_RAMP.map(([p, a]) => `rgba(0,0,0,${a}) ${Math.round(solid + p * r)}px`).join(', ');
  const m = `linear-gradient(${side === 'top' ? 180 : 0}deg, ${stops})`;
  return <div aria-hidden="true" style={{ position: 'absolute', left: 0, right: 0, height: h, pointerEvents: 'none', background: PAGE, maskImage: m, WebkitMaskImage: m, ...(side === 'top' ? { top: '100%' } : { bottom: 0 }) }} />;
};
// Bottom fade tops out at the text box's midline (input 698–770 → 734) and
// goes solid at the nav's top edge (791). The tray sits clear above it.
const adaBottomFade = () => <AdaFade side="bottom" h={140} solid={83} />;
const AdaHead = () =>
<div style={{ position: 'relative', zIndex: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 16px 12px', background: PAGE }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <AdaMenuBtn />
      <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>Ada</div>
    </div>
    <UploadPill />
    <AdaFade side="top" h={ADA_EDGE_H} />
  </div>;
// Ada's chat surfaces follow Gemini's colourway: a grey prompt pill, the reply
// as plain text on the page, a floating translucent text box. The home state
// adds Gemini's bottom glow, tinted to the brand accent.
const adaTheme = () => IS_DARK ? {
  box: 'rgba(31,31,33,0.92)', edge: '1px solid rgba(255,255,255,0.08)', lift: 'none', ph: '#999999',
  bubble: '#212121', bubbleInk: '#e0e0e0', resp: '#e0e0e0', speakBg: '#2a2170', speakInk: '#e6e2ff', glyph: '#e6e2ff',
  glow: `radial-gradient(140% 58% at 62% 100%, ${ACC}5e 0%, ${ACC}22 42%, transparent 72%), ${PAGE}` } : {
  box: 'rgba(255,255,255,0.86)', edge: 'none', lift: '0 6px 26px rgba(0,0,0,0.08)', ph: '#6f7174',
  bubble: '#f1f0f0', bubbleInk: TEXT, resp: TEXT, speakBg: ACCL, speakInk: TEXT, glyph: ACC,
  glow: `radial-gradient(140% 58% at 62% 100%, ${ACC}4d 0%, ${ACC}1c 42%, transparent 72%), ${PAGE}` };
// Gemini's text box: 324 × 72, fully round; the action inset 16 all round so
// its 20 radius sits concentric inside the box's 36. Docked 21 above the nav.
const AdaInput = ({ placeholder = "What's on your mind?", send, busy }) => {
  const t = adaTheme();
  return (
    <div style={{ position: 'absolute', bottom: 104, left: 39, right: 39, height: 72, boxSizing: 'border-box', borderRadius: 36, background: t.box, border: t.edge, boxShadow: t.lift, backdropFilter: 'blur(18px)', WebkitBackdropFilter: 'blur(18px)', display: 'flex', alignItems: 'center', gap: send ? 4 : 10, padding: '0 16px 0 24px' }}>
      <div style={{ flex: 1, minWidth: 0, fontSize: 17, color: t.ph, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{placeholder}</div>
      {send &&
      <div style={{ width: 40, height: 40, borderRadius: 20, color: t.resp, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n="mic" style={{ fontSize: 20 }} /></div>}
      <div style={{ width: 40, height: 40, borderRadius: 20, background: t.speakBg, color: t.speakInk, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n={busy ? 'end' : send ? 'arrow_upward' : 'mic_none'} style={{ fontSize: 20 }} /></div>
    </div>);
};

const ADA_SUGGEST = [['planner', 'Plan my week'], ['self_improvement', "I'm overwhelmed"], ['account_tree', 'Break this down'], ['alarm', 'Deadline help']];
const ADA_SCREEN = () => {
  const th = adaTheme();
  return (
    <Phone bg={th.glow}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column' }}>
        <AdaHead />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '0 20px 152px' }}>
          {/* cube + line centred in the space above the suggestions */}
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
            <AdaBlob size={78} mood="happy" />
            <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 20, fontWeight: 700, marginTop: 15, lineHeight: 1.4 }}>Drop your thoughts.<br />I'll turn them into a plan.</div>
          </div>
          {/* suggestions as Gemini lays them out: line icon, text to the right, 44 rows */}
          <div style={{ display: 'flex', flexDirection: 'column', padding: '0 6px 0 22px', marginBottom: 22 }}>
            {ADA_SUGGEST.map(([ic, label]) =>
            <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 14, height: 44, cursor: 'pointer' }}>
                <Ic n={ic} style={{ fontSize: 22, color: th.resp }} />
                <span style={{ fontSize: 17, fontWeight: 500, color: th.resp }}>{label}</span>
              </div>
            )}
          </div>
        </div>
        <AdaInput />
      </div>
      <BNav active={4} />
    </Phone>);
};


const ADA_CHAT = () => {
  const t = adaTheme();
  return (
    <Phone bg={PAGE}>
      <div style={{ height: 792 }}>
        <AdaHead />
        <div style={{ padding: `${ADA_EDGE_H + 2}px 16px 18px`, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', gap: 9, alignItems: 'flex-start' }}>
            <div style={{ flexShrink: 0, marginTop: 1 }}><AdaBlob size={24} /></div>
            <div style={{ flex: 1, minWidth: 0, color: t.resp, fontSize: 17, lineHeight: 1.55 }}>Hey Ridhwan, your CC viva is 3 days away. Want me to build a prep plan?</div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <div style={{ background: t.bubble, color: t.bubbleInk, borderRadius: 22, padding: '10px 16px', maxWidth: 262, fontSize: 17, lineHeight: 1.5 }}>Yes, and I need to finish NLP assignment 3 too</div>
          </div>
          <div style={{ display: 'flex', gap: 9, alignItems: 'flex-start' }}>
            <div style={{ flexShrink: 0, marginTop: 1 }}><AdaBlob size={24} /></div>
            <div style={{ flex: 1, minWidth: 0, color: t.resp }}>
              <div style={{ fontSize: 17, lineHeight: 1.55, marginBottom: 8 }}>Done. Scheduled across 2 days:</div>
              <div style={{ background: ACCL, borderRadius: 14, padding: '10px 12px', maxWidth: 260 }}>
                {[['Today', 'LL(1) notes · 35m', 'NLP draft · 45m'], ['Tomorrow', 'CC viva mock · 1h', 'NLP final edits · 30m']].map(([day, l1, l2], i) =>
                <div key={day} style={{ marginTop: i ? 8 : 0 }}>
                    <div style={{ fontSize: 12, fontWeight: 800, color: ACC, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 2 }}>{day}</div>
                    <div style={{ fontSize: 17, color: TEXT, marginBottom: 1 }}>· {l1}</div>
                    <div style={{ fontSize: 17, color: TEXT }}>· {l2}</div>
                  </div>
                )}
              </div>
              <div style={{ fontSize: 15, color: DIM, marginTop: 6 }}>Added to your plan <Ic n="check" style={{ fontSize: 16 }} /></div>
            </div>
          </div>
        </div>
        {adaBottomFade(false)}
        <AdaInput placeholder="Ask Ada anything..." send />
      </div>
      <BNav active={4} />
    </Phone>);
};


/* ─── 05 · ADA PROPOSALS ──────────────────────────────────────────────────
   Ada never writes to the plan on her own: each change lands as a card to
   approve or decline. With 2+ waiting, a glass tray docks above the input.
   The thread scrolls under the header fade, the tray and the input. */
const adaGreen = () => IS_DARK ? SUCC : '#1D7A52'; // assignment ink: 5.3:1 on white
const AdaSay = ({ children, mood }) =>
<div style={{ display: 'flex', gap: 9, alignItems: 'flex-start' }}>
    <div style={{ flexShrink: 0, marginTop: 1 }}><AdaBlob size={24} mood={mood} /></div>
    <div style={{ flex: 1, minWidth: 0, color: adaTheme().resp, fontSize: 17, lineHeight: 1.55, textWrap: 'pretty' }}>{children}</div>
  </div>;
const YouSay = ({ children }) => {
  const t = adaTheme();
  return <div style={{ display: 'flex', justifyContent: 'flex-end' }}><div style={{ background: t.bubble, color: t.bubbleInk, borderRadius: 22, padding: '10px 16px', maxWidth: 262, fontSize: 17, lineHeight: 1.5 }}>{children}</div></div>;
};
// Thinking loader: the five Tier 3 state marks in turn, each with its own motion.
// Scattered thoughts gather (Distracted, Creative), narrow (Focus), lock in (Deep Focus), settle (Relax).
const THINK_SEQ = ['state_distracted', 'state_creative', 'state_focus', 'state_deep_focus', 'state_relax'];
const THINK_ANIM = {
  state_creative: 'aqSpin 1.6s linear infinite',
  'state_focus.outer': 'aqSpin 1.4s linear infinite',
  'state_focus.inner': 'aqSpinR 1.1s linear infinite',
  'state_deep_focus.core': 'aqPulse .9s ease-in-out infinite',
  'state_relax.wave1': 'aqBob 1s ease-in-out infinite',
  'state_relax.wave2': 'aqBob 1s -.5s ease-in-out infinite'
};
const THINK_BUBBLES = [[7, 16, 2], [13, 13.5, 1.25], [11, 8.5, 0.6], [17, 9, 1.25], [19.5, 4.25, 0.6]]; // = state_distracted, split so each drifts
const ThinkMark = ({ size = 22, color = ACC, sw = 1.75 }) =>
<svg className="aq-think" viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{ color, overflow: 'visible', flexShrink: 0, display: 'block' }}>
    {THINK_SEQ.map((name, i) =>
  <g key={name} className={'aq-slot' + (name === 'state_focus' ? ' aq-rest' : '')} style={{ animation: `aqThinkSlot 4.5s ${i * 0.9}s ease-in-out infinite backwards` }}>
        <g style={{ animation: THINK_ANIM[name] }}>
          {name === 'state_distracted' ?
      THINK_BUBBLES.map(([cx, cy, r], k) => <circle key={k} cx={cx} cy={cy} r={r} style={{ animation: `aqDrift .9s ${-k * 0.18}s ease-in-out infinite` }} />) :
      window.AQ.ICONS[name].layers.map((l) => <path key={l.id} d={l.d} fill={l.paint ? 'currentColor' : undefined} style={{ animation: THINK_ANIM[name + '.' + l.id] }} />)}
        </g>
      </g>
  )}
  </svg>;
const AdaThinking = () =>
<div style={{ display: 'flex', gap: 9, alignItems: 'center' }} role="status">
    <div style={{ flexShrink: 0 }}><AdaBlob size={24} mood="focused" /></div>
    <span style={{ fontSize: 17, color: MED }}>Ada is thinking</span>
    <ThinkMark />
  </div>;
const MetaChip = ({ icon, dot, label }) =>
<span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 30, padding: '0 11px 0 9px', borderRadius: 100, background: BG, fontSize: 15, fontWeight: 600, color: TEXT }}>
    {icon ? <Ic n={icon} style={{ fontSize: 16, color: MED }} /> : <span style={{ width: 8, height: 8, borderRadius: '50%', background: dot, flexShrink: 0 }} />}
    {label}
  </span>;
const ProposalCard = ({ title, tag, tagColor, added }) => {
  const green = adaGreen();
  const btn = { flex: 1, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, cursor: 'pointer' };
  return (
    <div style={{ background: WHITE, borderRadius: 20, padding: 14, border: `1.5px solid ${added ? BORDER : ACC + '40'}`, boxShadow: added ? 'none' : SHADOW, display: 'flex', flexDirection: 'column', gap: 9 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 24 }}>
        {added ?
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 15, fontWeight: 700, color: green }}><Ic n="check_circle" style={{ fontSize: 18, color: green }} />Added to today</span> :
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, height: 24, padding: '0 9px 0 6px', borderRadius: 100, background: ACCL, color: TEXT, fontSize: 12, fontWeight: 800, letterSpacing: '0.06em', textTransform: 'uppercase' }}><Ic n="add" sw={2.2} style={{ fontSize: 14, color: ACC }} />New task</span>}
        {added && <span role="button" style={{ fontSize: 15, fontWeight: 700, color: MED, padding: '10px 4px', margin: '-10px -4px', cursor: 'pointer' }}>Undo</span>}
      </div>
      <div style={{ fontSize: 17, fontWeight: 700, color: TEXT, lineHeight: 1.35, textWrap: 'pretty' }}>{title}</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        <MetaChip icon="date" label="Today" />
        {tag && <MetaChip dot={tagColor} label={tag} />}
      </div>
      {!added &&
      <div style={{ display: 'flex', gap: 8, marginTop: 3 }}>
          <div role="button" style={{ ...btn, background: INK, color: '#fff', fontWeight: 800 }}>Approve</div>
          <div role="button" style={{ ...btn, background: BG, color: TEXT, fontWeight: 700 }}>Decline</div>
        </div>}
    </div>);
};
const ProposalTray = ({ count }) => {
  const t = adaTheme();
  return (
    <div style={{ position: 'absolute', bottom: 184, left: 39, right: 39, height: 56, boxSizing: 'border-box', borderRadius: 28, background: t.box, border: t.edge, boxShadow: t.lift, backdropFilter: 'blur(18px)', WebkitBackdropFilter: 'blur(18px)', display: 'flex', alignItems: 'center', padding: '0 6px 0 16px' }}>
      <span role="button" style={{ flex: 1, minWidth: 0, height: 44, display: 'flex', alignItems: 'center', gap: 2, fontSize: 15, fontWeight: 700, color: TEXT, whiteSpace: 'nowrap', cursor: 'pointer' }}>{count} waiting<Ic n="expand_less" style={{ fontSize: 18, color: MED }} /></span>
      <span role="button" style={{ height: 44, display: 'flex', alignItems: 'center', padding: '0 10px', fontSize: 15, fontWeight: 700, color: MED, whiteSpace: 'nowrap', cursor: 'pointer' }}>Decline all</span>
      <span role="button" style={{ height: 44, display: 'flex', alignItems: 'center', padding: '0 16px', borderRadius: 22, background: INK, color: '#fff', fontSize: 15, fontWeight: 800, whiteSpace: 'nowrap', cursor: 'pointer' }}>Approve all</span>
    </div>);
};
// A thread frame. scroll = px scrolled; end = pinned to the latest message.
// Bottom inset clears the glass (tray + input + nav) so the last line sits above it.
const AdaThread = ({ scroll = 0, end, tray, busy, children }) => {
  const box = React.useRef(null), col = React.useRef(null);
  const [y, setY] = React.useState(scroll);
  React.useLayoutEffect(() => {
    if (!end) return;
    const fit = () => box.current && col.current && setY(Math.max(0, col.current.offsetHeight - box.current.clientHeight));
    fit(); document.fonts && document.fonts.ready.then(fit);
  }, [end]);
  return (
    <Phone bg={PAGE}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column' }}>
        <AdaHead />
        <div ref={box} style={{ flex: 1, minHeight: 0, position: 'relative', overflow: 'hidden' }}>
          <div ref={col} style={{ transform: `translateY(${-y}px)`, padding: `${ADA_EDGE_H + 2}px 16px ${tray ? 256 : 200}px`, display: 'flex', flexDirection: 'column', gap: 16 }}>{children}</div>
        </div>
        {adaBottomFade(tray)}
        {tray && <ProposalTray count={tray} />}
        <AdaInput placeholder="Ask Ada anything..." send busy={busy} />
      </div>
      <BNav active={4} />
    </Phone>);
};
const ADA_ASK_3 = 'hi I want to make these tasks which are proper workout and new shoes buying and learning Arabic';
const ADA_PROPOSE_3 = () =>
<AdaSay>
    Three tasks for today. Approve the ones you want and I'll add them to your plan.
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 10 }}>
      <ProposalCard title="Proper workout" tag="Gym" tagColor={SUCC} />
      <ProposalCard title="Buy new shoes" tag="Personal" tagColor="#5cbbff" />
      <ProposalCard title="Learn Arabic" />
    </div>
  </AdaSay>;
const ADA_THINKING = () => <AdaThread busy><YouSay>{ADA_ASK_3}</YouSay><AdaThinking /></AdaThread>;
const ADA_PROPOSALS = () => <AdaThread scroll={92} tray={3}><YouSay>{ADA_ASK_3}</YouSay><ADA_PROPOSE_3 /></AdaThread>;
const ADA_PROPOSALS_END = () => <AdaThread end tray={3}><YouSay>{ADA_ASK_3}</YouSay><ADA_PROPOSE_3 /></AdaThread>;
const ADA_APPLIED = () =>
<AdaThread end>
    <YouSay>hey Ada I need to call the car wash and get it booked for the next month. Another thing would be I need to buy a laptop cover a good laptop bag you know an iPad cover right yeah I need to get these things properly.</YouSay>
    <AdaSay>
      Two tasks for today. Approve them and I'll add them to your plan.
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 10 }}>
        <ProposalCard added title="Call the car wash and book for next month" />
        <ProposalCard added title="Buy laptop cover, laptop bag and iPad cover" />
      </div>
    </AdaSay>
    <AdaSay>Both are on today's plan. Anything else?</AdaSay>
  </AdaThread>;

// Chat history - slide-over panel from the chat-history button (dimmed Ada screen peeking on the right)
const CHAT_HISTORY = () =>
<Phone bg={WHITE}>
    <div style={{ height: 816, position: 'relative' }}>
      {/* dimmed peek of the Ada screen behind, on the right */}
      <div style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 30, background: '#cdcbc9' }} />
      <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, right: 24, background: WHITE, borderRadius: '0 16px 16px 0', boxShadow: '6px 0 30px rgba(0,0,0,0.12)', padding: '0 16px', overflow: 'hidden' }}>
        {/* header - same chat-history button */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 0 18px' }}>
          <AdaMenuBtn />
          <div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: WHITE, boxShadow: SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }} title="New chat">
            <Ic n="edit" style={{ fontSize: 21, color: TEXT }} />
          </div>
        </div>
        {/* title */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <div style={{ ...{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.5 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Chat history</div>
        </div>
        {/* dated conversations */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {[
        ['MONDAY, 1 JUN', 'CC viva prep plan'],
        ['FRIDAY, 22 MAY', 'NLP assignment 3 breakdown'],
        ['MONDAY, 18 MAY', 'Exam-week schedule'],
        ['FRIDAY, 15 MAY', "I'm overwhelmed: triage"],
        ['MONDAY, 9 FEB', 'Google Calendar import']].
        map(([date, title], i) =>
        <div key={i} style={{ cursor: 'pointer' }}>
              <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 3 }}>{date}</div>
              <div style={{ fontSize: 17, color: TEXT, fontWeight: "700" }}>{title}</div>
            </div>
        )}
        </div>
      </div>
    </div>
    <BNav active={4} />
  </Phone>;


/* ─── SETTINGS PRIMITIVES ─────────────────────────────────────────────── */
// Shared building blocks for the Profile hub + Settings flow.

// iOS-style pill toggle. on = accent track, off = neutral track.
const Toggle = ({ on = false }) =>
<div style={{ width: 51, height: 31, boxSizing: 'border-box', borderRadius: 100, background: on ? ACC : DIM, flexShrink: 0, padding: 2, display: 'flex', justifyContent: on ? 'flex-end' : 'flex-start', transition: 'background .2s' }}>
    <div style={{ width: 27, height: 27, borderRadius: '50%', background: '#fff', boxShadow: '0 2px 5px rgba(0,0,0,0.2)' }} />
  </div>;

// Circular back button used on every settings sub-screen.
const BackBtn = ({ style }) =>
<div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: WHITE, boxShadow: SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, ...style }}>
    <Ic n="back" style={{ fontSize: 24, color: TEXT }} />
  </div>;

// Muted group header above a card (e.g. "Tasks", "Account & subscription").
const GroupLabel = ({ children, style }) =>
<div style={{ fontSize: 17, fontWeight: 700, color: MED, margin: '0 0 8px 3px', ...style }}>{children}</div>;

// Rounded white container that clips its rows.
const SetGroup = ({ children, style }) =>
<div style={{ background: WHITE, borderRadius: 18, boxShadow: SHADOW, overflow: 'hidden', ...style }}>{children}</div>;

// Grey value pill on the right of a row (used for times like "7:00 AM").
const TimePill = ({ children }) =>
<div style={{ height: 36, boxSizing: 'border-box', display: 'flex', alignItems: 'center', background: HILITE, borderRadius: 100, padding: '0 12px', fontSize: 17, fontWeight: 700, color: TEXT, flexShrink: 0 }}>{children}</div>;

// One settings row. Provide a trailing affordance: toggle / value / pill / chevron.
const SetRow = ({ icon, iconColor, avatar, label, sub, value, pill, toggle, chevron, last, danger }) =>
<div style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 11, padding: '12px 15px', backgroundImage: last ? 'none' : `linear-gradient(${BORDER}, ${BORDER})`, backgroundSize: `calc(100% - ${icon ? 46 : avatar ? 58 : 15}px) 1px`, backgroundPosition: '100% 100%', backgroundRepeat: 'no-repeat' }}>
    {avatar}
    {icon && <Ic n={icon} style={{ fontSize: 20, color: danger ? '#e85476' : iconColor || TEXT, flexShrink: 0 }} />}
    <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{ flex: value ? '0 0 auto' : '1 1 auto', minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: 600, color: danger ? '#e85476' : TEXT, whiteSpace: value ? 'nowrap' : 'normal', overflow: 'hidden', textOverflow: 'ellipsis', lineHeight: 1.3 }}>{label}</div>
        {sub && <div style={{ fontSize: 15, color: MED, marginTop: 2, lineHeight: 1.4 }}>{sub}</div>}
      </div>
      {value && <span style={{ flex: 1, minWidth: 0, fontSize: 17, color: MED, fontWeight: 500, textAlign: 'right', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{value}</span>}
    </div>
    {pill && <TimePill>{pill}</TimePill>}
    {toggle !== undefined && <Toggle on={toggle} />}
    {chevron && <Ic n="chevron_right" style={{ fontSize: 19, color: DIM, flexShrink: 0 }} />}
  </div>;


/* ─── 06 PROFILE - TOP ────────────────────────────────────────────────── */
// Top of the profile page: identity, streak orb, stat tiles, mood week.
// (The PROFILE hub below is the bottom of the same scrolling page.)
const PROFILE_TOP = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
        <div style={{ background: WHITE, borderRadius: HEAD_BTN / 2, height: HEAD_BTN, boxSizing: 'border-box', display: 'flex', alignItems: 'center', padding: '0 18px', boxShadow: SHADOW, fontSize: 17, fontWeight: 700 }}>Ridhwan Ahamed</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
          {['ios_share', 'settings'].map((ic) =>
        <div key={ic} style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Ic n={ic} style={{ fontSize: 20, color: TEXT }} />
            </div>
        )}
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ width: 54, height: 54, borderRadius: '50%', background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})`, margin: '0 auto 5px', boxShadow: `0 6px 24px ${ACC}44` }} />
          <div style={{ fontSize: 15, fontWeight: 700 }}>Prism</div>
          <div style={{ fontSize: 15, color: MED }}>3 days</div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
        {[['24', 'DAYS ON THE BOARD', 'since you started', 0], ['128', 'TASKS DONE', 'all time', 0]].map(([v, label, sub, prog]) =>
      <Card key={label} style={{ flex: 1, textAlign: 'center', padding: '10px' }}>
            <div style={{ fontFamily: NUMSERIF, fontSize: 34, fontWeight: 800, marginBottom: 3 }}>{v}</div>
            <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', color: DIM, marginBottom: 7 }}>{label}</div>
            <div style={{ height: 4, background: BG, borderRadius: 2, marginBottom: 4 }}>
              <div style={{ width: `${prog * 100}%`, height: '100%', background: ACC, borderRadius: 2 }} />
            </div>
            <div style={{ fontSize: 12, color: DIM }}>{sub}</div>
          </Card>
      )}
      </div>
      <Card style={{ marginBottom: 8 }}>
        <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 700, marginBottom: 8 }}>Mood &amp; Daily Reflections</div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) =>
        <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div style={{ width: 24, height: 24, borderRadius: '50%', background: i === 0 ? ACCL : BG, border: i === 0 ? `1.5px solid ${ACC}` : '1.5px solid transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {i === 0 && <div style={{ width: 8, height: 8, borderRadius: '50%', background: ACC }} />}
              </div>
              <span style={{ fontSize: 12, color: DIM }}>{d}</span>
            </div>
        )}
        </div>
      </Card>
      <Card>
        {[['Rate the app'], ['Share feedback'], ['FAQ']].map(([label], i, arr) =>
      <div key={label} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: i < arr.length - 1 ? `1px solid ${BORDER}` : 'none' }}>
            <span style={{ fontSize: 17 }}>{label}</span>
            <Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
          </div>
      )}
      </Card>
    </div>
    <BNav active={3} />
  </Phone>;


/* ─── 06 PROFILE - HUB (bottom of the page) ───────────────────────────── */
/* ─── 06 PROFILE - TOP restructure variants (A/B/C) ────────────────── */
// Shared top buttons row - identical to the current page (kept as-is per brief).
const ProfileTopHead = () =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
    <div style={{ background: WHITE, borderRadius: HEAD_BTN / 2, height: HEAD_BTN, boxSizing: 'border-box', display: 'flex', alignItems: 'center', padding: '0 18px', boxShadow: SHADOW, fontSize: 17, fontWeight: 700 }}>Ridhwan Ahamed</div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
      {['ios_share', 'settings'].map((ic) =>
    <div key={ic} style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Ic n={ic} style={{ fontSize: 20, color: TEXT }} />
        </div>
    )}
    </div>
  </div>;

// Mood week as tiny melting ice-cubes: logged days render a cube whose melt +
// tone reflect that day's mood; today is a dashed accent slot inviting a log.
const MOOD_WEEK_DATA = [['M', 3], ['T', 2], ['W', null], ['T', null], ['F', null], ['S', null], ['S', null]];
const MOOD_TODAY_I = 2;
const MoodWeekRow = ({ cube = 24 }) =>
<div style={{ display: 'flex', justifyContent: 'space-between' }}>
    {MOOD_WEEK_DATA.map(([d, idx], i) =>
  <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
        <div style={{ width: cube + 4, height: cube + 4, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {idx != null ?
      <CubeSVG size={cube} tone={CUBE_TONES[idx]} melt={(4 - idx) / 4} expr={MOOD_EXPR[idx]} bubbles={0} /> :
      <div style={{ width: cube - 3, height: cube - 3, borderRadius: 8, border: `1.5px dashed ${i === MOOD_TODAY_I ? ACC : '#d8d4cc'}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {i === MOOD_TODAY_I && <span style={{ fontSize: 17, color: ACC, fontWeight: 700, lineHeight: 1 }}>+</span>}
            </div>}
        </div>
        <span style={{ fontSize: 12, fontWeight: 700, color: i === MOOD_TODAY_I ? ACC : DIM }}>{d}</span>
      </div>
  )}
  </div>;

// Support links rows (kept on both screens per brief).
const ProfileLinks = ({ rows = [['Your week · The Core'], ['Rate the app'], ['Share feedback'], ['FAQ']] }) =>
<Card>
    {rows.map(([label], i, arr) =>
  <div key={label} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: i < arr.length - 1 ? `1px solid ${BORDER}` : 'none' }}>
        <span style={{ fontSize: 17 }}>{label}</span>
        <Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
      </div>
  )}
  </Card>;

// A - Identity-led: Ada greets left-aligned; stats fuse into one editorial band.
const PROFILE_TOP_A_V7 = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <ProfileTopHead />
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '2px 2px 14px' }}>
        <CubeSVG size={46} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks sparkles />
        <div>
          <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: -0.2 }}>Keep it frozen, Ridhwan</div>
          <div style={{ fontSize: 13, color: MED, marginTop: 2 }}>Jun 22 – 28</div>
        </div>
      </div>
      <Card style={{ display: 'flex', padding: 0, marginBottom: 8 }}>
        {[['24', 'DAYS ON THE BOARD'], ['128', 'TASKS DONE']].map(([v, label], i) =>
      <div key={label} style={{ flex: 1, padding: '14px 14px', borderLeft: i ? `1px solid ${BORDER}` : 'none' }}>
            <div style={{ fontFamily: NUMSERIF, fontSize: 34, fontWeight: 800, lineHeight: 1 }}>{v}</div>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.1em', color: DIM, marginTop: 5 }}>{label}</div>
          </div>
      )}
      </Card>
      <Card style={{ marginBottom: 8 }}>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 9 }}>MOOD &amp; DAILY REFLECTIONS</div>
        <MoodWeekRow cube={24} />
      </Card>
      <ProfileLinks />
    </div>
    <BNav active={3} />
  </Phone>;

// B - Week-led: one hero card merges streak + mood week + goal; Prism inline row.
const PROFILE_TOP_B = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <ProfileTopHead />
      <Card style={{ marginBottom: 8, padding: '14px 15px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <CubeSVG size={26} tone={CUBE_TONES[4]} melt={0} expr="happy" />
            <span style={{ fontFamily: SANS, fontSize: 17, fontWeight: 800 }}>Your week</span>
          </div>
          <div style={{ background: INK, color: '#fff', borderRadius: 100, padding: '4px 11px', fontSize: 12, fontWeight: 800, letterSpacing: '0.06em' }}>6 DAYS ON THE BOARD</div>
        </div>
        <MoodWeekRow cube={26} />
        <div style={{ height: 1, background: BORDER, margin: '12px 0 10px' }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span style={{ fontSize: 13, color: MED, fontWeight: 600, whiteSpace: 'nowrap' }}>0/1 tasks today</span>
          <div style={{ flex: 1, height: 4, background: BG, borderRadius: 2, margin: '0 10px' }}>
            <div style={{ width: '43%', height: '100%', background: ACC, borderRadius: 2 }} />
          </div>
          <span style={{ fontSize: 13, fontWeight: 800, color: ACC, whiteSpace: 'nowrap' }}>43% week goal</span>
        </div>
      </Card>
      <Card style={{ marginBottom: 8, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 15px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <div style={{ width: 26, height: 26, borderRadius: '50%', background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})` }} />
          <div>
            <div style={{ fontSize: 15, fontWeight: 700 }}>Prism</div>
            <div style={{ fontSize: 12, color: MED }}>3 days in a row</div>
          </div>
        </div>
        <Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
      </Card>
      <ProfileLinks />
    </div>
    <BNav active={3} />
  </Phone>;

// C - Stats-led: big serif numerals straight on the paper (no tiles), slim mood strip.
const PROFILE_TOP_C = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <ProfileTopHead />
      <div style={{ display: 'flex', padding: '8px 2px 16px' }}>
        {[['24', 'DAYS ON BOARD'], ['128', 'TASKS DONE'], ['19', 'SESSIONS']].map(([v, label], i) =>
      <div key={label} style={{ flex: 1, textAlign: 'center', borderLeft: i ? `1px solid ${BORDER}` : 'none' }}>
            <div style={{ fontFamily: NUMSERIF, fontSize: 34, fontWeight: 800, letterSpacing: -1 }}>{v}</div>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.12em', color: DIM, marginTop: 2 }}>{label}</div>
          </div>
      )}
      </div>
      <Card style={{ marginBottom: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 9 }}>
          <span style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM }}>MOOD THIS WEEK</span>
          <span style={{ fontSize: 13, fontWeight: 700, color: ACC, display: 'inline-flex', alignItems: 'center', gap: 1 }}>Log today<Ic n="chevron_right" style={{ fontSize: 15 }} /></span>
        </div>
        <MoodWeekRow cube={22} />
      </Card>
      <Card style={{ marginBottom: 8, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 15px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <div style={{ width: 26, height: 26, borderRadius: '50%', background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})` }} />
          <div>
            <div style={{ fontSize: 15, fontWeight: 700 }}>Prism streak</div>
            <div style={{ fontSize: 12, color: MED }}>3 days in a row</div>
          </div>
        </div>
        <Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
      </Card>
      <ProfileLinks />
    </div>
    <BNav active={3} />
  </Phone>;


// The whole profile page in the deployed order, as ONE scroll. At 402×874 the
// page no longer needs splitting across two frames: the top frame shows it from
// the top, the hub frame shows it scrolled to the end, and the share sheet dims
// the same page behind it - so nothing can drift between them.
const ProfilePageBody = () =>
<>
    <ProfileTopHead />
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '2px 2px 14px' }}>
      <CubeSVG size={46} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks sparkles />
      <div>
        <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: -0.2 }}>Keep it frozen, Ridhwan</div>
        <div style={{ fontSize: 13, color: MED, marginTop: 2 }}>Jun 22 – 28</div>
      </div>
    </div>
    <Card style={{ display: 'flex', padding: 0, marginBottom: 8 }}>
      {[['24', 'DAYS ON THE BOARD'], ['128', 'TASKS DONE']].map(([v, label], i) =>
      <div key={label} style={{ flex: 1, padding: '14px 14px', borderLeft: i ? `1px solid ${BORDER}` : 'none' }}>
          <div style={{ fontFamily: NUMSERIF, fontSize: 34, fontWeight: 800, lineHeight: 1 }}>{v}</div>
          <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.1em', color: DIM, marginTop: 5 }}>{label}</div>
        </div>
      )}
    </Card>
    <div style={{ position: 'relative', background: WHITE, borderRadius: 18, boxShadow: SHADOW, padding: '14px 15px', marginBottom: 8, cursor: 'pointer', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: 13, right: 14, width: 8, height: 8, borderRadius: '50%', background: ACC, boxShadow: '0 0 0 4px ' + ACC + '22' }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
        <div style={{ flexShrink: 0 }}><IceCore data={CORE_WEEK} w={44} band={15} labels={false} /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <CoreCap>Your week</CoreCap>
          <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.4, margin: '4px 0 4px' }}>The Core</div>
          <div style={{ fontSize: 17, color: MED, lineHeight: 1.5 }}>Seven days, drilled and read.</div>
        </div>
      </div>
    </div>
    <Card style={{ marginBottom: 12 }}>
      <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 9 }}>MOOD &amp; DAILY REFLECTIONS</div>
      <MoodWeekRow cube={24} />
    </Card>
    <Card style={{ marginBottom: 12 }}>
      {[['Rate the app'], ['Share feedback'], ['FAQ'], ['Follow us on Instagram']].map(([label], i, arr) =>
      <div key={label} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 0', borderBottom: i < arr.length - 1 ? `1px solid ${BORDER}` : 'none' }}>
          <span style={{ fontSize: 17 }}>{label}</span>
          <Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
        </div>
      )}
    </Card>
    <IBCard style={{ marginBottom: 12 }} />
    <div style={{ position: 'relative', borderRadius: 20, overflow: 'hidden', background: `linear-gradient(135deg, ${ACC} 0%, #b39df5 52%, #e9c8d8 100%)`, padding: '17px 18px', textAlign: 'center', boxShadow: `0 8px 24px ${ACC}3a` }}>
      <div style={{ position: 'absolute', inset: 0, borderRadius: 20, boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.4)', pointerEvents: 'none' }} />
      <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 54, height: 54, objectFit: 'contain', filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.18))' }} />
      <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 28, fontWeight: 800, color: '#fff', letterSpacing: -0.5, marginTop: 2 }}>Aqademiq</div>
      <div style={{ fontSize: 15, fontWeight: 700, color: 'rgba(255,255,255,0.92)', marginTop: 4 }}>Your focus sanctuary.</div>
    </div>
  </>;

// Top of the page.
const PROFILE_TOP_A = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <ProfilePageBody />
    </div>
    <BNav active={3} />
  </Phone>;

// The same page scrolled to its end - flex-end pins the bottom, so the overflow
// clips off the top exactly as a scrolled list would.
const PROFILE = () =>
<Phone>
    <div style={{ padding: '0 16px 36px', height: 742, overflow: 'hidden', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div style={{ flexShrink: 0 }}><ProfilePageBody /></div>
    </div>
    <BNav active={3} />
  </Phone>;

// Bottom of the profile page (v7 split version, superseded).
const PROFILE_V7 = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      {/* identity + actions - consistent with Profile top */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
        <div style={{ background: WHITE, borderRadius: HEAD_BTN / 2, height: HEAD_BTN, boxSizing: 'border-box', display: 'flex', alignItems: 'center', padding: '0 18px', boxShadow: SHADOW, fontSize: 17, fontWeight: 700 }}>Ridhwan Ahamed</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
          {['ios_share', 'settings'].map((ic) =>
        <div key={ic} style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Ic n={ic} style={{ fontSize: 20, color: TEXT }} />
            </div>
        )}
        </div>
      </div>
      {/* support links - plain rows, no icons (matches Profile top) */}
      <Card style={{ marginBottom: 16 }}>
        {[['Rate the app'], ['Share feedback'], ['FAQ'], ['Follow us on Instagram']].map(([label], i, arr) =>
      <div key={label} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: i < arr.length - 1 ? `1px solid ${BORDER}` : 'none' }}>
            <span style={{ fontSize: 17 }}>{label}</span>
            <Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
          </div>
      )}
      </Card>
      {/* invite card - same as the share / referral hero */}
      <div style={{ position: 'relative', borderRadius: 20, overflow: 'hidden', background: `linear-gradient(135deg, ${ACC} 0%, #b39df5 52%, #e9c8d8 100%)`, padding: '17px 18px', textAlign: 'center', boxShadow: `0 8px 24px ${ACC}3a` }}>
        <div style={{ position: 'absolute', inset: 0, borderRadius: 20, boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.4)', pointerEvents: 'none' }} />
        <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 54, height: 54, objectFit: 'contain', filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.18))' }} />
        <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 28, fontWeight: 800, color: '#fff', letterSpacing: -0.5, marginTop: 2 }}>Aqademiq</div>
        <div style={{ fontSize: 15, fontWeight: 700, color: 'rgba(255,255,255,0.92)', marginTop: 4 }}>Your focus sanctuary.</div>
      </div>
    </div>
    <BNav active={3} />
  </Phone>;


/* ─── 08 THE CORE - the weekly report ───────────────────────────────────
   Per the "Aqademiq · The Core" concept + build plan. An ice core drilled out
   of the last seven days: a RECORD, not a score. Eight beats - Wrapped opening,
   WHOOP substance - with a landing small enough for a depleted person to take.

   RULES ENFORCED STRUCTURALLY IN THIS SECTION (doc §5):
     · no percentages, no rates, no x-of-y denominators, no progress bars
     · no week-over-week change, no scores, no streaks, no failure red
     · exactly ONE numeral in the whole report, and it is a COUNT of things
       that happened (doc §3 beat 05)
     · a day with nothing logged is an EMPTY BAND, never a puddle
     · a subject that got nothing is an UNLABELLED OUTLINE, never named in copy
     · banned words never rendered: streak · goal · target · consistency ·
       productive · wasted · off week · reserve · low · still · at least ·
       behind · missed
   Voice (doc §7): describe the WEEK, never the person. Ada reads, never grades;
   her expression is floored at neutral. Same register on every week. */

// Monday at the top, as it is drilled. mood = index on the shipped ramp;
// null = nothing logged that day (an empty band).
const CORE_WEEK = [
{ d: 'MON', mood: 1 },
{ d: 'TUE', mood: 2 },
{ d: 'WED', mood: 2 },
{ d: 'THU', mood: null },
{ d: 'FRI', mood: 3 },
{ d: 'SAT', mood: 4 },
{ d: 'SUN', mood: 3 }];

const CORE_THIN = [
{ d: 'MON', mood: null },
{ d: 'TUE', mood: 2 },
{ d: 'WED', mood: null },
{ d: 'THU', mood: null },
{ d: 'FRI', mood: null },
{ d: 'SAT', mood: null },
{ d: 'SUN', mood: null }];

const CORE_ONBOARD = CORE_WEEK.filter((x) => x.mood != null).length; // 6

// Where attention went. The last entry got nothing: it stays an unlabelled
// outline - present in the distribution, never named in copy (doc §3 beat 06).
const CORE_SUBJ = [
{ code: 'CC 401', color: ACC, share: 0.42 },
{ code: 'NET 305', color: SUCC, share: 0.31 },
{ code: 'NLP 302', color: '#5cbbff', share: 0.27 },
{ code: null, color: DIM, share: 0 }];


/* The ice core itself - the hero drawing, and the same drawing everywhere.
   A translucent drilled column; each band is a day, tinted by that day's mood.
   Bands with nothing logged are dashed outlines. `settled` renders the
   freeze-in: bands below it have not landed yet. */
const IceCore = ({ data = CORE_WEEK, w = 96, band = 40, settled = 99, labels = true, mono = false }) => {
  const h = band * data.length;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 9 }}>
      {labels &&
      <div style={{ paddingTop: 6 }}>
          {data.map((row, i) =>
        <div key={i} style={{ height: band, display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
              <span style={{ fontSize: 7.5, fontWeight: 800, letterSpacing: '0.1em', color: i < settled ? DIM : '#e2ded7' }}>{row.d}</span>
            </div>
        )}
        </div>
      }
      <div style={{ position: 'relative', width: w, height: h + 12, flexShrink: 0 }}>
        <div style={{ position: 'absolute', inset: 0, borderRadius: w / 2.4 + 'px / 22px', background: 'rgba(255,255,255,0.55)', boxShadow: '0 6px 22px rgba(90,68,241,0.13), inset 0 0 0 1.5px rgba(255,255,255,0.9)', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: 6, left: 0, right: 0, bottom: 6 }}>
            {data.map((row, i) => {
              const landed = i < settled;
              const empty = row.mood == null;
              const tint = mono ? INK : MOODS[row.mood == null ? 2 : row.mood].color;
              return (
                <div key={i} style={{ height: band, position: 'relative', padding: '2px 5px' }}>
                  <div style={{
                    height: '100%', borderRadius: 7,
                    background: !landed ? 'transparent' : empty ? 'transparent' : mono ? INK + '26' : tint + '3a',
                    border: !landed ? '1.5px dashed #e6e2db' : empty ? '1.5px dashed ' + (mono ? '#cfcbc3' : '#d6d2ca') : '1.5px solid ' + tint + '4d',
                    transition: 'background 400ms ease' }} />
                  {landed && !empty &&
                  <React.Fragment>
                      <div style={{ position: 'absolute', top: band * 0.3, left: 13, width: 3.5, height: 3.5, borderRadius: '50%', background: 'rgba(255,255,255,0.85)' }} />
                      <div style={{ position: 'absolute', top: band * 0.58, left: 21, width: 2.2, height: 2.2, borderRadius: '50%', background: 'rgba(255,255,255,0.7)' }} />
                    </React.Fragment>
                  }
                </div>);

            })}
          </div>
          <div style={{ position: 'absolute', top: 8, bottom: 8, left: w * 0.14, width: w * 0.1, borderRadius: 99, background: 'linear-gradient(rgba(255,255,255,0.9), rgba(255,255,255,0.25))', filter: 'blur(1.5px)', pointerEvents: 'none' }} />
        </div>
        <div style={{ position: 'absolute', top: -1, left: 3, right: 3, height: 13, borderRadius: '50%', border: '1.5px solid rgba(255,255,255,0.95)', background: 'rgba(255,255,255,0.5)', pointerEvents: 'none' }} />
      </div>
    </div>);

};

// Story chrome: a way out, and where you are in the eight beats.
const CoreTop = ({ beat }) =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
    <BarDismiss edge="left" />
    <Dots total={9} active={beat} />
    <span style={{ width: HEAD_BTN - 12, flexShrink: 0 }} />
  </div>;

// Ada reads. Never grades, never prescribes, expression floored at neutral.
const CoreAda = ({ children, expr = 'neutral' }) =>
<div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
    <div style={{ flexShrink: 0 }}><CubeSVG size={28} tone={CUBE_TONES[4]} melt={0} expr={expr} bubbles={2} /></div>
    <div style={{ fontSize: 15, color: TEXT, lineHeight: 1.6 }}>{children}</div>
  </div>;

const CoreCap = ({ children }) =>
<div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.14em', color: DIM, textTransform: 'uppercase' }}>{children}</div>;


/* Entry - it waits in the tab identically every week, with the same frost dot,
   whatever the week held. Never pushed (doc §6). */
const CORE_ENTRY = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <ProfileTopHead />
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '2px 2px 14px' }}>
        <CubeSVG size={46} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks sparkles />
        <div>
          <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: -0.2 }}>Keep it frozen, Ridhwan</div>
          <div style={{ fontSize: 13, color: MED, marginTop: 2 }}>Jun 22 – 28</div>
        </div>
      </div>
      <div style={{ position: 'relative', background: WHITE, borderRadius: 18, boxShadow: SHADOW, padding: '14px 15px', marginBottom: 8, cursor: 'pointer', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: 13, right: 14, width: 8, height: 8, borderRadius: '50%', background: ACC, boxShadow: '0 0 0 4px ' + ACC + '22' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
          <div style={{ flexShrink: 0 }}><IceCore data={CORE_WEEK} w={44} band={15} labels={false} /></div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <CoreCap>Your week</CoreCap>
            <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.4, margin: '4px 0 4px' }}>The Core</div>
            <div style={{ fontSize: 17, color: MED, lineHeight: 1.5 }}>Seven days, drilled and read.</div>
          </div>
        </div>
      </div>
      <Card style={{ marginBottom: 8 }}>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 9 }}>MOOD &amp; DAILY REFLECTIONS</div>
        <MoodWeekRow cube={24} />
      </Card>
      <ProfileLinks rows={[['Rate the app'], ['Share feedback']]} />
    </div>
    <BNav active={3} />
  </Phone>;

/* Beat 01 - the core freezes in. A thing being drilled, not a dashboard loading. */
const CORE_FREEZE = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={0} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <IceCore data={CORE_WEEK} w={104} band={42} settled={3} />
        <div style={{ fontSize: 15, color: DIM, fontWeight: 600, marginTop: 22, letterSpacing: '0.02em' }}>Drilling your week…</div>
      </div>
    </div>
  </Phone>;

/* Beat 02 - the shape of the week. One sentence, full-bleed, before a single
   number appears anywhere. Names the week's shape, never the student. */
const CORE_SHAPE = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={1} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', paddingBottom: 40 }}>
        <CoreCap>The shape of the week</CoreCap>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.28, letterSpacing: -0.6, marginTop: 12, textWrap: 'pretty' }}>
          “A quiet start,<br />then three days<br />that held.”
        </div>
      </div>
    </div>
  </Phone>;

/* Beat 03 - the core itself. The hero. This is the screenshot. */
const CORE_HERO = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={2} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', paddingBottom: 12 }}>
        <IceCore data={CORE_WEEK} w={104} band={42} />
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.6, textAlign: 'center', marginTop: 20, padding: '0 6px' }}>
          Each band is a day, Monday at the top. Tint is that day's mood. Thursday has nothing logged, so it stays an open band.
        </div>
      </div>
    </div>
  </Phone>;

/* Beat 04 - one thing that happened. Exactly one concrete, non-aggregate
   moment: a named task, a named day. */
const CORE_MOMENT = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={3} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', paddingBottom: 40 }}>
        <CoreCap>One thing that happened</CoreCap>
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, lineHeight: 1.35, letterSpacing: -0.4, margin: '12px 0 18px', textWrap: 'pretty' }}>
          Wednesday, you finished the reading you'd moved twice.
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, background: BG, borderRadius: 14, padding: '11px 13px', textAlign: 'left', alignSelf: 'stretch' }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#5cbbff', flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 15, fontWeight: 700 }}>Read Ch. 4: Normalization</div>
            <div style={{ fontSize: 12, color: MED, marginTop: 1 }}>NLP 302 · Wednesday</div>
          </div>
        </div>
      </div>
    </div>
  </Phone>;

/* Beat 05 - the one numeral. Playfair, large, alone. Always a COUNT of things
   that happened: never a rate, percentage, score or change. */
const CORE_NUMERAL = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={4} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', paddingBottom: 30 }}>
        <div style={{ fontFamily: NUMSERIF, fontSize: 132, fontWeight: 800, lineHeight: 0.85, letterSpacing: -4, color: TEXT }}>{CORE_ONBOARD}</div>
        <div style={{ fontSize: 13, fontWeight: 800, letterSpacing: '0.2em', color: DIM, marginTop: 16 }}>DAYS ON THE BOARD</div>
      </div>
    </div>
  </Phone>;

/* Beat 06 - where attention went. One cube per subject in its own tint, melted
   by share. The subject that got nothing is an unlabelled outline. */
const CORE_ATTENTION = () => {
  const top = Math.max(...CORE_SUBJ.map((s) => s.share));
  return (
    <Phone bg={WHITE}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
        <CoreTop beat={5} />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', paddingBottom: 30 }}>
          <CoreCap>Where attention went</CoreCap>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', margin: '22px 0 6px', alignSelf: 'stretch' }}>
            {CORE_SUBJ.map((s, i) => {
              const t = s.share === 0 ? null : Math.min(4, Math.round(1 + s.share / top * 3));
              return (
                <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 9, flex: 1 }}>
                  <div style={{ height: 56, display: 'flex', alignItems: 'flex-end' }}>
                    {t == null ?
                    <div style={{ width: 34, height: 34, borderRadius: 10, border: '1.5px dashed #d6d2ca' }} /> :
                    <CubeSVG size={30 + s.share * 34} tone={{ border: s.color, body: s.color + '33', ink: s.color }} melt={1 - s.share / top} expr="neutral" bubbles={1} />
                    }
                  </div>
                  <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.04em', color: s.code ? TEXT : 'transparent' }}>{s.code || '–'}</span>
                </div>);

            })}
          </div>
          <div style={{ fontSize: 13, color: MED, lineHeight: 1.6, marginTop: 14 }}>
            Compilers took the most of your week. The crisper the cube, the more of your attention it held.
          </div>
        </div>
      </div>
    </Phone>);

};

/* Beat 07 - when you thawed. The count is drawn, not written: one cracked
   cube per thaw, stacked on the day it happened, so the report keeps its one
   numeral. Thawing is how App freeze is meant to work; the copy never grades
   it. Absent when App freeze isn't set up. */
const CORE_THAWS = { TUE: 1, THU: 2, SUN: 1 };
const CORE_THAWED = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={6} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', paddingBottom: 30 }}>
        <CoreCap>When you thawed</CoreCap>
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, lineHeight: 1.35, letterSpacing: -0.4, margin: '12px 0 24px', textWrap: 'pretty' }}>
          The ice held, and you opened it when you needed to.
        </div>
        <div style={{ display: 'flex', alignSelf: 'stretch', background: BG, borderRadius: 18, padding: '18px 8px 14px' }}>
          {CORE_WEEK.map(({ d }) => {
            const n = CORE_THAWS[d] || 0;
            return (
              <div key={d} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                <div style={{ height: 70, display: 'flex', flexDirection: 'column-reverse', alignItems: 'center', gap: 4 }}>
                  {n ? Array.from({ length: n }, (_, i) => <Ic key={i} n="cube_cracked" style={{ fontSize: 30, color: AQ_ICE }} />) : <span style={{ width: 5, height: 5, borderRadius: '50%', background: BORDER, marginBottom: 12 }}></span>}
                </div>
                <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.08em', color: n ? TEXT : DIM }}>{d[0]}</span>
              </div>);
          })}
        </div>
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.6, marginTop: 14, textWrap: 'pretty' }}>
          Each cracked cube is one thaw, on the day it happened. Every one waited a breath first.
        </div>
      </div>
    </div>
  </Phone>;

/* Beat 08 - what the week gave back. The recovery read: end-of-session mood
   against the day's baseline. Renders ONLY when it points positive; otherwise
   the beat is absent, never greyed. Gated on GET /v1/focus-sessions. */
const CORE_GAVE_BACK = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={7} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', paddingBottom: 30 }} data-comment-anchor="9c00115fd5-div-3347-7">
        <CoreCap>What the week gave back</CoreCap>
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, lineHeight: 1.35, letterSpacing: -0.4, margin: '12px 0 20px', textWrap: 'pretty' }}>
          You finished most sessions feeling better than you started them.
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 20, background: BG, borderRadius: 16, padding: '16px 12px', alignSelf: 'stretch' }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7 }}>
            <CubeSVG size={40} tone={CUBE_TONES[1]} melt={0.75} expr="meh" bubbles={1} />
            <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.1em', color: DIM }}>GOING IN</span>
          </div>
          <Ic n="forward" style={{ fontSize: 20, color: DIM }} />
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7 }}>
            <CubeSVG size={40} tone={CUBE_TONES[3]} melt={0.25} expr="smile" bubbles={2} />
            <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.1em', color: DIM }}>COMING OUT</span>
          </div>
        </div>
      </div>
    </div>
  </Phone>;

/* Beat 09 - one small thing. The landing, sized so refusing it would feel
   absurd. Sharing sits beside it, never as the finale. */
const CORE_LANDING = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={8} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', paddingBottom: 24 }}>
        <CoreAda expr="smile">
          One small thing for next week, or just tomorrow's check-in, if that's the size that fits.
        </CoreAda>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: ACCL, border: '1.5px solid ' + ACC + '55', borderRadius: 16, padding: '13px 14px', margin: '18px 0 10px' }}>
          <div style={{ width: 30, height: 30, borderRadius: 10, background: WHITE, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ic n="wind_down" style={{ fontSize: 20, color: ACC }} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 800 }}>Tomorrow's check-in</div>
            <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>Two taps, in the morning.</div>
          </div>
        </div>
        <PBtn>Keep it</PBtn>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 16, marginTop: 14 }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 15, fontWeight: 700, color: MED, cursor: 'pointer' }}>
            <Ic n="share" style={{ fontSize: 19 }} />Share the shape
          </span>
          <span style={{ fontSize: 15, fontWeight: 700, color: MED, cursor: 'pointer' }}>Not this time</span>
        </div>
      </div>
    </div>
  </Phone>;

/* A thin week, told in the same register (doc §7). Beat 04 reaches for the
   smallest true thing rather than skipping; empty days are open bands. */
const CORE_THIN_WEEK = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={2} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', paddingBottom: 12 }}>
        <div style={{ textAlign: 'center', marginBottom: 16 }}>
          <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800, lineHeight: 1.3, letterSpacing: -0.3 }}>“One band, and a<br />lot of open core.”</div>
        </div>
        <IceCore data={CORE_THIN} w={92} band={34} />
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.6, textAlign: 'center', marginTop: 18, padding: '0 4px' }}>
          Tuesday, you opened the compiler notes. That's on the board.
        </div>
      </div>
    </div>
  </Phone>;

/* The story image - the core's ACTIVITY SHAPE only. No mood value, tint, word,
   or anything derived from one may leave in a picture (doc §6). Built at
   360 × 640 (exports ×3 = 1080 × 1920); all content inside Instagram's safe
   band (84 clear top and bottom). Composed as a specimen plate: the week's
   core laid on its side, the one count set huge, Ada signing it. Night ice
   ground in both appearances, so it reads on any feed. */
const STORY_W = 360, STORY_H = 640;
const STORY_ICE = AQ_ICE_ON_DARK, STORY_SUB = 'rgba(255,255,255,0.62)';
const StorySample = ({ data = CORE_WEEK, w = 300, h = 78 }) =>
<div style={{ width: w }}>
    <div style={{ position: 'relative', width: w, height: h, borderRadius: `${h * 0.28}px / ${h / 2}px`, background: 'rgba(255,255,255,0.05)', boxShadow: `0 22px 60px ${AQ_ICE}8c, inset 0 0 0 1.5px rgba(203,188,253,0.42)`, padding: 6, boxSizing: 'border-box', display: 'flex', gap: 3 }}>
      {data.map((row, i) => {
        const on = row.mood != null;
        return (
          <div key={i} style={{ flex: 1, position: 'relative', borderRadius: i === 0 ? `${h * 0.22}px 6px 6px ${h * 0.22}px / ${h * 0.4}px 6px 6px ${h * 0.4}px` : i === data.length - 1 ? `6px ${h * 0.22}px ${h * 0.22}px 6px / 6px ${h * 0.4}px ${h * 0.4}px 6px` : 6, boxSizing: 'border-box', background: on ? `linear-gradient(180deg, #f1ecff 0%, ${STORY_ICE} 48%, #a294f6 100%)` : 'transparent', border: on ? 'none' : '1.5px dashed rgba(203,188,253,0.38)' }}>
            {on && <><span style={{ position: 'absolute', top: '58%', left: '30%', width: 4, height: 4, borderRadius: '50%', background: 'rgba(255,255,255,0.85)' }}></span><span style={{ position: 'absolute', top: '72%', left: '58%', width: 2.5, height: 2.5, borderRadius: '50%', background: 'rgba(255,255,255,0.7)' }}></span></>}
          </div>);
      })}
      <div style={{ position: 'absolute', top: 11, left: h * 0.2, right: h * 0.2, height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.55)', filter: 'blur(1.5px)', pointerEvents: 'none' }}></div>
      <div style={{ position: 'absolute', top: 0, bottom: 0, right: -1, width: h * 0.24, borderRadius: '50%', border: '1.5px solid rgba(255,255,255,0.72)', boxSizing: 'border-box', pointerEvents: 'none' }}></div>
    </div>
    <div style={{ display: 'flex', gap: 3, padding: '0 6px', marginTop: 10 }}>
      {data.map((row, i) => <span key={i} style={{ flex: 1, textAlign: 'center', fontSize: 10, fontWeight: 800, letterSpacing: '0.08em', color: row.mood != null ? 'rgba(255,255,255,0.8)' : 'rgba(255,255,255,0.4)' }}>{row.d[0]}</span>)}
    </div>
  </div>;
const StoryCard = ({ scale = 1, radius = 0 }) =>
<div style={{ width: STORY_W * scale, height: STORY_H * scale, borderRadius: radius, overflow: 'hidden', flexShrink: 0, position: 'relative' }}>
    <div style={{ width: STORY_W, height: STORY_H, transform: `scale(${scale})`, transformOrigin: '0 0', position: 'relative', fontFamily: SANS, color: '#fff', background: `radial-gradient(90% 34% at 50% 70%, ${AQ_ICE}66 0%, transparent 70%), radial-gradient(70% 30% at 20% 8%, ${AQ_ICE}2e 0%, transparent 70%), #13102a` }}>
      <div style={{ position: 'absolute', top: 90, left: 30, right: 30, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <CubeSVG size={30} tone={CUBE_TONES[4]} melt={0} expr="happy" bubbles={2} />
          <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: -0.2 }}>Aqademiq</span>
        </div>
        <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.14em', color: STORY_SUB }}>JUN 22 – 28</span>
      </div>
      <div style={{ position: 'absolute', top: 134, left: 30, right: 30, height: 1, background: 'rgba(255,255,255,0.14)' }}></div>
      <div style={{ position: 'absolute', top: 172, left: 24, right: 30, display: 'flex', alignItems: 'flex-end', gap: 14 }}>
        <span style={{ fontFamily: NUMSERIF, fontSize: 236, fontWeight: 800, lineHeight: 0.8, letterSpacing: -8 }}>{CORE_ONBOARD}</span>
        <span style={{ fontSize: 24, fontWeight: 800, lineHeight: 1.15, letterSpacing: -0.4, paddingBottom: 6 }}>days on<br />the board.</span>
      </div>
      <div style={{ position: 'absolute', top: 400, left: 30 }}><StorySample /></div>
      <div style={{ position: 'absolute', top: 530, left: 30, right: 30, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', fontSize: 13, fontWeight: 700 }}>
        <span style={{ color: STORY_SUB }}>Seven days, drilled.</span>
        <span style={{ color: '#fff' }}>@tryaqademiq</span>
      </div>
    </div>
  </div>;
const CORE_STORY = () => <StoryCard scale={1.1} radius={20} />;

// Share the shape: the story image previewed full, one primary destination.
const CORE_SHARE = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <BackBtn />
        <span style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>Share the shape</span>
      </div>
      <div style={{ flex: 1, minHeight: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ borderRadius: 22, boxShadow: '0 18px 50px rgba(19,16,42,0.34)' }}><StoryCard scale={0.72} radius={22} /></div>
      </div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 14 }}>
        <Ic n="shield" style={{ fontSize: 19, color: MED, flexShrink: 0 }} />
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.6 }}>Your shape only. Nothing about how you felt is in this picture.</div>
      </div>
      <PBtn style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Ic n="share" style={{ fontSize: 20, color: '#fff' }} />Share to your story</PBtn>
      <div style={{ display: 'flex', gap: 8, marginTop: 10, marginBottom: 34 }}>
        <BarPill fill="well" icon="download" label="Save image" style={{ flex: 1, justifyContent: 'center' }} />
        <BarPill fill="well" icon="more" label="More" style={{ flex: 1, justifyContent: 'center' }} />
      </div>
    </div>
  </Phone>;

/* Screenshot caught - the same banner on ANY screen in the app; this frame
   shows it on a Core beat. Non-blocking: drops under the island,
   leaves the OS thumbnail alone, eases away after 6 s. Offers the tag and the
   clean story image on Core screens (a screenshot carries mood tint; the card
   doesn't). Elsewhere the second action shares the screenshot itself. */
const CORE_SCREENSHOT = () =>
<div style={{ position: 'relative', width: 402, height: 874, flexShrink: 0 }}>
    <CORE_HERO />
    <div style={{ position: 'absolute', top: 62, left: 12, right: 12, background: WHITE, borderRadius: 28, boxShadow: '0 14px 44px rgba(20,15,40,0.2), 0 0 0 1px rgba(0,0,0,0.04)', padding: 14, display: 'flex', flexDirection: 'column', gap: 12, fontFamily: SANS }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
        <StoryCard scale={0.125} radius={7} />
        <div style={{ flex: 1, minWidth: 0, paddingTop: 2 }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: TEXT }}>Screenshotting?</div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.45, marginTop: 3, textWrap: 'pretty' }}>Tag us <span style={{ color: ACC, fontWeight: 800 }}>@tryaqademiq</span> on your story. We repost the good ones.</div>
        </div>
        <div style={{ width: HEAD_BTN, height: HEAD_BTN, margin: '-6px -6px 0 0', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, cursor: 'pointer' }}><Ic n="close" style={{ fontSize: 20, color: MED }} /></div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <BarPill fill="well" icon="duplicate" label="Copy tag" style={{ flex: 1, justifyContent: 'center', fontSize: 15 }} />
        <BarPill fill="ink" icon="share" label="Use story card" style={{ flex: 1.3, justifyContent: 'center', fontSize: 15 }} />
      </div>
    </div>
    <div style={{ position: 'absolute', left: 18, bottom: 40, width: 402 * 0.21, height: 874 * 0.21, borderRadius: 12, overflow: 'hidden', boxShadow: '0 8px 26px rgba(0,0,0,0.26), 0 0 0 3px #fff' }}>
      <div style={{ transform: 'scale(0.21)', transformOrigin: '0 0' }}><CORE_HERO /></div>
    </div>
  </div>;

/* A real off switch (doc §6). One tap, honoured immediately. No confirmation,
   no win-back, no re-prompt in a later release. */
const CORE_OFF_SWITCH = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '4px 0 0', marginBottom: 16 }}>
        <BackBtn />
        <span style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>Weekly report</span>
      </div>
      <SetGroup style={{ marginBottom: 12 }}>
        <SetRow label="Show me The Core" toggle={true} last />
      </SetGroup>
      <div style={{ fontSize: 15, color: MED, lineHeight: 1.65, padding: '0 3px', marginBottom: 18 }}>
        One tap turns it off, immediately. We won't ask again.
      </div>
      <GroupLabel>What it never does</GroupLabel>
      <SetGroup>
        <SetRow icon="notifications_off" label="Notify you" sub="It waits in the tab, the same way every week." />
        <SetRow icon="history_toggle_off" label="Open on a past week" sub="Current week only." />
        <SetRow icon="visibility_off" label="Show what you wrote" sub="Never shown or exported." last />
      </SetGroup>
    </div>
    <BNav active={3} />
  </Phone>;

/* A rule for a bad season, not a bad week (doc §6). One quiet, dismissible
   line OUTSIDE the story, in plain product voice - not the mascot's. No
   escalation, no advice, and Ada does not comment. At most once a month. */
const CORE_SUPPORT_LINE = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <CoreTop beat={2} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', paddingBottom: 12 }}>
        <IceCore data={CORE_THIN} w={92} band={34} />
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.6, textAlign: 'center', marginTop: 18 }}>
          Tuesday, you opened the compiler notes. That's on the board.
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: BG, borderRadius: 14, padding: '11px 12px', marginBottom: 14 }}>
        <div style={{ flex: 1, fontSize: 13, color: MED, lineHeight: 1.55 }}>
          Support resources are available any time, if you'd like them. <span style={{ fontWeight: 800, color: TEXT }}>View</span>
        </div>
        <Ic n="close" style={{ fontSize: 21, color: DIM, cursor: 'pointer', flexShrink: 0 }} />
      </div>
    </div>
  </Phone>;


/* ─── 12 FEEDBACK ────────────────────────────────────────────────────────
   Reached from Profile/Stats → "Share feedback". A pushed page (no bottom nav)
   with a floating action; List + Board views, plus the suggestion + sort sheets. */

// Ada in the feedback promo banner - the same ice cube as everywhere else.
const AdaTile = ({ size = 42 }) =>
<div style={{ width: size, height: size, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <AdaBlob size={size} />
  </div>;

const FeedChip = ({ label, dot, active }) =>
<div style={{ flexShrink: 0, display: 'flex', alignItems: 'center', gap: 6, background: active ? INK : WHITE, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: dot ? '0 14px 0 12px' : '0 16px', boxShadow: active ? 'none' : SHADOW }}>
    {dot && <span style={{ width: 6, height: 6, borderRadius: '50%', background: dot }} />}
    <span style={{ fontSize: 15, fontWeight: 700, color: active ? '#fff' : TEXT }}>{label}</span>
  </div>;

// Filled list - the live board's first four cards.
const FB_KIND = { Feature: ['lightbulb', ACC, ACCL], Improvement: ['tune', '#2a76b3', '#5cbbff24'] };
const FB_ITEMS = [
{ t: 'Amazing app', n: 3, body: 'this app changed my life. what an app! great app! no more procrastination!!.', c: 1, kind: 'Feature', v: 7, on: true },
{ t: 'suggestion on study timer', n: 12, body: 'it would be helpful if the timer for study timer be displayed on the lock screen to prevent breaking out of focus', c: 0, kind: 'Improvement', v: 3, on: true },
{ t: 'I really love the app. fabulous', n: 4, c: 0, kind: 'Feature', v: 3, on: true },
{ t: 'minor nitpicks', n: 18, body: 'no delete session button while ending a session, when i was trying to write this from guestmode was a bit confusing', c: 0, kind: 'Improvement', v: 2, on: false }];
const FB_FADE = 'linear-gradient(to bottom, #000 calc(100% - 100px), transparent calc(100% - 84px))';
const FeedCard = ({ it }) => {
  const [ic, ink, tint] = FB_KIND[it.kind];
  return (
    <div style={{ flexShrink: 0, display: 'flex', gap: 14, background: WHITE, borderRadius: 18, boxShadow: SHADOW, padding: '13px 12px 10px 15px' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: 800, lineHeight: 1.25, color: TEXT }}>{it.t} <span style={{ fontWeight: 700, color: DIM }}>#{it.n}</span></div>
        {it.body && <div style={{ fontSize: 15, color: MED, lineHeight: 1.42, marginTop: 3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{it.body}</div>}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 6 }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 15, fontWeight: 700, color: MED, whiteSpace: 'nowrap' }}><span style={{ width: 6, height: 6, borderRadius: '50%', background: '#9aa3b2' }}></span>Under review</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 15, fontWeight: 700, color: DIM }}><Ic n="chat_bubble_outline" style={{ fontSize: 18 }} />{it.c}</span>
          <span style={{ marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 4, background: tint, color: ink, borderRadius: 8, padding: '3px 8px', fontSize: 15, fontWeight: 800, whiteSpace: 'nowrap' }}><Ic n={ic} style={{ fontSize: 16 }} />{it.kind}</span>
        </div>
      </div>
      <div style={{ flexShrink: 0, width: 46, height: 30, boxSizing: 'border-box', borderRadius: 10, border: `1.5px solid ${it.on ? ACC : BORDER}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Ic n="chevron_up" style={{ fontSize: 20, color: it.on ? ACC : MED, marginLeft: -4 }} />
        <span style={{ fontSize: 17, fontWeight: 800, color: TEXT }}>{it.v}</span>
      </div>
    </div>);
};

// The Feedback page body (header → toggle → search → filters/columns → content).
// Reused dimmed behind the suggestion / sort sheets. `view` = 'list' | 'board'.
const FeedbackBody = ({ view = 'list', filterShift = 0, filled = false }) => {
  const chips = [
  ['All', null, true], ['Under review', '#9aa3b2'], ['Planned', ACC],
  ['In progress', WARN], ['Shipped', '#9aa3b2'], ['Declined', '#9aa3b2']];

  const cols = [['Open', '#9aa3b2'], ['Planned', ACC], ['In progress', WARN]];
  return (
    <div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0, padding: '8px 16px 0', display: 'flex', flexDirection: 'column' }}>
      {/* header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
        <div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: WHITE, boxShadow: SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Ic n="back" style={{ fontSize: 22, color: TEXT }} />
        </div>
        <span style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>Feedback</span>
      </div>
      {/* List / Board toggle */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 11 }}>
        {[['view_agenda', 'List', 'list'], ['view_week', 'Board', 'board']].map(([ic, lb, v]) => {
          const on = view === v;
          return (
            <div key={v} style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, padding: '10px 0', borderRadius: 12, background: on ? ACCL : PILL, border: `1.5px solid ${on ? ACC : 'transparent'}` }}>
              <Ic n={ic} style={{ fontSize: 20, color: on ? ACC : MED }} />
              <span style={{ fontSize: 17, fontWeight: 700, color: on ? ACC : MED }}>{lb}</span>
            </div>);

        })}
      </div>
      {/* search + sort */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8, background: WHITE, borderRadius: HEAD_BTN / 2, height: HEAD_BTN, boxSizing: 'border-box', padding: '0 14px', boxShadow: SHADOW }}>
          <Ic n="search" style={{ fontSize: 20, color: DIM }} />
          <span style={{ fontSize: 17, color: DIM }}>Search suggestions</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, background: WHITE, borderRadius: HEAD_BTN / 2, height: HEAD_BTN, boxSizing: 'border-box', padding: '0 15px 0 13px', boxShadow: SHADOW }}>
          <Ic n="sort" style={{ fontSize: 19, color: TEXT }} />
          <span style={{ fontSize: 17, fontWeight: 700 }}>Top</span>
        </div>
      </div>
      {view === 'list' ?
      <>
          {/* filter chips (horizontal) */}
          <div style={{ overflow: 'hidden', margin: '0 -16px 12px', padding: '0 16px' }}>
            <div style={{ display: 'flex', gap: 8, transform: `translateX(${-filterShift}px)` }}>
              {chips.map(([l, d, a]) => <FeedChip key={l} label={l} dot={d} active={a} />)}
            </div>
          </div>
          {/* promo banner */}
          <div style={{ background: ACCL, borderRadius: 16, padding: '11px 14px', marginBottom: 16 }}>
            <div style={{ display: 'flex', gap: 11, marginBottom: 9 }}>
              <AdaTile />
              <span style={{ fontSize: 15, fontWeight: 600, lineHeight: 1.45, color: TEXT }}>We'd love to hear your ideas. Suggest features and upvote what matters to you.</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 15, fontWeight: 800, color: ACC }}>Join user research →</span>
              <span style={{ fontSize: 15, fontWeight: 800, color: ACC }}>Found a bug?</span>
            </div>
          </div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', color: DIM, marginBottom: 9 }}>SUGGESTIONS ({filled ? 18 : 0})</div>
          {filled ?
          <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 8, margin: '0 -16px', padding: '0 16px', WebkitMaskImage: FB_FADE, maskImage: FB_FADE }}>
            {FB_ITEMS.map((it) => <FeedCard key={it.n} it={it} />)}
          </div> :
          /* empty state - centered in the space above the floating action */
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 20px 72px' }}>
            <Ic n="search" style={{ fontSize: 34, color: '#d6d2ca', marginBottom: 8 }} />
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 6 }}>No suggestions match</div>
            <div style={{ fontSize: 15, color: MED, lineHeight: 1.5 }}>Try a different search or filter, or make the first suggestion.</div>
          </div>}
        </> :

      <>
          {/* board columns */}
          <div style={{ display: 'flex', gap: 12, overflow: 'hidden', margin: '0 -16px', padding: '0 16px', flex: 1 }}>
            {cols.map(([l, d]) =>
          <div key={l} style={{ flexShrink: 0, width: 200 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: HILITE, borderRadius: 12, padding: '11px 14px', marginBottom: 12 }}>
                  <span style={{ width: 7, height: 7, borderRadius: '50%', background: d }} />
                  <span style={{ fontSize: 17, fontWeight: 800 }}>{l}</span>
                  <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>0</span>
                </div>
                <div style={{ textAlign: 'center', fontSize: 15, color: DIM, marginTop: 120 }}>Nothing here yet</div>
              </div>
          )}
          </div>
        </>
      }
    </div>);

};

// Floating pill action shared by both views.
const MakeSuggestionBtn = () =>
<div style={{ position: 'absolute', left: 16, right: 16, bottom: 40, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, boxShadow: '0 8px 24px rgba(0,0,0,0.22)' }}>
    <Ic n="add" style={{ fontSize: 18, color: '#fff' }} />
    <span style={{ fontSize: 17, fontWeight: 800, color: '#fff' }}>Make a suggestion</span>
  </div>;

const FEEDBACK_LIST = () =>
<Phone><FeedbackBody view="list" /><MakeSuggestionBtn /></Phone>;

const FEEDBACK_LIST_FILLED = () =>
<Phone><FeedbackBody view="list" filled /><MakeSuggestionBtn /></Phone>;

const FEEDBACK_LIST_FILTERS = () =>
<Phone><FeedbackBody view="list" filterShift={210} /><MakeSuggestionBtn /></Phone>;

const FEEDBACK_BOARD = () =>
<Phone><FeedbackBody view="board" /><MakeSuggestionBtn /></Phone>;

// Make-a-suggestion - bottom sheet over the dimmed list.
const MAKE_SUGGESTION_SHEET = () => {
  const kinds = [['lightbulb', 'Feature', true], ['tune', 'Improvement'], ['bug_report', 'Bug']];
  return (
    <Phone>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.4, pointerEvents: 'none' }}><FeedbackBody view="list" /></div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.42)' }} />
      <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -12px 48px rgba(20,15,28,0.28)', padding: '12px 18px 38px' }}>
        <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 3 }}>
      <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>Make a suggestion</div>
      <BarDismiss tight />
    </div>
    <div style={{ fontSize: 15, color: MED, marginBottom: 14 }}>Share an idea. The community votes on what gets built.</div>
        <div style={{ display: 'flex', gap: 7, marginBottom: 16 }}>
          {kinds.map(([ic, lb, on]) =>
          <div key={lb} style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5, padding: '9px 0', borderRadius: 12, background: on ? ACCL : HILITE, border: `1.5px solid ${on ? ACC : 'transparent'}` }}>
              <Ic n={ic} style={{ fontSize: 18, color: on ? ACC : MED }} />
              <span style={{ fontSize: 15, fontWeight: 700, color: on ? ACC : MED }}>{lb}</span>
            </div>
          )}
        </div>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 7 }}>TITLE</div>
        <div style={{ background: WHITE, border: `1.5px solid ${ACC}`, borderRadius: 12, padding: '12px 14px', marginBottom: 15 }}>
          <span style={{ fontSize: 17, color: DIM }}><span style={{ color: ACC }}>|</span>One clear sentence</span>
        </div>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 7 }}>DETAILS (OPTIONAL)</div>
        <div style={{ background: HILITE, borderRadius: 12, padding: '12px 14px', marginBottom: 18, minHeight: 52 }}>
          <span style={{ fontSize: 17, color: DIM, lineHeight: 1.45 }}>What problem does it solve? How should it work?</span>
        </div>
        <div style={{ background: HILITE, borderRadius: 100, height: 50, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#b0aaa2' }}>Share suggestion</div>
      </div>
    </Phone>);

};

// Sort suggestions - bottom sheet over the dimmed board.
const SORT_SHEET = () =>
<Phone>
    <div style={{ position: 'absolute', inset: 0, opacity: 0.4, pointerEvents: 'none' }}><FeedbackBody view="board" /></div>
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.42)' }} />
    <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -12px 48px rgba(20,15,28,0.28)', padding: '12px 18px 40px' }}>
      <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 14px' }} />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 2 }}>
      <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>Sort suggestions</div>
      <BarDismiss tight />
    </div>
    <div style={{ fontSize: 15, color: MED, marginBottom: 16 }}>Choose how the board is ordered</div>
      {[['trending_up', 'Most voted', 'What the community wants most', true], ['schedule', 'Newest', 'Fresh ideas first']].map(([ic, lb, sub, on]) =>
    <div key={lb} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '13px 15px', borderRadius: 16, background: on ? ACCL : HILITE, border: `1.5px solid ${on ? ACC : 'transparent'}`, marginBottom: 10 }}>
          <Ic n={ic} style={{ fontSize: 21, color: on ? ACC : TEXT }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 700, color: on ? ACC : TEXT }}>{lb}</div>
            <div style={{ fontSize: 15, color: MED, marginTop: 1 }}>{sub}</div>
          </div>
          {on && <Ic n="check_circle:fill" style={{ fontSize: 22, color: ACC }} />}
        </div>
    )}
    </div>
  </Phone>;


/* ─── 07 MOOD CHECK-IN ───────────────────────────────────────────────── */

// Blob morphs per mood: 5 states reflected in SVG path + expression
// Labels per rating; color = paling-periwinkle ramp (used for rings, labels, slider fills, calendar dots)
const MOODS = [
{ label: 'Rough', color: '#a79fc4' },
{ label: 'Tired', color: '#9286d2' },
{ label: 'OK', color: '#7d70d9' },
{ label: 'Good', color: '#6a5ce4' },
{ label: 'Great', color: '#5a44f1' }];


// Melting ice-cube rating: best (idx 4) = crisp & vivid, worst (idx 0) = pale melted puddle.
const MOOD_EXPR = ['sad', 'meh', 'neutral', 'smile', 'happy'];
const MOOD_BUBBLES = [0, 1, 1, 2, 3];
const MoodBlob = ({ idx = 2, size = 80 }) => {
  const scale = 0.72 + idx * 0.07; // worse ratings render physically smaller
  return (
    <div style={{ width: size, height: size, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <CubeSVG size={size * scale} tone={CUBE_TONES[idx]} melt={(4 - idx) / 4} expr={MOOD_EXPR[idx]} bubbles={MOOD_BUBBLES[idx]} cheeks={idx === 4} sparkles={idx === 4} sweat={idx === 1} />
    </div>);

};

const MOOD_CHECKIN = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '10px 22px 0' }}>
      <div style={{ width: '100%', display: 'flex', justifyContent: 'flex-end', marginBottom: 8 }}>
        <span style={{ height: HEAD_BTN, display: 'flex', alignItems: 'center', margin: '-15px -10px', padding: '0 10px', fontSize: 15, color: DIM, fontWeight: 600, cursor: 'pointer' }}>Skip</span>
      </div>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, textAlign: 'center', marginBottom: 4 }}>Morning<br />check-in</div>
      <div style={{ fontSize: 17, color: DIM, marginBottom: 14 }}>How are you feeling today?</div>
      <MoodBlob idx={3} size={84} />
      <div style={{ fontSize: 17, fontWeight: 800, color: MOODS[3].color, marginTop: 6, marginBottom: 14 }}>Good</div>
      {/* Mood slider - flex segments keep dots evenly spaced, fill aligns to the selection */}
      <div style={{ width: '100%', padding: '0 22px 22px', marginBottom: 6, position: 'relative' }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          {MOODS.map((mood, i) => {
          const sel = i === 3,filled = i <= 3;
          return (
            <React.Fragment key={i}>
                {i > 0 && <div style={{ flex: 1, height: 4, borderRadius: 2, background: filled ? MOODS[3].color : BG, opacity: filled ? 0.45 : 1 }} />}
                <div style={{ position: 'relative', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <div style={{ width: sel ? 34 : 24, height: sel ? 34 : 24, borderRadius: '50%', background: sel ? mood.color + '22' : WHITE, border: sel ? `2.5px solid ${mood.color}` : `2px solid ${BORDER}`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: sel ? `0 2px 8px ${mood.color}40` : 'none' }}>
                    <div style={{ width: sel ? 13 : 8, height: sel ? 13 : 8, borderRadius: '50%', background: mood.color, opacity: sel ? 1 : 0.45 }} />
                  </div>
                  <span style={{ position: 'absolute', top: '100%', left: '50%', transform: 'translateX(-50%)', marginTop: 7, fontSize: 12, fontWeight: 700, whiteSpace: 'nowrap', color: sel ? mood.color : DIM }}>{mood.label}</span>
                </div>
              </React.Fragment>);

        })}
        </div>
      </div>
      <Card style={{ width: '100%', background: ACCL, boxShadow: 'none', marginBottom: 14 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <AdaBlob size={24} mood="happy" />
          <span style={{ fontSize: 15, color: TEXT, lineHeight: 1.6 }}>Nice! On "Good" days you average 2.4 hrs of deep focus. I've scheduled your hardest task for 2 PM.</span>
        </div>
      </Card>
      <PBtn>Set today's intention →</PBtn>
    </div>
  </Phone>;


const MOOD_EVENING = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '10px 22px 0' }}>
      <div style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <span style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', color: DIM }}>MON · 18 MAY</span>
        <span style={{ height: HEAD_BTN, display: 'flex', alignItems: 'center', margin: '-15px -10px', padding: '0 10px', fontSize: 15, color: DIM, fontWeight: 600, cursor: 'pointer' }}>Skip</span>
      </div>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>Evening<br />reflection</div>
      <div style={{ fontSize: 17, color: DIM, marginBottom: 18 }}>How did today go?</div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 22, padding: '0 2px' }}>
        {MOODS.map((mood, i) =>
      <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
            <div style={{ padding: 3, borderRadius: '50%', border: i === 3 ? `2px solid ${mood.color}` : '2px solid transparent', background: i === 3 ? mood.color + '14' : 'transparent' }}>
              <MoodBlob idx={i} size={i === 3 ? 34 : 31} />
            </div>
            <span style={{ fontSize: 12, fontWeight: 700, color: i === 3 ? mood.color : DIM }}>{mood.label}</span>
          </div>
      )}
      </div>
      <SLabel>Optional note</SLabel>
      <div style={{ background: BG, borderRadius: 14, padding: '12px 14px', fontSize: 17, color: DIM, marginBottom: 14, minHeight: 70 }}>What made today that way?</div>
      <Card style={{ marginBottom: 18 }}>
        <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 700, marginBottom: 8 }}>This week's mood</div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          {[2, 3, 1, 4, 3, null, null].map((idx, i) =>
        <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div style={{ width: 24, height: 24, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {idx !== null ?
            <MoodBlob idx={idx} size={24} /> :
            <div style={{ width: 22, height: 22, borderRadius: '50%', background: BG }} />}
              </div>
              <span style={{ fontSize: 12, color: DIM }}>{'MTWTFSS'[i]}</span>
            </div>
        )}
        </div>
      </Card>
      <PBtn>Save reflection →</PBtn>
    </div>
  </Phone>;


/* ─── 09 CONTEXT / OVERFLOW MENUS ───────────────────────────────────── */

const TASK_OVERFLOW = () =>
<Phone>
    {/* dimmed real Plan page underneath */}
    <div style={{ padding: '0 16px', opacity: 0.4, pointerEvents: 'none' }}>
      <PlanHeader />
      <PlanDateStrip />
      <div style={{ marginBottom: 10 }}><CollapseHead icon="schedule" label="ANYTIME" count={3} open /></div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <PlanTask title="Read chapter 4" dur="10m" tag="CC 401" color={ACC} />
        <PlanTask title="Review lecture slides" dur="5m" tag="NLP 302" color="#5cbbff" />
      </div>
      <div style={{ margin: '8px 0 2px' }}><CollapseHead label="PLANNED" count={3} open /></div>
      <TimeLabel>11:30 AM</TimeLabel>
      <PlanTask title="LL(1) parsing notes" dur="30m" tag="CC 401" color={ACC} bar />
    </div>
    {/* scrim */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.3)' }} />
    {/* action sheet - white runs flush to the bottom so it merges with the nav */}
    <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -8px 40px rgba(0,0,0,0.18)', overflow: 'hidden', padding: '10px 0px 89px' }}>
      <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 12px' }} />
      <div style={{ padding: '0 18px 12px', borderBottom: `1px solid ${BORDER}` }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3 }}>
          <div style={{ width: 7, height: 7, borderRadius: '50%', background: ACC }} />
          <span style={{ fontSize: 12, fontWeight: 800, color: ACC }}>CC 401</span>
        </div>
        <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 700 }}>LL(1) parsing notes</div>
        <div style={{ fontSize: 15, color: DIM }}>35 min · Ada generated · 3 microtasks</div>
      </div>
      {[
    ['check_circle_outline', 'Mark as done', TEXT, false],
    ['timer', 'Start session', ACC, false],
    ['carry_forward', 'Reschedule', TEXT, false],
    ['auto_awesome', 'Break down more', TEXT, false],
    ['arrow_forward', 'Move to tomorrow', TEXT, false],
    ['delete_outline', 'Delete', '#e85476', true]].
    map(([icon, label, color, last]) =>
    <div key={label} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 14, padding: '12px 18px', backgroundImage: last ? 'none' : `linear-gradient(${BORDER}, ${BORDER})`, backgroundSize: `calc(100% - 50px) 1px`, backgroundPosition: '100% 100%', backgroundRepeat: 'no-repeat' }}>
          <Ic n={icon} style={{ fontSize: 18, color }} />
          <span style={{ fontSize: 17, fontWeight: 600, color }}>{label}</span>
        </div>
    )}
    </div>
    <BNav active={1} />
  </Phone>;


const TASK_SWIPE = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <PlanHeader />
      <PlanDateStrip />
      <div style={{ margin: '2px 0 2px' }}><CollapseHead label="PLANNED" count={3} open /></div>
      <TimeLabel>11:30 AM</TimeLabel>
      {/* swiped card revealing Later / Delete */}
      <div style={{ position: 'relative', borderRadius: 16, overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: 0, right: 0, bottom: 0, display: 'flex' }}>
          <div style={{ width: 62, background: WARN, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2 }}>
            <Ic n="carry_forward" style={{ fontSize: 20, color: '#fff' }} />
            <span style={{ fontSize: 11, color: '#fff', fontWeight: 700 }}>Later</span>
          </div>
          <div style={{ width: 62, background: '#e85476', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2 }}>
            <Ic n="delete" style={{ fontSize: 20, color: '#fff' }} />
            <span style={{ fontSize: 11, color: '#fff', fontWeight: 700 }}>Delete</span>
          </div>
        </div>
        <div style={{ marginRight: 124, position: 'relative' }}>
          <PlanTask title="LL(1) parsing notes" dur="30m" tag="CC 401" color={ACC} bar />
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 4px 6px' }}>
        <Ic n="swipe_left" style={{ fontSize: 18, color: DIM }} />
        <span style={{ fontSize: 13, color: DIM, fontWeight: 600 }}>Swipe a task to reschedule or delete</span>
      </div>
      <TimeLabel>12:00 PM</TimeLabel>
      <PlanTask title="Assignment 3 draft" dur="30m" tag="NLP 302" color="#5cbbff" bar />
    </div>
    <BNav active={1} />
  </Phone>;


/* ─── 13 SETTINGS ─────────────────────────────────────────────────────── */

// Scroll shell for every settings screen. big = the home screen's stacked
// back-button + large title; otherwise an inline back + title.
// Space the floating bottom nav needs at the foot of every settings screen.
const NAV_CLEARANCE = 95;
// Soft fade so a long list dissolves into the nav instead of being hard-cut.
const LIST_FADE = 'linear-gradient(to bottom, #000 calc(100% - 93px), rgba(0,0,0,0.15) calc(100% - 49px), transparent calc(100% - 27px))';
// Two-sided fade for a scrolled-down state (content continues above + below).
const LIST_FADE_BOTH = 'linear-gradient(to bottom, transparent 0, #000 26px, #000 calc(100% - 93px), rgba(0,0,0,0.15) calc(100% - 49px), transparent calc(100% - 27px))';

// Header + scrollable body for a settings screen, WITHOUT the Phone shell or
// nav - so it can be reused as a faithful dimmed backdrop behind a sheet.
// `offset` simulates a scrolled-down state (shifts the list up).
const SetBody = ({ title, big, gear, children, offset = 0 }) =>
<div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0, display: 'flex', flexDirection: 'column' }}>
    <div style={{ padding: '4px 16px 0', flexShrink: 0 }}>
      {big ?
    <>
          <BackBtn style={{ marginBottom: 14 }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 16 }}>
            {gear && <Ic n="settings" style={{ fontSize: 25, color: TEXT }} />}
            <span style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800 }}>{title}</span>
          </div>
        </> :

    <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <BackBtn />
          <span style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>{title}</span>
        </div>
    }
    </div>
    <div style={{ flex: 1, overflow: 'hidden', padding: '0 16px', WebkitMaskImage: offset ? LIST_FADE_BOTH : LIST_FADE, maskImage: offset ? LIST_FADE_BOTH : LIST_FADE }}>
      <div style={{ transform: `translateY(${-offset}px)` }}>
        {children}
        <div style={{ height: NAV_CLEARANCE, flexShrink: 0 }} />
      </div>
    </div>
  </div>;

const SetScreen = ({ title, big, gear, offset, children }) =>
<Phone>
    <SetBody title={title} big={big} gear={gear} offset={offset}>{children}</SetBody>
    <BNav active={3} />
  </Phone>;

// Shared full-screen scrim + slide-up panel for every settings sheet, with the
// real (dimmed) screen behind it. `body` is the SetBody to dim; `panel` the sheet.
const SettingsSheet = ({ body, nav = true, panel }) =>
<Phone>
    {body}
    {nav && <BNav active={3} />}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.42)' }} />
    {panel}
  </Phone>;

// Settings home content (also used as the dimmed backdrop behind sheets).
const HomeBody = () =>
<>
    {/* profile card → opens Profile edit */}
    <div style={{ display: 'flex', alignItems: 'center', gap: 13, background: WHITE, borderRadius: 18, boxShadow: SHADOW, padding: '13px 15px', marginBottom: 20 }}>
      <div style={{ width: 46, height: 46, borderRadius: '50%', background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})`, flexShrink: 0, boxShadow: `0 4px 14px ${ACC}44`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28 }}>🎓</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: 800 }}>Ridhwan Ahamed</div>
        <div style={{ fontSize: 15, color: MED, marginTop: 1 }}>BITS Pilani Dubai · CS Undergrad</div>
      </div>
      <Ic n="chevron_right" style={{ fontSize: 20, color: DIM, flexShrink: 0 }} />
    </div>
    {/* study tags */}
    <GroupLabel>Study tags</GroupLabel>
    <div style={{ background: WHITE, borderRadius: 18, boxShadow: SHADOW, padding: '13px 13px 14px', marginBottom: 7 }}>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7 }}>
        {[['Lecture', '#5cbbff'], ['Class', ACC], ['Exam', '#e85476'], ['Assignment', SUCC], ['Report', WARN], ['Presentation', '#c0497b'], ['Reading', '#9aa3b2']].map(([t, c]) =>
      <div key={t} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: WHITE, border: `1px solid ${BORDER}`, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 10px 0 9px' }}>
            <Ic n={'task_' + AQ_TAG[t]} style={{ fontSize: 18, color: IS_DARK ? c : AQ_TAG_INK[AQ_TAG[t]] }} />
            <span style={{ fontSize: 15, fontWeight: 700, color: TEXT }}>{t}</span>
            <Ic n="close" style={{ fontSize: 16, color: DIM }} />
          </div>
      )}
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 3, border: `1.5px dashed ${ACC}88`, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 12px 0 10px', color: ACC, fontSize: 15, fontWeight: 700 }}>
          <Ic n="add" style={{ fontSize: 18 }} />New tag
        </div>
      </div>
    </div>
    <div style={{ fontSize: 13, color: MED, lineHeight: 1.5, margin: '0 4px 20px' }}>Ada uses your tags to read your workload and shape your plan.</div>
    {/* preferences - one consolidated group */}
    <GroupLabel>Preferences</GroupLabel>
    <SetGroup style={{ marginBottom: 20 }}>
      <SetRow icon="notifications_none" label="Notifications" chevron />
      <SetRow icon="auto_mode" label="Appearance" value="System" chevron />
      <SetRow icon="vibration" label="Haptics" value="Essential" chevron />
      <SetRow icon="graphic_eq" label="Prism" value="Deep Work" chevron />
      <SetRow icon="ac_unit" label="App freeze" value="On" chevron />
      <SetRow icon="calendar_today" label="Calendar import" chevron />
      <SetRow icon="format_list_bulleted" label="Reminder import" chevron last />
    </SetGroup>
    {/* account + about */}
    <GroupLabel>Account</GroupLabel>
    <SetGroup style={{ marginBottom: 20 }}>
      <SetRow icon="mail" label="Email settings" chevron />
      <SetRow icon="logout" label="Sign out" chevron />
      <SetRow icon="delete_outline" label="Delete account" chevron danger last />
    </SetGroup>
    <GroupLabel>About</GroupLabel>
    <SetGroup>
      <SetRow icon="play_circle_outline" label="Ice Breakers" value="3 of 6" chevron />
      <SetRow icon="star_outline" label="Rate Aqademiq" chevron />
      <SetRow icon="description" label="Privacy Policy" chevron />
      <SetRow icon="help_outline" label="Terms of service" chevron last />
    </SetGroup>
  </>;

const SETTINGS_HOME = () =>
<SetScreen title="Settings" big gear><HomeBody /></SetScreen>;

// Profile edit content (also used as the dimmed backdrop behind name/email sheets).
const ProfileBody = () =>
<>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 20 }}>
      <div style={{ width: 72, height: 72, borderRadius: '50%', background: `radial-gradient(circle at 38% 33%, ${ACCL}, ${ACC})`, boxShadow: `0 6px 20px ${ACC}44`, marginBottom: 9, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 34 }}>🎓</div>
      <div style={{ fontSize: 17, fontWeight: 800, color: ACC }}>Change photo</div>
    </div>
    <GroupLabel>Personal</GroupLabel>
    <SetGroup style={{ marginBottom: 20 }}>
      <SetRow label="Name" value="Ridhwan Ahamed" chevron />
      <SetRow label="Gender" value="Prefer not to say" chevron />
      <SetRow label="Date of birth" value="Add" chevron last />
    </SetGroup>
    <GroupLabel>Account</GroupLabel>
    <SetGroup style={{ marginBottom: 20 }}>
      <SetRow label="Email" value="f20230375@dubai…" chevron />
      <SetRow label="Password" chevron last />
    </SetGroup>
    <GroupLabel>Study</GroupLabel>
    <SetGroup>
      <SetRow label="University" value="BITS Dubai" chevron />
      <SetRow label="Program" value="CS · Undergrad" chevron last />
    </SetGroup>
  </>;

const SETTINGS_PROFILE = () =>
<SetScreen title="Profile"><ProfileBody /></SetScreen>;

// Settings - scrolled down (collapsed header). Same page as the home, lower down.
const SETTINGS_ACCOUNT = () =>
<SetScreen title="Settings" offset={600}><HomeBody /></SetScreen>;

// Notifications content (also used dimmed behind the sound sheet).
const NotifBody = () =>
<>
    <SetGroup style={{ marginBottom: 18 }}>
      <SetRow label="Notification sound" value="Chime" chevron last />
    </SetGroup>
    <GroupLabel>Tasks</GroupLabel>
    <SetGroup style={{ marginBottom: 18 }}>
      <SetRow label="Before task" toggle={false} />
      <SetRow label="When a task starts" toggle={true} />
      <SetRow label="Halfway through task" toggle={false} />
      <SetRow label="When a task is finished" toggle={false} last />
    </SetGroup>
    <GroupLabel>Time of day reminders</GroupLabel>
    <SetGroup>
      <SetRow label="All day & anytime" toggle={true} />
      <SetRow label="At time" pill="7:00 AM" />
      <SetRow label="Morning" toggle={true} />
      <SetRow label="At time" pill="8:00 AM" last />
    </SetGroup>
  </>;

const NOTIFICATIONS = () =>
<SetScreen title="Notifications"><NotifBody /></SetScreen>;

// Notifications - scrolled: reminders → review your day → other.
const NOTIFICATIONS_MORE = () =>
<SetScreen title="Notifications">
    <GroupLabel>Time of day reminders</GroupLabel>
    <SetGroup style={{ marginBottom: 16 }}>
      <SetRow label="All day & anytime" toggle={true} />
      <SetRow label="At time" pill="7:00 AM" />
      <SetRow label="Morning" toggle={true} />
      <SetRow label="At time" pill="8:00 AM" last />
    </SetGroup>
    <GroupLabel>Review your day</GroupLabel>
    <SetGroup style={{ marginBottom: 16 }}>
      <SetRow label="Review today notifications" toggle={true} />
      <SetRow label="At time" pill="8:00 PM" last />
    </SetGroup>
    <GroupLabel>Other</GroupLabel>
    <SetGroup>
      <SetRow label="State of mind reminder" toggle={true} />
      <SetRow label="Motivational" toggle={true} />
      <SetRow label="Product updates" toggle={true} last />
    </SetGroup>
  </SetScreen>;

// Compact dimmed settings list behind a popover / sheet.
// Slide-up sheet container - drag handle + optional title.
const SheetPanel = ({ title, children }) =>
<div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -12px 48px rgba(20,15,28,0.28)', padding: '12px 18px 40px' }}>
    <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 16px' }} />
    {title && <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800, marginBottom: 16 }}>{title}</div>}
    {children}
  </div>;

// Appearance - bottom sheet over the (real, dimmed) settings home.
const APPEARANCE_PICKER = () => {
  const opts = [
  ['light_mode', 'Light', 'Always bright', false],
  ['dark_mode', 'Dark', 'Easy on the eyes', false],
  ['brightness_auto', 'System', 'Match your device', true]];

  return (
    <SettingsSheet
      body={<SetBody title="Settings" big gear><HomeBody /></SetBody>}
      panel={
      <SheetPanel title="Appearance">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
            {opts.map(([icon, label, sub, sel]) =>
          <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 16, background: sel ? ACCL : HILITE, border: `1.5px solid ${sel ? ACC : 'transparent'}` }}>
                <Ic n={icon} style={{ fontSize: 21, color: sel ? ACC : TEXT }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 17, fontWeight: 700, color: sel ? ACC : TEXT }}>{label}</div>
                  <div style={{ fontSize: 15, color: MED, marginTop: 1 }}>{sub}</div>
                </div>
                {sel &&
            <Ic n="check_circle:fill" style={{ fontSize: 22, color: ACC }} />}
              </div>
          )}
          </div>
        </SheetPanel>
      } />);


};

// Prism - Focus audio + in-app sounds.
const SOUNDS_SETTING = () =>
<SetScreen title="Prism">
    <GroupLabel>Prism focus audio</GroupLabel>
    <SetGroup style={{ marginBottom: 20 }}>
      <SetRow label="Play Prism in Focus" toggle={true} />
      <SetRow label="Default mode" value="Deep Work" chevron last />
    </SetGroup>
    <GroupLabel>In-app sounds</GroupLabel>
    <SetGroup>
      <SetRow label="All in-app sounds" toggle={true} />
      <SetRow label="Create task" toggle={true} />
      <SetRow label="Complete task" toggle={true} />
      <SetRow label="Task countdown" toggle={true} />
      <SetRow label="Complete a subtask item" toggle={true} last />
    </SetGroup>
  </SetScreen>;

// Text-entry bottom sheet (Edit name / Change email) over the dimmed Profile screen.
const InputSheet = ({ title, value, light }) =>
<SettingsSheet
  body={<SetBody title="Profile"><ProfileBody /></SetBody>}
  panel={
  <SheetPanel title={title}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: BG, borderRadius: 14, padding: '12px 12px 12px 15px' }}>
          <span style={{ flex: 1, fontSize: 17, fontWeight: 600, color: TEXT, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{value}<span style={{ color: ACC, fontWeight: 400 }}>|</span></span>
          <div style={{ width: 34, height: 34, borderRadius: '50%', background: light ? WHITE : INK, boxShadow: light ? SHADOW : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ic n="send" style={{ fontSize: 18, color: light ? TEXT : '#fff' }} />
          </div>
        </div>
      </SheetPanel>
  } />;

const EDIT_NAME_SHEET = () => <InputSheet title="What should we call you?" value="Ridhwan Ahamed" />;
const CHANGE_EMAIL_SHEET = () => <InputSheet title="Change email address" value="f20230375@dubai.bits-pilani.ac.in" light />;
const EDIT_UNI_SHEET = () => <InputSheet title="Your university" value="BITS Dubai" />;
const EDIT_PROGRAM_SHEET = () => <InputSheet title="Your program" value="CS · Undergrad" />;

// Single-line option pill used by the gender / notification-sound sheets.
const OptionRow = ({ label, sel }) =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 50, boxSizing: 'border-box', padding: '0 16px', borderRadius: 100, background: sel ? ACCL : HILITE, border: `1.5px solid ${sel ? ACC : 'transparent'}`, marginBottom: 9 }}>
    <span style={{ fontSize: 17, fontWeight: 700, color: sel ? ACC : TEXT }}>{label}</span>
    {sel && <Ic n="check_circle:fill" style={{ fontSize: 20, color: ACC }} />}
  </div>;

// Gender - option sheet over the dimmed Profile.
const GENDER_SHEET = () =>
<SettingsSheet
  body={<SetBody title="Profile"><ProfileBody /></SetBody>}
  panel={
  <SheetPanel title="Gender">
      {['Female', 'Male', 'Non-binary'].map((g) => <OptionRow key={g} label={g} />)}
      <OptionRow label="Prefer not to say" sel />
    </SheetPanel>
  } />;

// Change password - 3 fields + CTA over the dimmed Profile.
const CHANGE_PASSWORD_SHEET = () =>
<SettingsSheet
  body={<SetBody title="Profile"><ProfileBody /></SetBody>}
  panel={
  <SheetPanel title="Change password">
      {[['Current password', true], ['New password', false], ['Confirm new password', false]].map(([lbl, cursor]) =>
    <div key={lbl} style={{ marginBottom: 13 }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: MED, margin: '0 2px 6px' }}>{lbl}</div>
          <div style={{ background: BG, borderRadius: 14, padding: '12px 15px', fontSize: 17, fontWeight: 600, minHeight: 18 }}>{cursor ? <span style={{ color: ACC }}>|</span> : <span> </span>}</div>
        </div>
    )}
      <div style={{ marginTop: 5, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff', cursor: 'pointer' }}>Update password</div>
    </SheetPanel>
  } />;

// Notification sound - option sheet over the dimmed Notifications screen.
const NOTIF_SOUND_SHEET = () =>
<SettingsSheet
  body={<SetBody title="Notifications"><NotifBody /></SetBody>}
  panel={
  <SheetPanel title="Notification sound">
      <OptionRow label="Chime" sel />
      {['Pulse', 'Glass', 'Drop', 'None'].map((s) => <OptionRow key={s} label={s} />)}
    </SheetPanel>
  } />;

// Delete account - destructive confirm dialog over the dimmed (scrolled) settings.
const DELETE_ACCOUNT_DIALOG = () =>
<Phone>
    <SetBody title="Settings" big gear offset={600}><HomeBody /></SetBody>
    <BNav active={3} />
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.42)' }} />
    <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: 212, background: WHITE, borderRadius: 22, boxShadow: '0 20px 64px rgba(0,0,0,0.34)', padding: '18px 18px 14px' }}>
      <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800, marginBottom: 8 }}>Delete account?</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.5, marginBottom: 16 }}>This permanently removes your profile and data. There is no undo.</div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, margin: '-13px -8px -13px 0', padding: '0 2px 2px' }}>
        <span style={{ height: HEAD_BTN, display: 'flex', alignItems: 'center', padding: '0 6px', fontSize: 17, fontWeight: 700, color: MED, cursor: 'pointer' }}>Cancel</span>
        <span style={{ height: HEAD_BTN, display: 'flex', alignItems: 'center', padding: '0 6px', fontSize: 17, fontWeight: 800, color: '#e85476', cursor: 'pointer' }}>Delete</span>
      </div>
    </div>
  </Phone>;

// Rate Aqademiq - star sheet over the dimmed (scrolled) settings.
const RATE_SHEET = () =>
<SettingsSheet
  body={<SetBody title="Settings" big gear offset={600}><HomeBody /></SetBody>}
  panel={
  <SheetPanel title="Rate Aqademiq">
      <div style={{ fontSize: 17, color: MED, textAlign: 'center', marginBottom: 16 }}>How has Aqademiq been treating you?</div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 14, marginBottom: 20 }}>
        {[0, 1, 2, 3, 4].map((i) => <Ic n="rate" key={i} style={{ fontSize: 30, color: '#c9c5bd' }} />)}
      </div>
      <div style={{ background: HILITE, borderRadius: 100, height: 50, boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#b0aaa2' }}>Submit rating</div>
    </SheetPanel>
  } />;

// New study tag - bottom sheet over the dimmed settings home (reached via "+ New tag").
const ADD_TAG_SHEET = () => {
  const colors = ['#5cbbff', ACC, '#e85476', SUCC, WARN, '#c0497b', '#9aa3b2'];
  const selected = '#e85476';
  const name = 'Tutorial';
  const icon = 'class';
  // Pack palette: tag glyphs sit in the ink step of their hue on light tiles.
  const pal = Object.values(window.AQT.PALETTE).find((p) => p.hue === selected.toLowerCase());
  const ink = IS_DARK ? selected : pal ? pal.ink : selected;
  return (
    <SettingsSheet
      body={<SetBody title="Settings" big gear><HomeBody /></SetBody>}
      panel={
      <SheetPanel title="New study tag">
          {/* live preview chip */}
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 18 }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, background: WHITE, border: `1px solid ${BORDER}`, borderRadius: 100, height: 36, boxSizing: 'border-box', padding: '0 15px', boxShadow: SHADOW }}>
              {icon ? <Ic n={'task_' + icon} style={{ fontSize: 18, color: ink }} /> : <span style={{ width: 9, height: 9, borderRadius: '50%', background: selected }} />}
              <span style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>{name}</span>
            </div>
          </div>
          {/* name input */}
          <div style={{ fontSize: 17, fontWeight: 700, color: MED, margin: '0 2px 7px' }}>Name</div>
          <div style={{ display: 'flex', alignItems: 'center', background: BG, borderRadius: 14, padding: '12px 15px', marginBottom: 18 }}>
            <span style={{ flex: 1, fontSize: 17, fontWeight: 600, color: TEXT }}>{name}<span style={{ color: ACC, fontWeight: 400 }}>|</span></span>
          </div>
          {/* icon picker - No icon (the tag keeps its dot) + the pack's Tier 2 task glyphs; neutral until picked, then in the tag colour */}
          <div style={{ fontSize: 17, fontWeight: 700, color: MED, margin: '0 2px 11px' }}>Icon</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: 8, marginBottom: 18 }}>
            <div role="button" aria-label="No icon" aria-pressed={!icon} style={{ gridColumn: 'span 2', height: 50, borderRadius: 14, background: !icon ? selected + '1f' : BG, boxShadow: !icon ? `inset 0 0 0 2px ${ink}` : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer' }}>
              <span style={{ width: 9, height: 9, borderRadius: '50%', background: !icon ? selected : MED }} />
              <span style={{ fontSize: 15, fontWeight: 600, color: !icon ? ink : TEXT }}>No icon</span>
            </div>
            {window.AQT.TASKS.map((t) => {
            const on = t.name === icon;
            return (
              <div key={t.name} role="button" aria-label={t.label} aria-pressed={on} style={{ height: 50, borderRadius: 14, background: on ? selected + '1f' : BG, boxShadow: on ? `inset 0 0 0 2px ${ink}` : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                  <Ic n={'task_' + t.name} style={{ fontSize: 24, color: on ? ink : TEXT }} />
                </div>);
          })}
          </div>
          {/* colour picker */}
          <div style={{ fontSize: 17, fontWeight: 700, color: MED, margin: '0 2px 11px' }}>Colour</div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 22, padding: '0 2px' }}>
            {colors.map((c) =>
          <div key={c} style={{ width: 32, height: 32, borderRadius: '50%', background: c, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: c === selected ? `0 0 0 2px ${WHITE}, 0 0 0 4px ${c}` : 'none', cursor: 'pointer' }}>
                {c === selected && <Ic n="check" style={{ fontSize: 20, color: '#fff' }} />}
              </div>
          )}
          </div>
          {/* add button */}
          <div style={{ background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff', cursor: 'pointer' }}>Add tag</div>
        </SheetPanel>
      } />);


};

// Email settings - warm intro + grouped toggles.
const EMAIL_SETTINGS = () =>
<SetScreen title="Email settings">
    <div style={{ fontSize: 17, color: TEXT, lineHeight: 1.55, marginBottom: 20, padding: '0 2px' }}>
      We'll only reach out when it's genuinely useful: a new feature, a study tip, or the occasional offer. You're in control, and you can change this anytime.
    </div>
    <SetGroup>
      <SetRow label="Product updates" toggle={true} />
      <SetRow label="Study tips & guides" toggle={true} />
      <SetRow label="Offers & promotions" toggle={false} />
      <SetRow label="Research & surveys" toggle={false} last />
    </SetGroup>
  </SetScreen>;


/* ─── GUEST MODE ──────────────────────────────────────────────────────── */

const GUEST_HOME = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      {/* same compact header language as 02 - Home: tappable day/month left,
        actions right - with the GUEST badge joining the action cluster */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <div style={{ cursor: 'pointer' }}>
          <div style={{ fontFamily: SANS, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.1, fontSize: 17 }}>Monday</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 1, fontSize: 12, fontWeight: 800, color: MED, letterSpacing: '0.04em', marginTop: 1 }}>JUN 2026
            <Ic n="chevron_right" style={{ fontSize: 14 }} />
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <BarPill icon="guest" iconColor={WARN} label="Guest" />
          <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
            <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 800, color: TEXT, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 24 }} /></div>
            <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Ic n="add" style={{ fontSize: 24, color: TEXT }} />
            </div>
          </div>
        </div>
      </div>
      <PlanDateStrip selected={0} today={0} />
      <Card style={{ background: ACCL, boxShadow: 'none', padding: '10px 12px', marginBottom: 10, border: `1px solid ${ACC}22` }}>
        <div style={{ display: 'flex', gap: 9, alignItems: 'center' }}>
          <AdaBlob size={26} mood="happy" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 1 }}>You're exploring as a guest</div>
            <div style={{ fontSize: 13, color: MED, lineHeight: 1.45 }}>Set up so Ada can plan your week &amp; track stats.</div>
          </div>
        </div>
        <div style={{ background: INK, borderRadius: 100, padding: '7px 0', textAlign: 'center', fontSize: 15, fontWeight: 700, color: '#fff', marginTop: 8 }}>Set up now · 2 min →</div>
      </Card>
      <div style={{ marginBottom: 8 }}><CollapseHead label="PLANNED" count={1} open /></div>
      <TimeLabel>2:00 PM</TimeLabel>
      <PlanTask title="Read chapter 4" dur="30m" tag="CC 401" color={ACC} bar />
    </div>
    <BNav active={1} guest />
  </Phone>;


const GUEST_ADA_PROMPT = () =>
<Phone bg={WHITE}>
    <div style={{ height: 742, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 26px 38px' }} data-comment-anchor="c4a9c85a54-div-3353-5">
      <div style={{ position: 'relative' }}>
        <AdaBlob size={88} mood="happy" />
        <div style={{ position: 'absolute', bottom: 2, right: -2, width: 26, height: 26, borderRadius: '50%', background: WARN, border: `3px solid ${WHITE}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Ic n="guest" style={{ fontSize: 16, color: '#fff' }} />
        </div>
      </div>
      <div style={{ ...{ fontFamily: SANS, fontSize: 28, fontWeight: 800, marginTop: 18, marginBottom: 8, lineHeight: 1.25 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Meet Ada</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 18 }}>Ada builds your week from your real workload. To plan for you, it needs to know what you're studying.</div>
      <Card style={{ width: '100%', boxShadow: 'none', background: BG, padding: '10px 14px', marginBottom: 22, textAlign: 'left' }}>
        {['What & where you study', 'Your deadlines & syllabus', 'When you focus best'].map((t, i, a) =>
      <div key={t} style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 9, padding: '6px 0', backgroundImage: i < a.length - 1 ? `linear-gradient(${BORDER}, ${BORDER})` : 'none', backgroundSize: `calc(100% - 28px) 1px`, backgroundPosition: '100% 100%', backgroundRepeat: 'no-repeat' }}>
            <Ic n="check_circle:fill" style={{ fontSize: 19, color: ACC }} />
            <span style={{ fontSize: 15, fontWeight: 600 }}>{t}</span>
          </div>
      )}
      </Card>
      <PBtn style={{ marginBottom: 9 }}>Set up Ada · 2 min →</PBtn>
      <div style={{ fontSize: 15, color: MED, fontWeight: 600, cursor: 'pointer' }}>Maybe later</div>
    </div>
    <BNav active={4} guest />
  </Phone>;


const GUEST_STATS_PROMPT = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, position: 'relative' }}>
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 14 }}>Your stats</div>
      <div style={{ filter: 'blur(3.5px)', opacity: 0.5, pointerEvents: 'none' }}>
        <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
          {[['–', 'DAYS ON BOARD'], ['–', 'SESSIONS']].map(([v, l]) =>
        <Card key={l} style={{ flex: 1, textAlign: 'center', padding: '14px' }}>
              <div style={{ fontFamily: NUMSERIF, fontSize: 34, fontWeight: 800 }}>{v}</div>
              <div style={{ fontSize: 12, fontWeight: 800, color: DIM, letterSpacing: '0.1em' }}>{l}</div>
            </Card>
        )}
        </div>
        <Card style={{ marginBottom: 10, height: 96 }}>
          <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 700, marginBottom: 8 }}>Weekly focus</div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 44 }}>
            {[40, 70, 30, 85, 55, 20, 60].map((h, i) => <div key={i} style={{ flex: 1, height: `${h}%`, background: ACC, opacity: 0.5, borderRadius: 3 }} />)}
          </div>
        </Card>
        <Card style={{ height: 70 }}><div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 700 }}>Mood trends</div></Card>
      </div>
    </div>
    {/* sheet anchored to the phone bottom - white runs flush under the nav */}
    <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, padding: '16px 18px 89px', boxShadow: '0 -8px 40px rgba(0,0,0,0.14)' }}>
      <div style={{ width: 36, height: 4, borderRadius: 2, background: '#e0e0e0', margin: '0 auto 14px' }} />
      <div style={{ marginBottom: 14 }}>
        <div style={{ ...{ fontFamily: SANS, fontSize: 17, fontWeight: 800, marginBottom: 3 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Track your progress</div>
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55 }}>Set up your profile and Ada will track your streaks, focus hours &amp; mood trends, then tune your plan to match.</div>
      </div>
      <PBtn style={{ marginBottom: 8 }}>Set up now · 2 min →</PBtn>
      <div style={{ textAlign: 'center', fontSize: 15, color: MED, fontWeight: 600, cursor: 'pointer' }}>Not now</div>
    </div>
    <BNav active={3} guest />
  </Phone>;


const GUEST_SAVE_PROMPT = () =>
<Phone bg={SESSION_GRAD}>
    {/* the session-complete screen it is raised over, dimmed */}
    <div style={{ opacity: 0.4, pointerEvents: 'none' }}><SessionEndBody bare /></div>
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.22)' }}></div>
    {/* sheet anchored to the phone bottom - white runs flush under the nav */}
    <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, padding: '16px 18px 89px', boxShadow: '0 -8px 40px rgba(0,0,0,0.14)' }}>
      <div style={{ width: 36, height: 4, borderRadius: 2, background: '#e0e0e0', margin: '0 auto 14px' }} />
      <div style={{ marginBottom: 14 }}>
        <div style={{ ...{ fontFamily: SANS, fontSize: 17, fontWeight: 800, marginBottom: 3 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Don't lose this session</div>
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55 }} data-comment-anchor="4eb1cf4e9d-div-2495-13">You're in guest mode, so this won't be saved. Create an account to keep your streak &amp; history.</div>
      </div>
      <PBtn style={{ marginBottom: 8 }}>Create account &amp; save →</PBtn>
      <div style={{ textAlign: 'center', fontSize: 15, color: MED, fontWeight: 600, cursor: 'pointer' }}>Not now</div>
    </div>
    <BNav active={2} guest />
  </Phone>;


// Guest mode - Subjects page. Fresh guest hasn't onboarded, so the list is
// empty; same header language as Guest home (logo + GUEST badge / ··· + pill).
const GUEST_SUBJECTS = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 26, height: 26, objectFit: 'contain' }} />
          <BarPill icon="guest" iconColor={WARN} label="Guest" />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 800, color: TEXT, lineHeight: 1 }}><Ic n="more" style={{ fontSize: 24 }} /></div>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ic n="add" style={{ fontSize: 24, color: TEXT }} />
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 7, marginBottom: 14 }}>
        <span style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.5 }}>Subjects</span>
        <span style={{ fontSize: 17, fontWeight: 700, color: DIM }}>0</span>
      </div>
      {/* empty state */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 18px' }}>
        <div style={{ width: 78, height: 78, borderRadius: '50%', background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 16 }}>
          <AdaBlob size={48} mood="happy" />
        </div>
        <div style={{ ...{ fontFamily: SANS, fontSize: 22, fontWeight: 800, marginBottom: 6 }, fontFamily: "\"Plus Jakarta Sans\"", fontWeight: "700" }}>No subjects yet</div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.55, marginBottom: 18 }}>Add the classes you're taking and I'll keep your materials, deadlines and grades in one place.</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: '0 22px', color: '#fff', fontSize: 17, fontWeight: 800, whiteSpace: 'nowrap' }}>
          <Ic n="add" style={{ fontSize: 21 }} />Add your first subject
        </div>
      </div>
      {/* guest setup nudge - consistent with Guest home */}
      <Card style={{ background: ACCL, boxShadow: 'none', padding: '11px 12px', marginBottom: 12, border: `1px solid ${ACC}22` }}>
        <div style={{ display: 'flex', gap: 9, alignItems: 'center' }}>
          <AdaBlob size={28} mood="focused" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 1 }}>You're exploring as a guest</div>
            <div style={{ fontSize: 13, color: MED, lineHeight: 1.45 }}>Set up so I can plan your week &amp; track grades.</div>
          </div>
        </div>
      </Card>
    </div>
    <BNav active={0} guest />
  </Phone>;


/* ─── REFERRAL SHEET ──────────────────────────────────────────────────── */

const REFERRAL = () =>
<Phone>
    {/* dimmed profile behind */}
    <div style={{ position: 'absolute', top: 58, left: 0, right: 0, bottom: 0, padding: '0 16px 110px', opacity: 0.32, pointerEvents: 'none', overflow: 'hidden', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div style={{ flexShrink: 0 }}><ProfilePageBody /></div>
    </div>
    {/* scrim */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.28)' }} />
    {/* sheet */}
    <div style={{ position: 'absolute', left: 8, right: 8, bottom: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -10px 44px rgba(0,0,0,0.22)', padding: '10px 18px 40px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 16px', flexShrink: 0 }} />
      <div style={{ display: 'flex', flexDirection: 'column' }}>
      {/* gift card hero */}
      <div style={{ position: 'relative', borderRadius: 20, overflow: 'hidden', background: `linear-gradient(135deg, ${ACC} 0%, #b39df5 52%, #e9c8d8 100%)`, padding: '17px 18px', textAlign: 'center', marginBottom: 13, boxShadow: `0 8px 24px ${ACC}3a` }}>
        <div style={{ position: 'absolute', inset: 0, borderRadius: 20, boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.4)', pointerEvents: 'none' }} />
        <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 54, height: 54, objectFit: 'contain', filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.18))' }} />
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, color: '#fff', letterSpacing: -0.5, marginTop: 2, fontFamily: '"Plus Jakarta Sans"' }}>Aqademiq</div>
        <div style={{ fontSize: 15, fontWeight: 700, color: 'rgba(255,255,255,0.92)', marginTop: 4 }}>Invite by Ridhwan Ahamed</div>
      </div>
      {/* offer copy */}
      <div style={{ ...{ fontFamily: SANS, fontSize: 22, fontWeight: 800, textAlign: 'center', lineHeight: 1.2, marginBottom: 6 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Help us grow!</div>
      <div style={{ color: MED, textAlign: 'center', lineHeight: 1.5, marginBottom: 14, padding: '0 6px', fontSize: "13px" }}>Share your code with friends and help us reach more students. It means the world to us 💜.</div>
      {/* referral code */}
      <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: DIM, textAlign: 'center', marginBottom: 9 }}>Your referral code</div>
      <div style={{ display: 'flex', gap: 5, justifyContent: 'center', marginBottom: 15 }}>
        {REF_CODE.split('').map((c, i) =>
        <div key={i} style={{ width: 34, height: 44, marginLeft: i === 4 ? 7 : 0, borderRadius: 10, background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: MONO, fontSize: 24, fontWeight: 800, color: TEXT, boxShadow: `inset 0 0 0 1px ${BORDER}` }}>{c}</div>
        )}
      </div>
      {/* share button */}
      <div style={{ width: '100%', height: 50, boxSizing: 'border-box', padding: '0 16px', borderRadius: 100, background: `linear-gradient(120deg, ${ACC}, #9f8bef)`, color: '#fff', fontSize: 17, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, boxShadow: `0 6px 20px ${ACC}40`, cursor: 'pointer' }}>
        <Ic n="share" style={{ fontSize: 18 }} /> Share Invite
      </div>
      </div>
    </div>
  </Phone>;


/* ─── TASKS SHARE / REFERRAL ──────────────────────────────────────────── */

const TASK_SHARE = () =>
<Phone>
    {/* dimmed Subjects page behind - the sheet is raised from its Share pill */}
    <div style={{ opacity: 0.3, pointerEvents: 'none' }}><SubjectsListBody /></div>
    {/* scrim */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.28)' }} />
    {/* sheet */}
    <div style={{ position: 'absolute', left: 8, right: 8, bottom: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -10px 44px rgba(0,0,0,0.22)', padding: '10px 18px 40px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 16px', flexShrink: 0 }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div style={{ position: 'relative', borderRadius: 20, overflow: 'hidden', background: `linear-gradient(135deg, ${ACC} 0%, #b39df5 52%, #e9c8d8 100%)`, padding: '17px 18px', textAlign: 'center', marginBottom: 13, boxShadow: `0 8px 24px ${ACC}3a` }}>
          <div style={{ position: 'absolute', inset: 0, borderRadius: 20, boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.4)', pointerEvents: 'none' }} />
          <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 54, height: 54, objectFit: 'contain', filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.18))' }} />
          <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 28, fontWeight: 800, color: '#fff', letterSpacing: -0.5, marginTop: 2 }}>Aqademiq</div>
          <div style={{ fontSize: 15, fontWeight: 700, color: 'rgba(255,255,255,0.92)', marginTop: 4 }}>Invite by Ridhwan Ahamed</div>
        </div>
        <div style={{ ...{ fontFamily: SANS, fontSize: 22, fontWeight: 800, textAlign: 'center', lineHeight: 1.2, marginBottom: 6 }, fontFamily: "\"Plus Jakarta Sans\"" }}>Help us grow!</div>
        <div style={{ color: MED, textAlign: 'center', lineHeight: 1.5, marginBottom: 14, padding: '0 6px', fontSize: "13px" }}>Share your code with friends and help us reach more students. It means the world to us 💜.</div>
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: DIM, textAlign: 'center', marginBottom: 9 }}>Your referral code</div>
        <div style={{ display: 'flex', gap: 5, justifyContent: 'center', marginBottom: 15 }}>
          {REF_CODE.split('').map((c, i) =>
        <div key={i} style={{ width: 34, height: 44, marginLeft: i === 4 ? 7 : 0, borderRadius: 10, background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: MONO, fontSize: 24, fontWeight: 800, color: TEXT, boxShadow: `inset 0 0 0 1px ${BORDER}` }}>{c}</div>
        )}
        </div>
        <div style={{ width: '100%', height: 50, boxSizing: 'border-box', padding: '0 16px', borderRadius: 100, background: `linear-gradient(120deg, ${ACC}, #9f8bef)`, color: '#fff', fontSize: 17, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, boxShadow: `0 6px 20px ${ACC}40`, cursor: 'pointer' }}>
          <Ic n="share" style={{ fontSize: 18 }} /> Share Invite
        </div>
      </div>
    </div>
  </Phone>;


/* ─── 14 ICE BREAKERS - the tutorial shelf ──────────────────────────────
   Per "Aqademiq · Tutorial Curriculum - Ice Breakers". Sixty short screen
   recordings, four tiers, surfaced contextually. Rules taken from the doc:
     · the empty planner keeps "New task" primary - the video is a SECOND door,
       never a replacement (doc §CTA)
     · the profile card shows THREE rows, never more; runtime on every row;
       watched items collapse so the card height is stable (doc §card)
     · progress counts only the tiers the student has UNLOCKED - S+A = 16 here,
       so the number never looks hopeless (doc §card)
     · guests see the card in full - it is the one card that must not be locked
     · no autoplay, no badge, no red dot. A shelf, not a notification.
     · tier colour runs down the shipped ice ramp (S = frozen, C = puddle), so
       it reuses CUBE_TONES rather than introducing colour
     · naming avoids "melt"/"thaw" - those name the failure end of the ramp. */

const IB_TIERS = { S: CUBE_TONES[4], A: CUBE_TONES[3], B: CUBE_TONES[2], C: CUBE_TONES[0] };

// SHIPPED INVENTORY - the six recordings that exist today. All six are the
// first session (S tier), numbered in the order they are meant to be watched;
// nothing from the later tiers is shot, so nothing later is offered anywhere.
const IB_SPINE = { n: '01', t: 'Add One Small Thing', hook: 'The empty planner is the moment you close the tab.', len: '25s', where: 'Plan' };
const IB_S = [
{ n: '02', t: 'Too Big? Break It Down', len: '45s', where: 'Task' },
{ n: '03', t: 'Five Minutes, Not Twenty-Five', len: '40s', where: 'Focus' },
{ n: '04', t: "Freeze, Don't Quit", len: '25s', where: 'Focus' },
{ n: '05', t: 'Push It To Tomorrow', len: '20s', where: 'Plan · reschedule' },
{ n: '06', t: 'Start A Session From A Task', len: '40s', where: 'Plan → Focus' }];

// The first session as six list rows (guests get the whole tier as a list).
const IB_S_ALL = [{ n: '01', t: 'Add One Small Thing', len: '25s', where: 'Plan' }, ...IB_S];

// The next three unwatched, once the first half of the session is behind you.
const IB_NEXT3 = IB_S.slice(2);


// Every recording is a phone screen capture, shot on iPhone 17 (1206×2622 →
// 1:2.174), so a poster is a PORTRAIT frame at that ratio - never a landscape
// band. Height drives width so the shape stays honest at any size.
const PHONE_SHOT_RATIO = 2622 / 1206;
const IBPhoneShot = ({ h = 228, cube = 40, play = 38, radius = 18, playing = false }) => {
  const w = Math.round(h / PHONE_SHOT_RATIO);
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div style={{ position: 'relative', width: w, height: h, borderRadius: radius, background: ACCL, boxShadow: `inset 0 0 0 1.5px ${ACC}26`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, overflow: 'hidden' }}>
        <CubeSVG size={cube} tone={CUBE_TONES[4]} melt={0} expr="happy" bubbles={2} />
        {!playing && <div style={{ position: 'absolute', width: play, height: play, borderRadius: '50%', background: 'rgba(255,255,255,0.92)', boxShadow: '0 4px 16px rgba(0,0,0,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Ic n="play" style={{ fontSize: play * 0.6, color: INK, marginLeft: 2 }} />
        </div>}
      </div>
    </div>);

};

// Still poster frame - no autoplay anywhere in the section, so every video
// rests on a frozen frame with a play affordance and its runtime.
const IBPoster = ({ h = 84, len, cube = 34, radius = 13 }) =>
<div style={{ position: 'relative', height: h, borderRadius: radius, background: ACCL, overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
    <CubeSVG size={cube} tone={CUBE_TONES[4]} melt={0} expr="happy" bubbles={2} />
    <div style={{ position: 'absolute', bottom: 7, left: 8, display: 'flex', alignItems: 'center', gap: 5, background: 'rgba(17,17,17,0.82)', borderRadius: 100, padding: '3px 8px 3px 6px' }}>
      <Ic n="play" style={{ fontSize: 11, color: '#fff' }} />
      <span style={{ fontSize: 9, fontWeight: 800, color: '#fff', letterSpacing: '0.04em' }}>{len}</span>
    </div>
  </div>;


// One list row. Runtime is always present - the doc's point that "45s" does
// more to get a click than any thumbnail.
const IBRow = ({ v, tier = 'S', last, watched, dim, tight }) =>
<div style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 10, padding: tight ? '7px 0' : '9px 0', backgroundImage: last ? 'none' : `linear-gradient(${BORDER}, ${BORDER})`, backgroundSize: `calc(100% - 32px) 1px`, backgroundPosition: '100% 100%', backgroundRepeat: 'no-repeat', opacity: dim ? 0.45 : 1 }}>
    <div style={{ width: 22, height: 22, borderRadius: '50%', background: watched ? HILITE : IB_TIERS[tier].body, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <Ic n={watched ? 'check' : 'play_arrow'} style={{ fontSize: 16, color: watched ? MED : IB_TIERS[tier].ink }} />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 15, fontWeight: 800, lineHeight: 1.25, color: watched ? MED : TEXT, textDecoration: watched ? 'line-through' : 'none' }}>{v.t}</div>
      <div style={{ fontSize: 12, fontWeight: 700, color: DIM, letterSpacing: '0.04em', marginTop: 2 }}>{v.n} · {v.where}</div>
    </div>
    <span style={{ fontSize: 13, fontWeight: 800, color: watched ? DIM : MED, flexShrink: 0 }}>{v.len}</span>
  </div>;


// Progress, exactly as specced: one track, accent fill, count on the left and
// the percentage right-aligned. Denominator = unlocked tiers only.
const IBProgress = ({ done = 7, total = 16 }) => {
  const pct = Math.round(done / total * 100);
  return (
    <div>
      <div style={{ height: 5, background: BG, borderRadius: 3, overflow: 'hidden', marginBottom: 6 }}>
        <div style={{ width: `${pct}%`, height: '100%', background: ACC, borderRadius: 3 }} />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 12, fontWeight: 700, color: MED, whiteSpace: 'nowrap' }}>{done} of {total} watched</span>
        <span style={{ fontSize: 12, fontWeight: 800, color: ACC, whiteSpace: 'nowrap' }}>{pct}%</span>
      </div>
    </div>);

};

// The collapsed watched pile - keeps the card's height stable forever.
const IBWatchedDisclosure = ({ count = 7, style }) =>
<div style={{ minHeight: 52, boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 8, padding: '9px 0', borderTop: `1px solid ${BORDER}`, ...style }}>
    <Ic n="chevron_down" style={{ fontSize: 20, color: DIM }} />
    <span style={{ flex: 1, fontSize: 13, fontWeight: 700, color: MED }}>Watched ({count})</span>
  </div>;


// The shelf card itself - a sibling of the other profile cards, permanent and
// never dismissible. `stage` names the tier the next three rows come from.
const IBCard = ({ rows = IB_NEXT3, tier = 'S', stage = null, done = 3, total = 6, style }) =>
<Card style={{ padding: '13px 15px 12px', ...style }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: stage ? 2 : 9 }}>
      <span style={{ width: 7, height: 7, borderRadius: '50%', background: IB_TIERS[tier].border, flexShrink: 0 }} />
      <span style={{ flex: 1, fontFamily: SANS, fontSize: 17, fontWeight: 800 }}>Ice Breakers</span>
      <span style={{ fontSize: 13, fontWeight: 700, color: ACC, display: 'inline-flex', alignItems: 'center', gap: 1 }}>See all<Ic n="chevron_right" style={{ fontSize: 15 }} /></span>
    </div>
    {stage && <div style={{ fontSize: 13, color: MED, marginBottom: 9 }}>{stage}</div>}
    {rows.slice(0, 3).map((v, i, a) => <IBRow key={v.n} v={v} tier={tier} last={i === a.length - 1} />)}
    <div style={{ marginTop: 9, paddingTop: 10, borderTop: `1px solid ${BORDER}` }}><IBProgress done={done} total={total} /></div>
  </Card>;


// Small page head for the pushed section pages.
const IBHead = ({ title = 'Ice Breakers', sub }) =>
<div style={{ marginBottom: 10 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: sub ? 9 : 0 }}>
      <BackBtn />
      <span style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800 }}>{title}</span>
    </div>
    {sub && <div style={{ fontSize: 13, color: MED, lineHeight: 1.45, padding: '0 2px' }}>{sub}</div>}
  </div>;


/* Frame 1 - the empty planner. The whole reason the section exists: the doc's
   recommended copy, task creation still primary, watching as the second door. */
const IB_EMPTY_PLAN = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <PlanHeader />
      <PlanDateStrip />
      <div style={{ marginBottom: 6 }}><CollapseHead icon="schedule" label="ANYTIME" count={0} open /></div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 2px', marginBottom: 14 }}>
        <span style={{ fontSize: 17, color: DIM }}>Add a task for anytime</span>
        <Ic n="add" style={{ fontSize: 21, color: DIM }} />
      </div>
      <div style={{ marginBottom: 6 }}><CollapseHead label="PLANNED" count={0} open /></div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 2px' }}>
        <span style={{ fontSize: 17, color: DIM }}>Add a planned task</span>
        <Ic n="add" style={{ fontSize: 21, color: DIM }} />
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 8px' }}>
        <CubeSVG size={50} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
        <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800, letterSpacing: -0.3, marginTop: 10 }}>Nothing planned yet</div>
      </div>
      <div style={{ flexShrink: 0 }}>
        <PBtn ghost style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, fontSize: 17 }}>
          <Ic n="ice_breakers" style={{ fontSize: 21, color: ACC }} />Show me how<Ic n="chevron_right" style={{ fontSize: 19, color: DIM }} />
        </PBtn>
      </div>
      <div style={{ height: 74, flexShrink: 0 }} />
    </div>
    <BNav active={1} />
  </Phone>;


/* Frame 2 - the shelf card in place on Profile: a sibling of the links card,
   directly above the invite hero, permanent. */
const IB_PROFILE_CARD = () =>
<Phone>
    <div style={{ padding: '0 16px 8px', height: 742, overflow: 'hidden' }}>
      <ProfileTopHead />
      <IBCard />
      <div style={{ height: 10 }} />
      <div style={{ position: 'relative', borderRadius: 20, overflow: 'hidden', background: `linear-gradient(135deg, ${ACC} 0%, #b39df5 52%, #e9c8d8 100%)`, padding: '10px 16px', textAlign: 'center', boxShadow: `0 8px 24px ${ACC}3a` }}>
        <img src={window.__resources && window.__resources.logo || "assets/aqademiq-logo-opt.png"} alt="Aqademiq" style={{ width: 32, height: 32, objectFit: 'contain', filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.18))' }} />
        <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800, color: '#fff', letterSpacing: -0.4, marginTop: 1 }}>Aqademiq</div>
      </div>
    </div>
    <BNav active={3} />
  </Phone>;


/* Frame 3 - Day 0. S tier only, in order, with the spine queued at the top.
   Six items is a curriculum; sixty is homework, so nothing else is visible. */
const IB_SECTION_S = () =>
<Phone>
    <div style={{ padding: '0 16px 24px', height: 792, overflow: 'hidden' }}>
      <IBHead />
      <Card style={{ padding: 11, marginBottom: 9, display: 'flex', gap: 11, alignItems: 'center' }}>
        <div style={{ position: 'relative', width: 44, height: 64, borderRadius: 11, background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <CubeSVG size={26} tone={CUBE_TONES[4]} melt={0} expr="happy" bubbles={2} />
          <div style={{ position: 'absolute', bottom: 4, right: 4, width: 16, height: 16, borderRadius: '50%', background: 'rgba(17,17,17,0.82)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ic n="play" style={{ fontSize: 14, color: '#fff', marginLeft: 1 }} />
          </div>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <span style={{ background: INK, color: '#fff', fontSize: 11, fontWeight: 800, letterSpacing: '0.08em', borderRadius: 100, padding: '3px 7px' }}>START HERE</span>
            <span style={{ fontSize: 12, fontWeight: 800, color: DIM, letterSpacing: '0.04em' }}>{IB_SPINE.n} · {IB_SPINE.len}</span>
          </div>
          <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: -0.2, lineHeight: 1.2, marginBottom: 3 }}>{IB_SPINE.t}</div>
          <div style={{ fontSize: 13, color: MED, lineHeight: 1.4 }}>{IB_SPINE.hook}</div>
        </div>
      </Card>
      <Card style={{ padding: '5px 14px' }}>
        {IB_S.map((v, i, a) => <IBRow key={v.n} v={v} last={i === a.length - 1} tight />)}
      </Card>
    </div>
  </Phone>;


/* Frame 4 - a video open, laid out as the live app: one card holding the
   meta, the title, the capture at the device's exact 1206×2622 ratio, a
   scrubber and the hook line. Opening it is the tap; it plays from there. */
const IB_PLAYER = () =>
<Phone>
    <div style={{ padding: '8px 16px 0', height: 792, overflow: 'hidden' }}>
      <IBHead />
      <Card style={{ padding: '16px 15px 13px', marginTop: 2 }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: DIM, lineHeight: 1.35 }}>{IB_SPINE.n} · {IB_SPINE.where}</div>
        <div style={{ fontSize: 20, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.3, marginBottom: 8 }}>{IB_SPINE.t}</div>
        <IBPhoneShot h={552} cube={64} radius={30} playing />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '7px 0 8px' }}>
          <div style={{ width: 30, height: 30, borderRadius: '50%', background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ic n="pause" style={{ fontSize: 21, color: ACC }} />
          </div>
          <div style={{ flex: 1, height: 4, borderRadius: 2, background: ACCL, overflow: 'hidden' }}><div style={{ width: '5%', height: '100%', background: ACC }}></div></div>
          <span style={{ fontFamily: NUMSERIF, fontSize: 17, fontWeight: 700, color: MED, whiteSpace: 'nowrap' }}>0:01 / {IB_SPINE.len.replace('s', '').padStart(2, '0').replace(/^/, '0:')}</span>
        </div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.45 }}>The empty planner is the exact moment you close the tab. One task, and the white space breaks.</div>
      </Card>
    </div>
  </Phone>;


/* Frame 5 - the first session is done. The only moment the section draws
   attention to itself is this subtitle swap; the watched pile collapses. */
const IB_WATCHED = () =>
<Phone>
    <div style={{ padding: '0 16px 24px', height: 792, overflow: 'hidden' }}>
      <IBHead />
      <Card style={{ padding: '12px 14px', marginBottom: 10, display: 'flex', gap: 10, alignItems: 'center' }}>
        <CubeSVG size={34} tone={CUBE_TONES[4]} melt={0} expr="happy" bubbles={2} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 2 }}>One left in the first session</div>
          <div style={{ fontSize: 13, color: MED, lineHeight: 1.45 }}>Then that's all of them, for now.</div>
        </div>
      </Card>
      <Card style={{ padding: '6px 14px 12px', marginBottom: 10 }}>
        <IBRow v={IB_S[4]} last />
        <IBWatchedDisclosure count={5} style={{ marginTop: 2 }} />
        <div style={{ marginTop: 8 }}><IBProgress done={5} total={6} /></div>
      </Card>
      <div style={{ textAlign: 'center', fontSize: 13, fontWeight: 700, color: DIM }}>More coming soon</div>
    </div>
  </Phone>;


/* Frame 6 - guest. Stats stay locked; the shelf does not. The guest is
   precisely who needs it, so it renders in full, at full contrast. */
const IB_GUEST_CARD = () =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
        <BarPill label="Guest" style={{ gap: 7 }}><span style={{ background: WARN, color: '#fff', fontSize: 11, fontWeight: 800, letterSpacing: '0.08em', borderRadius: 100, padding: '2px 6px' }}>GUEST</span></BarPill>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, background: WHITE, borderRadius: 100, padding: '4px 6px', boxShadow: SHADOW }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ic n="settings" style={{ fontSize: 19, color: TEXT }} />
          </div>
        </div>
      </div>
      <Card style={{ position: 'relative', padding: 0, overflow: 'hidden', marginBottom: 8 }}>
        <div style={{ display: 'flex', filter: 'blur(3.5px)', opacity: 0.45, pointerEvents: 'none' }}>
          {[['–', 'DAYS ON THE BOARD'], ['–', 'TASKS DONE']].map(([v, l], i) =>
        <div key={l} style={{ flex: 1, padding: '14px', borderLeft: i ? `1px solid ${BORDER}` : 'none' }}>
              <div style={{ fontFamily: NUMSERIF, fontSize: 34, fontWeight: 800, lineHeight: 1 }}>{v}</div>
              <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.1em', color: DIM, marginTop: 5 }}>{l}</div>
            </div>
        )}
        </div>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, background: WHITE, borderRadius: 100, padding: '6px 12px', boxShadow: SHADOW }}>
            <Ic n="guest" style={{ fontSize: 18, color: WARN }} />
            <span style={{ fontSize: 13, fontWeight: 800 }}>Set up to track this</span>
          </div>
        </div>
      </Card>
      <IBCard rows={IB_S_ALL} tier="S" stage={null} done={0} total={6} />
    </div>
    <BNav active={3} guest />
  </Phone>;


/* ─── 15 ON ICE / RULES ───────────────────────────────────────────────────
   From "On Ice" (session-bound app freezing) + "Today's Frost" (the rules
   layer). The copy doctrine from those documents is enforced here, not
   paraphrased:
     · the word "blocked" never appears - apps go ON ICE, and ice melts
     · Freeze always means the session timer; on ice always means apps.
       The two never cross, which is why the exam rule is not "Deep freeze"
     · shield prose DECAYS toward plainness instead of escalating wit
     · Thaw and Not-today render IDENTICALLY in all three shield stages -
       the fourth thaw costs exactly what the first did
     · no counts, streaks, history or second-person accusation on the shield
     · arm counts, decline counts and compliance may exist internally and
       never reach a screen
     · no new notifications: the morning arm is an in-app card on Plan, and
       silence resolves to no
     · every platform limit is disclosed in the product, never discovered
       in a review */

const FROST_BG = `linear-gradient(170deg, #f8f6ff 0%, #ebe5fc 52%, #ddd4f8 100%)`;
const FROST_INK = '#1a1320';
const FROST_SUB = '#584f70'; // solid, not alpha - keeps 6:1 on the frost ground
const SYSFONT = '-apple-system, "SF Pro Text", "Helvetica Neue", sans-serif';
// The floor. Stated in the picker intro, and enforced if the all-except
// shield policy holds. A 12-hour frost that can hold messaging is a person
// unreachable for a working day because they tapped a preset on Sunday.
const ICE_FLOOR = ['Phone', 'Messages', 'Maps', 'Wallet', 'Camera', 'Clock', 'Settings', 'Health'];

// Day circles. Never labelled "weekend" anywhere - plenty of students work
// Saturdays and rest on Tuesday, so every Frost carries its own picker.
const FrostDays = ({ on = [1, 2, 3, 4, 5], size = 22, edit }) =>
<div style={{ display: 'flex', gap: 5 }}>
    {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => {
    const active = on.includes(i + 1);
    return <div key={i} style={{ width: size, height: size, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: Math.round(size * 0.45), fontWeight: 800, background: active ? ACC : HILITE, color: active ? '#fff' : MED, border: edit && !active ? `1.5px dashed ${DIM}` : 'none', boxSizing: 'border-box', cursor: 'pointer' }}>{d}</div>;
  })}
  </div>;


const IceChip = ({ icon = 'ac_unit', children, tone, ink, sm }) =>
<span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: tone || HILITE, borderRadius: 100, padding: sm ? '3px 9px' : '4px 10px', fontSize: sm ? 12 : 13, fontWeight: 700, color: ink || TEXT }}>
    {icon && <Ic n={icon} style={{ fontSize: sm ? 14 : 15, color: ink || ACC }} />}{children}
  </span>;


// A claim row - icon, bold clause, plain consequence. Used by the intro and
// both permission pre-prompts so the three read as one voice.
const IceClaim = ({ icon, title, body, tone }) =>
<div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
    <Ic n={icon} style={{ fontSize: 21, color: tone || ACC, flexShrink: 0, marginTop: 1 }} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 17, fontWeight: 800, color: TEXT, lineHeight: 1.3 }}>{title}</div>
      <div style={{ fontSize: 13, color: MED, lineHeight: 1.5, marginTop: 2 }}>{body}</div>
    </div>
  </div>;


/* ── Permissions and first run ─────────────────────────────────────────── */

/* ice-intro - what On Ice is, in the app's own words, before any system
   prompt. Nothing has been asked for yet, so nothing is at stake. */
const ICE_INTRO = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 20px' }}>
      <BackBtn style={{ marginBottom: 10 }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 14 }}>
          <CubeSVG size={72} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={3} />
        </div>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.4, lineHeight: 1.15, textAlign: 'center', marginBottom: 7 }}>Apps on ice</div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.55, textAlign: 'center', textWrap: 'pretty', marginBottom: 20 }}>Frozen, not forbidden. The apps you pick freeze when a focus session starts, and thaw when it ends.</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 13 }}>
          <IceClaim icon="ac_unit" title="Only inside a session" body="Nothing freezes outside one. There are no schedules to set." />
          <IceClaim icon="thaw" title="Ten seconds to thaw" body="The way out is always there, and it never gets more expensive." />
          <IceClaim icon="visibility_off" title="We never learn your picks" body="iOS hands us tokens, not names. Nothing to sync, nothing to leak." />
        </div>
      </div>
      <PBtn style={{ marginBottom: 10 }}>Set it up</PBtn>
      <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 600, color: MED, cursor: 'pointer' }}>Not now</div>
    </div>
  </Phone>;


/* ice-perm-ios - the pre-prompt. Says what the OS sheet will ask and what we
   can and cannot do with it, so the system dialog is never a surprise. */
const ICE_PERM_IOS = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 16px' }}>
      <BackBtn style={{ marginBottom: 12 }} />
      <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.2, marginBottom: 6 }}>Screen Time does<br />the freezing</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.5, marginBottom: 12 }}>iOS asks once. Aqademiq hands the apps to Screen Time and gets tokens back, never names.</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 12 }}>
        <IceClaim icon="check_circle_outline" title="What it can do" body="Hold your apps while a session runs, then let them go." tone={SUCC} />
        <IceClaim icon="hidden" title="What it can't do" body="Read your picks, log them, or sync them anywhere." tone={MED} />
        <IceClaim icon="schedule" title="What clears it" body="Your end time is registered with iOS, so it thaws even if the app dies." />
      </div>
      <Card style={{ display: 'flex', gap: 9, alignItems: 'flex-start', background: ACCL, boxShadow: 'none', padding: '9px 11px' }}>
        <AdaBlob size={22} mood="happy" />
        <span style={{ fontSize: 13, color: TEXT, lineHeight: 1.5 }}>Aqademiq is 18+, so this permission is yours to give. No family approval needed.</span>
      </Card>
      <div style={{ flex: 1 }} />
      <PBtn style={{ marginBottom: 9 }}>Continue</PBtn>
      <div style={{ textAlign: 'center', fontSize: 13, color: DIM }}>iOS will ask on the next screen</div>
    </div>
  </Phone>;


/* ice-perm-android - two special-access grants, neither of which is a normal
   permission dialog. The asymmetry with iOS is disclosed, not hidden. */
const ICE_PERM_ANDROID = () => {
  const grants = [
  ['Usage access', 'So Aqademiq knows which app is in front.', true],
  ['Draw over other apps', 'So the frost can appear on top.', false]];

  return (
    <Phone bg={WHITE}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 16px' }}>
        <BackBtn style={{ marginBottom: 6 }} />
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.15, marginBottom: 9 }}>Two permissions,<br />then you're set</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 8 }}>
          {grants.map(([t, s, done], i) =>
          <div key={t} style={{ display: 'flex', gap: 11, alignItems: 'center', background: done ? ACCL : BG, border: `1.5px solid ${done ? ACC + '55' : 'transparent'}`, borderRadius: 16, padding: '8px 11px' }}>
              <div style={{ width: 24, height: 24, borderRadius: '50%', background: done ? ACC : WHITE, boxShadow: done ? 'none' : SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 15, fontWeight: 800, color: done ? '#fff' : TEXT }}>
                {done ? <Ic n="check" style={{ fontSize: 19 }} /> : i + 1}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: 800 }}>{t}</div>
                <div style={{ fontSize: 13, color: MED, lineHeight: 1.45, marginTop: 1 }}>{s}</div>
              </div>
              {!done && <span style={{ fontSize: 13, fontWeight: 800, color: ACC, flexShrink: 0 }}>Grant</span>}
            </div>
          )}
        </div>
        {/* The honest bit, kept to one clause each - the full reliability
            statement lives in Settings → App freeze, where it can breathe. */}
        <Card style={{ padding: '8px 10px', display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
            <Ic n="info" style={{ fontSize: 18, color: WARN, flexShrink: 0, marginTop: 1 }} />
            <span style={{ flex: 1, fontSize: 12, color: TEXT, lineHeight: 1.45 }}>No official freeze API here, so it's less reliable than iOS. We'll say so if it stops.</span>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
            <Ic n="shield" style={{ fontSize: 18, color: SUCC, flexShrink: 0, marginTop: 1 }} />
            <span style={{ flex: 1, fontSize: 12, color: TEXT, lineHeight: 1.45 }}>No accessibility services. The faster route reads your whole screen.</span>
          </div>
        </Card>
        <div style={{ flex: 1 }} />
        <PBtn>Open system settings</PBtn>
      </div>
    </Phone>);

};

/* ice-perm-denied - declined. One short statement, one way back in, and an
   explicit promise not to ask again. Re-entry without nagging is the whole
   point of this frame. */
const ICE_PERM_DENIED = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 20px' }}>
      <BackBtn style={{ marginBottom: 10 }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <CubeSVG size={58} tone={CUBE_TONES[1]} melt={0.25} expr="happy" bubbles={1} />
        <div style={{ fontFamily: SANS, fontSize: 22, fontWeight: 800, letterSpacing: -0.3, marginTop: 14, marginBottom: 7 }}>On ice is off</div>
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, textWrap: 'pretty' }}>Screen Time access wasn't granted, so nothing freezes. Every other part of Aqademiq works exactly as it did.</div>
        <div style={{ marginTop: 14 }}><IceChip icon="notifications_off" tone={HILITE}>We won't ask again</IceChip></div>
      </div>
      <PBtn ghost style={{ marginBottom: 9, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, fontSize: 17 }}>
        <Ic n="freeze" style={{ fontSize: 20, color: ACC }} />Turn it on
      </PBtn>
      <div style={{ textAlign: 'center', fontSize: 13, color: DIM, lineHeight: 1.5 }}>It lives in Settings → App freeze whenever you want it.</div>
    </div>
  </Phone>;


/* ── The core mechanism ────────────────────────────────────────────────── */

/* ice-picker-intro - our words above Apple's picker. The privacy claim is
   said at the exact moment someone is wondering whether their study app is
   about to judge their habits. */
const ICE_PICKER_INTRO = () => {
  const rows = [['Social', '4 apps'], ['Games', '1 category'], ['Entertainment', '–'], ['Shopping', '–']];
  return (
    <Phone bg={PAGE}>
      <div style={{ height: 816, position: 'relative' }}>
        <div style={{ padding: '2px 16px 0' }}>
          <div style={{ fontFamily: SANS, fontSize: 19, fontWeight: 800, letterSpacing: -0.3, marginBottom: 5 }}>Pick what goes on ice.</div>
          <div style={{ fontSize: 11.5, color: MED, lineHeight: 1.55, marginBottom: 10, textWrap: 'pretty' }}>Aqademiq can't see what you choose. iOS keeps that to itself.</div>
          <Card style={{ padding: '10px 12px', background: ACCL, boxShadow: 'none' }}>
            <div style={{ fontSize: 9, fontWeight: 800, letterSpacing: '0.09em', color: ACC, marginBottom: 6 }}>NEVER ON ICE</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
              {ICE_FLOOR.map((a) => <span key={a} style={{ background: WHITE, borderRadius: 100, padding: '3px 8px', fontSize: 9.5, fontWeight: 700, color: TEXT }}>{a}</span>)}
            </div>
          </Card>
        </div>
        {/* Apple's sheet, in Apple's chrome - deliberately not our design */}
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: '#f2f2f7', borderRadius: '12px 12px 0 0', paddingBottom: 24, boxShadow: '0 -8px 40px rgba(0,0,0,0.20)', fontFamily: SYSFONT, overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 14px 10px', borderBottom: '0.5px solid #c6c6c8', background: '#f9f9f9' }}>
            <span style={{ fontSize: 12, color: '#007aff' }}>Cancel</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: '#000' }}>Apps &amp; Categories</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: '#007aff' }}>Done</span>
          </div>
          <div style={{ padding: '8px 12px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, background: '#e3e3e8', borderRadius: 9, padding: '6px 9px' }}>
              <span className="material-icons-outlined" style={{ fontSize: 14, color: '#8e8e93' }}>search</span>
              <span style={{ fontSize: 11.5, color: '#8e8e93' }}>Search</span>
            </div>
          </div>
          <div style={{ background: '#fff', borderTop: '0.5px solid #c6c6c8' }}>
            {rows.map(([name, sel], i) =>
            <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', borderBottom: i === rows.length - 1 ? 'none' : '0.5px solid #e5e5ea' }}>
                <span className="material-icons-outlined" style={{ fontSize: 17, color: sel === '–' ? '#c7c7cc' : '#007aff' }}>{sel === '–' ? 'circle' : 'check_circle'}</span>
                <span style={{ flex: 1, fontSize: 12.5, color: '#000' }}>{name}</span>
                <span style={{ fontSize: 11.5, color: '#8e8e93' }}>{sel === '–' ? '' : sel}</span>
                <span className="material-icons-outlined" style={{ fontSize: 15, color: '#c7c7cc' }}>chevron_right</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </Phone>);

};

/* ice-sheet - mirrors showLinkTaskSheet exactly: same grammar, same explicit
   escape at the top, one row lower in the setup stack. */
const ICE_SHEET = () => {
  const sets = [
  ['The usual', '9 apps', true],
  ['The loud ones', '4 apps · 1 category', false]];

  return (
    <Phone bg={WHITE}>
      <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.25, pointerEvents: 'none' }}><FocusSetupShell /></div>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.40)' }} />
        <div style={{ position: 'absolute', bottom: 8, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 -8px 40px rgba(0,0,0,0.20)', overflow: 'hidden', padding: '10px 0px 34px' }}>
          <div style={{ width: 38, height: 4, borderRadius: 2, background: '#e0ddd7', margin: '0 auto 12px' }} />
          <div style={{ padding: '0 18px 12px' }}>
            <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>What goes on ice</div>
            <div style={{ fontSize: 15, color: MED, marginTop: 2 }}>Optional: frozen only while this session runs</div>
          </div>
          {/* the escape, exactly where "Focus without a task" sits */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 18px', borderTop: `1px solid ${BORDER}`, borderBottom: `1px solid ${BORDER}` }}>
            <div style={{ width: 30, height: 30, borderRadius: '50%', background: BG, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Ic n="focus" style={{ fontSize: 21, color: MED }} />
            </div>
            <span style={{ flex: 1, fontSize: 17, fontWeight: 700, color: TEXT }}>Keep everything open</span>
            <Ic n="aqx_ring" style={{ fontSize: 19, color: '#cfcbc4' }} />
          </div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, padding: '11px 18px 5px' }}>YOUR SETS</div>
          {sets.map(([name, count, sel]) =>
          <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '9px 18px', background: sel ? ACCL : 'transparent' }}>
              <Ic n="freeze" style={{ fontSize: 21, color: sel ? ACC : DIM, flexShrink: 0 }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>{name}</div>
                <div style={{ fontSize: 13, color: DIM, marginTop: 1 }}>{count}</div>
              </div>
              <Ic n={sel ? 'check_circle' : 'radio_button_unchecked'} style={{ fontSize: 19, color: sel ? ACC : '#cfcbc4' }} />
            </div>
          )}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '9px 18px 2px', color: ACC }}>
            <Ic n="add" style={{ fontSize: 20 }} />
            <span style={{ fontSize: 15, fontWeight: 700 }}>New set</span>
            <span style={{ fontSize: 13, color: DIM, fontWeight: 600 }}>one slot left</span>
          </div>
          <div style={{ margin: '12px 18px 0', background: INK, borderRadius: 100, padding: '13px 0', textAlign: 'center', fontSize: 17, fontWeight: 800, color: '#fff' }}>Put on ice</div>
        </div>
      </div>
    </Phone>);

};

/* ice-sets - the three named sets. A rule editor rich enough to need its own
   mental model is exactly the executive-function tax this audience can't pay,
   so the cap is three and it is stated rather than enforced silently. */
const ICE_SETS = () =>
<Phone>
    <SetBody title="Sets">
      <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, margin: '0 3px 12px' }}>Build up to three, then pick one per session instead of choosing apps again every time.</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginBottom: 18 }}>
        {[['The usual', '9 apps', 'Last used'], ['The loud ones', '4 apps · 1 category', null]].map(([name, count, tag]) =>
      <Card key={name} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '12px 14px' }}>
            <Ic n="freeze" style={{ fontSize: 19, color: ACC, flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                <span style={{ fontSize: 17, fontWeight: 800 }}>{name}</span>
                {tag && <span style={{ background: HILITE, borderRadius: 100, padding: '2px 7px', fontSize: 11, fontWeight: 800, letterSpacing: '0.05em', color: MED }}>{tag.toUpperCase()}</span>}
              </div>
              <div style={{ fontSize: 13, color: MED, marginTop: 2 }}>{count}</div>
            </div>
            <Ic n="chevron_right" style={{ fontSize: 19, color: DIM, flexShrink: 0 }} />
          </Card>
      )}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, border: `1.5px dashed ${ACC}77`, borderRadius: 16, padding: '13px 0', color: ACC }}>
          <Ic n="add" style={{ fontSize: 21 }} />
          <span style={{ fontSize: 17, fontWeight: 800 }}>One more set</span>
        </div>
      </div>
      <GroupLabel>Never on ice</GroupLabel>
      <Card style={{ padding: '12px 13px', marginBottom: 16 }}>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5, marginBottom: 9 }}>
          {ICE_FLOOR.map((a) => <span key={a} style={{ background: HILITE, borderRadius: 100, padding: '4px 9px', fontSize: 13, fontWeight: 700, color: TEXT }}>{a}</span>)}
        </div>
        <div style={{ fontSize: 13, color: MED, lineHeight: 1.5 }}>These stay reachable whatever you pick. A frost that can hold your messages is a day spent unreachable.</div>
      </Card>
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', margin: '0 3px' }}>
        <Ic n="hidden" style={{ fontSize: 19, color: SUCC, flexShrink: 0, marginTop: 1 }} />
        <span style={{ fontSize: 13, color: MED, lineHeight: 1.55 }}>Your picks live on this phone as opaque tokens. Aqademiq never learns the names, so there is nothing to sync and nothing to leak.</span>
      </div>
    </SetBody>
    <BNav active={3} />
  </Phone>;


/* ── The shield ────────────────────────────────────────────────────────── */

/* The action block. Rendered from ONE component so the three stages are
   literally identical below the prose: the funniest line on the first read is
   the most irritating on the twentieth, but the exit must never change. */
const ShieldActions = () =>
<div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'center' }}>
    <div style={{ width: '100%', background: INK, borderRadius: 100, height: 50, boxSizing: 'border-box', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, color: '#fff', cursor: 'pointer' }}>Back to focus</div>
    <div style={{ width: '100%', background: 'rgba(255,255,255,0.88)', borderRadius: 100, height: 50, boxSizing: 'border-box', fontSize: 17, fontWeight: 800, color: FROST_INK, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, cursor: 'pointer' }}>
      <Ic n="thaw" style={{ fontSize: 19, color: ACC }} />Thaw · 10s
    </div>
  </div>;


// Read in under a second, by someone mid-reflex who did not consciously
// decide to open anything. Warm, fast, and free of judgement.
const IceShield = ({ stage = 1 }) => {
  const copy = [
  { t: "Ada's sitting on this one.", s: 'Yours again at 3:42', cube: 74, bub: 3, cheeks: true, size: 22 },
  { t: 'Still on ice.', s: '3:42', cube: 52, bub: 2, cheeks: false, size: 20 },
  { t: 'Frozen.', s: '3:42', cube: 36, bub: 1, cheeks: false, size: 20 }][
  stage - 1];
  return (
    <Phone bg={FROST_BG}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '0 22px 22px', textAlign: 'center' }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <CubeSVG size={copy.cube} tone={CUBE_TONES[4]} melt={0} expr="happy" bubbles={copy.bub} cheeks={copy.cheeks} />
          <div style={{ fontFamily: SANS, fontSize: copy.size, fontWeight: 800, letterSpacing: -0.3, color: FROST_INK, marginTop: 16 }}>{copy.t}</div>
          <div style={{ fontSize: 17, fontWeight: 600, color: FROST_SUB, marginTop: 5 }}>{copy.s}</div>
        </div>
        <ShieldActions />
      </div>
    </Phone>);

};

const ICE_SHIELD_FIRST = () => <IceShield stage={1} />;
const ICE_SHIELD_SECOND = () => <IceShield stage={2} />;
const ICE_SHIELD_THIRD = () => <IceShield stage={3} />;

/* ice-thaw - the price of leaving is watching ice melt. Not a penalty screen
   and not a counter: the brand animation doing the thing the metaphor
   promised. The session does not end, and it re-freezes by itself. */
const ICE_THAW = () =>
<Phone bg={FROST_BG}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '0 22px 22px', textAlign: 'center' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <IceTimer progress={0.3} size={130} drip />
        <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800, color: FROST_INK, marginTop: 16 }}>Melting…</div>
        <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 34, fontWeight: 800, letterSpacing: 0.5, color: FROST_INK, lineHeight: 1.1, marginTop: 3 }}>0:07</div>
        <div style={{ fontSize: 15, fontWeight: 600, color: FROST_SUB, lineHeight: 1.5, marginTop: 9 }}>Two minutes, then it re-freezes</div>
      </div>
      <div style={{ width: '100%', background: 'rgba(255,255,255,0.88)', borderRadius: 100, padding: '12px 0', textAlign: 'center', fontSize: 17, fontWeight: 800, color: FROST_INK, cursor: 'pointer' }}>Never mind</div>
    </div>
  </Phone>;


/* ── The rules layer ───────────────────────────────────────────────────── */

// One Frost card. The card IS the editor - taps apply, the name derives from
// the shape, and there is no save button anywhere in this layer. Kept dense:
// three of these plus the cap slot and the stand-down have to coexist above
// the fold, because the list's whole point is that three is the ceiling.
const FrostCard = ({ label, title, days, chips, note, on, expanded }) =>
<Card style={{ padding: '9px 11px 10px' }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 5 }}>
      <Ic n="freeze" style={{ fontSize: 18, color: on ? ACC : DIM, flexShrink: 0 }} />
      <span style={{ flex: 1, fontSize: 11, fontWeight: 800, letterSpacing: '0.09em', color: MED }}>{label}</span>
      <Toggle on={on} />
    </div>
    <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: -0.2, marginBottom: 6 }}>{title}</div>
    <div style={{ marginBottom: 6 }}><FrostDays on={days} size={18} edit={expanded} /></div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
      {chips.map((c) => <IceChip key={c[1]} icon={c[0]} sm>{c[1]}</IceChip>)}
    </div>
    {note && <div style={{ fontSize: 13, color: MED, lineHeight: 1.5, marginTop: 8 }}>{note}</div>}
  </Card>;


// `expanded` opens the first card as its own editor in place.
const FrostListBody = ({ expanded }) =>
<SetBody title="Today's Frost">
    {expanded ?
  <>
        <Card style={{ padding: '12px 14px 13px', marginBottom: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <Ic n="freeze" style={{ fontSize: 19, color: ACC }} />
            <span style={{ flex: 1, fontSize: 12, fontWeight: 800, letterSpacing: '0.09em', color: MED }}>FROST · WEEKDAYS</span>
            <Toggle on={true} />
          </div>
          {/* the stated guess. Touching any day dismisses it permanently -
              correction is the only acknowledgement needed. */}
          <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', background: ACCL, borderRadius: 12, padding: '9px 11px', marginBottom: 11 }}>
            <AdaBlob size={20} mood="happy" />
            <span style={{ fontSize: 13, color: TEXT, lineHeight: 1.5 }}>We guessed: Monday to Friday, 9 to 3. Fix what's wrong.</span>
          </div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 7 }}>DAYS</div>
          <div style={{ marginBottom: 12 }}><FrostDays on={[1, 2, 3, 4, 5]} size={24} edit /></div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 7 }}>WINDOW</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 5 }}>
            <span style={{ flex: 1, textAlign: 'center', background: HILITE, borderRadius: 10, padding: '7px 0', fontSize: 17, fontWeight: 800 }}>9:00</span>
            <span style={{ fontSize: 15, color: DIM }}>→</span>
            <span style={{ flex: 1, textAlign: 'center', background: HILITE, borderRadius: 10, padding: '7px 0', fontSize: 17, fontWeight: 800 }}>15:00</span>
          </div>
          <div style={{ fontSize: 12, color: MED, marginBottom: 13 }}>An end time is required · 12 hours max</div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 7 }}>HOW SOFT</div>
          <div style={{ display: 'flex', gap: 7, marginBottom: 6 }}>
            {[['Soft', true], ['Firm', false]].map(([l, sel]) =>
        <span key={l} style={{ flex: 1, textAlign: 'center', borderRadius: 10, padding: '8px 0', fontSize: 15, fontWeight: 800, background: sel ? ACCL : HILITE, border: `1.5px solid ${sel ? ACC : 'transparent'}`, color: sel ? ACC : TEXT, boxSizing: 'border-box' }}>{l}</span>
        )}
          </div>
          <div style={{ fontSize: 12, color: MED, marginBottom: 13 }}>A focus session lifts a soft frost while it runs.</div>
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.08em', color: DIM, marginBottom: 7 }}>WHAT GOES ON ICE</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, background: BG, borderRadius: 12, padding: '10px 12px' }}>
            <Ic n="freeze" style={{ fontSize: 20, color: ACC }} />
            <span style={{ flex: 1, fontSize: 17, fontWeight: 700 }}>The usual</span>
            <span style={{ fontSize: 13, color: MED, fontWeight: 600 }}>9 apps</span>
            <Ic n="chevron_right" style={{ fontSize: 21, color: DIM }} />
          </div>
        </Card>
      </> :

  <>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 8 }}>
          <FrostCard on label="FROST · WEEKDAYS" title="Mon to Fri · 9:00–15:00" days={[1, 2, 3, 4, 5]}
      chips={[['ac_unit', 'The usual · 9 on ice'], ['bolt', 'Soft']]} />
          <FrostCard label="DRIFT · REST" title="Sat & Sun · all day" days={[6, 7]}
      chips={[['menu_book', 'Coursework · 6 on ice'], ['spa', 'Soft']]} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, border: `1.5px dashed ${ACC}77`, borderRadius: 16, padding: '9px 0', color: ACC }}>
            <Ic n="add" style={{ fontSize: 20 }} />
            <span style={{ fontSize: 17, fontWeight: 800 }}>One more frost</span>
            <span style={{ fontSize: 12, color: DIM, fontWeight: 600 }}>three is the cap</span>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: WHITE, borderRadius: 16, boxShadow: SHADOW, padding: '11px 13px' }}>
          <Ic n="thaw" style={{ fontSize: 18, color: WARN, flexShrink: 0 }} />
          <span style={{ flex: 1, minWidth: 0, fontSize: 17, fontWeight: 800 }}>Thaw everything</span>
          <Ic n="chevron_right" style={{ fontSize: 18, color: DIM, flexShrink: 0 }} />
        </div>
      </>
  }
  </SetBody>;


const FROST_LIST = () =>
<Phone>
    <FrostListBody />
    <BNav active={3} />
  </Phone>;

const FROST_EDIT = () =>
<Phone>
    <FrostListBody expanded />
    <BNav active={3} />
  </Phone>;


/* frost-today - the morning arm, as an in-app card on Plan. No notification
   is scheduled for this: silence already resolves to no, so the prompt needs
   no push to work - which also keeps it out of a nearly-full budget. */
const FROST_TODAY = () => {
  const tasks = [['LL(1) parsing notes', 'CC 401 · 9:30', ACC], ['Assignment 3 draft', 'NLP 302 · 11:00', '#5cbbff']];
  return (
    <Phone>
      <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
        <PlanHeader />
        <PlanDateStrip />
        <Card style={{ padding: '12px 14px 12px', marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 7 }}>
            <Ic n="freeze" style={{ fontSize: 19, color: ACC, flexShrink: 0 }} />
            <span style={{ flex: 1, fontSize: 12, fontWeight: 800, letterSpacing: '0.09em', color: MED }}>TODAY'S FROST</span>
            <span style={{ fontSize: 13, fontWeight: 700, color: MED, cursor: 'pointer' }}>Not today</span>
          </div>
          <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: -0.2, marginBottom: 4 }}>Mon to Fri · 9:00–15:00</div>
          <div style={{ marginBottom: 11 }}><IceChip>The usual · 9 on ice</IceChip></div>
          <div style={{ display: 'flex', gap: 8 }}>
            <div style={{ flex: 1, background: INK, borderRadius: 100, padding: '10px 0', textAlign: 'center', fontSize: 17, fontWeight: 800, color: '#fff', cursor: 'pointer' }}>Hold it</div>
            <div style={{ flex: 1, background: WHITE, border: `1.5px solid ${BORDER}`, borderRadius: 100, padding: '10px 0', textAlign: 'center', fontSize: 17, fontWeight: 800, color: TEXT, cursor: 'pointer' }}>Shift it</div>
          </div>
          <div style={{ fontSize: 12, color: DIM, textAlign: 'center', marginTop: 8 }}>Do nothing and it stays off.</div>
        </Card>
        <div style={{ marginBottom: 8 }}><CollapseHead label="PLANNED" count={3} open /></div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          {tasks.map(([name, meta, color]) =>
          <Card key={name} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 13px' }}>
              <span style={{ width: 9, height: 9, borderRadius: '50%', background: color, flexShrink: 0 }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: 700 }}>{name}</div>
                <div style={{ fontSize: 13, color: DIM, marginTop: 1 }}>{meta}</div>
              </div>
              <Ic n="aqx_ring" style={{ fontSize: 18, color: DIM }} />
            </Card>
          )}
        </div>
      </div>
      <BNav active={1} />
    </Phone>);

};

/* frost-standdown - the emergency exit, reusing the verb the student already
   learned on the shield. No questions, no confirmation, no win-back. */
const FROST_STANDDOWN = () =>
<SettingsSheet
  body={<FrostListBody />}
  panel={
  <SheetPanel title="Thaw everything">
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginTop: -8, marginBottom: 14 }}>Every frost stands down. Nothing goes on ice until you bring it back.</div>
        {[['Just today', 'Back tomorrow morning'], ['A week', 'Back next Monday'], ['Until I bring it back', 'No end date']].map(([l, s], i) =>
    <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '12px 14px', borderRadius: 16, background: i === 0 ? ACCL : HILITE, border: `1.5px solid ${i === 0 ? ACC : 'transparent'}`, marginBottom: 9, cursor: 'pointer' }}>
            <Ic n="thaw" style={{ fontSize: 19, color: i === 0 ? ACC : TEXT, flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 17, fontWeight: 800, color: i === 0 ? ACC : TEXT }}>{l}</div>
              <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>{s}</div>
            </div>
          </div>
    )}
        <div style={{ fontSize: 13, color: DIM, textAlign: 'center', lineHeight: 1.5, marginTop: 4 }}>No questions asked, and nothing to undo later.</div>
      </SheetPanel>
  } />;


/* ── Settings ──────────────────────────────────────────────────────────── */

/* App freeze settings. What you change most sits first, then whether it is
   working: the one honest line about reliability stays above the fold. */
const FzStatus = ({ tone, children }) =>
<span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: tone === FZ_DANGER ? FZ_DANGER : MED }}>
    <span style={{ width: 8, height: 8, borderRadius: '50%', background: tone, flexShrink: 0 }}></span>{children}
  </span>;

// Option card for the App freeze sheets (same language as Haptics).
const FzPick = ({ icon, label, sub, sel }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 16, background: sel ? ACCL : HILITE, border: '1.5px solid ' + (sel ? ACC : 'transparent'), cursor: 'pointer' }}>
    <Ic n={icon} style={{ fontSize: 21, color: sel ? ACC : TEXT, flexShrink: 0 }} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 17, fontWeight: 800, color: sel ? ACC : TEXT }}>{label}</div>
      <div style={{ fontSize: 13, color: MED, marginTop: 1, lineHeight: 1.4 }}>{sub}</div>
    </div>
    {sel && <Ic n="check_circle:fill" style={{ fontSize: 21, color: ACC, flexShrink: 0 }} />}
  </div>;

// health: ok (iOS, working) · warn (Android, battery restricted) · off (Screen Time revoked).
// standdown: Thaw everything is on.
const IceSettingsBody = ({ os = 'ios', health = 'ok', standdown }) => {
  const android = os === 'android';
  const rel = {
    ok: ['check_circle', SUCC, 'Working on this phone', 'Screen Time holds your frozen apps, so frosts keep running even when Aqademiq is closed.'],
    warn: ['error_outline', WARN, 'Might stop in the background', 'Android can close Aqademiq to save battery. If it does, apps stop freezing.'],
    off: ['cancel', WARN, 'Nothing is freezing', 'Screen Time access is off. Your frosts are saved and come back when you turn it on.']
  }[health];
  return (
    <>
      {standdown &&
      <div style={{ background: ACCL, borderRadius: 18, padding: '14px 15px 15px', marginBottom: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 4 }}>
            <Ic n="thaw" style={{ fontSize: 21, color: ACC }} />
            <span style={{ fontSize: 17, fontWeight: 800 }}>Everything's thawed</span>
          </div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.45, marginBottom: 12 }}>Back tomorrow at 7:00 AM. Never open stays frozen.</div>
          <PBtn>Bring it back now</PBtn>
        </div>}
      <GroupLabel>Freezing</GroupLabel>
      <SetGroup style={{ marginBottom: 20 }}>
        <SetRow icon="ac_unit" label="Frosts & groups" value={standdown ? 'Paused' : '2 frosts'} chevron />
        <SetRow icon="thaw" label="Thaw" value="Standard · 2 min" chevron />
        {standdown ?
        <SetRow icon="waves" label="Thaw everything" value="Until 7:00 AM" chevron last /> :
        <SetRow icon="waves" label="Thaw everything" sub="For a day, a week, or until you're back" chevron last />}
      </SetGroup>
      <GroupLabel>Reliability</GroupLabel>
      <SetGroup style={{ marginBottom: 20 }}>
        <div style={{ padding: '12px 15px 13px', borderBottom: '1px solid ' + BORDER }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 5 }}>
            <Ic n={rel[0]} style={{ fontSize: 21, color: rel[1] }} />
            <span style={{ flex: 1, fontSize: 17, fontWeight: 800 }}>{rel[2]}</span>
          </div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.45 }}>{rel[3]}</div>
          {health === 'off' && <PBtn style={{ marginTop: 12 }}>Turn Screen Time back on</PBtn>}
        </div>
        <SetRow icon="refresh" label="Check my setup" sub="Re-checks access and re-applies your frosts" chevron last />
      </SetGroup>
      <GroupLabel>Permissions</GroupLabel>
      <SetGroup style={{ marginBottom: 20 }}>
        {android ?
        <>
            <SetRow icon="query_stats" label="Usage access" value={<FzStatus tone={SUCC}>Allowed</FzStatus>} chevron />
            <SetRow icon="layers" label="Appear on top" value={<FzStatus tone={SUCC}>Allowed</FzStatus>} chevron />
            <SetRow icon="battery_alert" iconColor={WARN} label="Battery" value={<FzStatus tone={WARN}>Restricted</FzStatus>} chevron last />
          </> :
        <SetRow icon="hourglass_empty" label="Screen Time" value={health === 'off' ? <FzStatus tone={FZ_DANGER}>Off</FzStatus> : <FzStatus tone={SUCC}>Allowed</FzStatus>} chevron last />}
      </SetGroup>
      <GroupLabel>Privacy</GroupLabel>
      <SetGroup>
        <SetRow icon="visibility_off" label="What we can see" sub={android ? 'App names, on this phone only. Never sent to us.' : 'Nothing. iOS gives us tokens, not names.'} chevron />
        <SetRow icon="description" label="What we refuse to do for engagement" chevron last />
      </SetGroup>
    </>);
};

const ICE_SETTINGS = () => <SetScreen title="App freeze"><IceSettingsBody /></SetScreen>;
const ICE_SETTINGS_ANDROID = () => <SetScreen title="App freeze" offset={230}><IceSettingsBody os="android" health="warn" /></SetScreen>;
const ICE_SETTINGS_OFF = () => <SetScreen title="App freeze"><IceSettingsBody health="off" /></SetScreen>;
const ICE_SETTINGS_STANDDOWN = () => <SetScreen title="App freeze"><IceSettingsBody standdown /></SetScreen>;

// Thaw: the wait and the length. Preview first, as a block-screen preview would.
const ThawPreview = () =>
<div style={{ height: 280, margin: '0 -16px 16px', overflow: 'hidden', WebkitMaskImage: 'linear-gradient(180deg, #000 82%, transparent)', maskImage: 'linear-gradient(180deg, #000 82%, transparent)' }}>
    <div style={{ width: 220, height: 300, margin: '2px auto 0', boxSizing: 'border-box', borderRadius: 44, border: '7px solid ' + (IS_DARK ? '#2c2934' : '#e4e0ec'), background: FROST_BG, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '10px 14px 0', textAlign: 'center' }}>
      <div style={{ width: 62, height: 18, borderRadius: 9, background: '#1a1320', marginBottom: 24 }}></div>
      <IceTimer progress={0.3} size={84} drip />
      <div style={{ fontFamily: SANS, fontSize: 17, fontWeight: 800, color: FROST_INK, marginTop: 12 }}>Take a breath.</div>
      <div style={{ fontSize: 13, fontWeight: 600, color: FROST_SUB, lineHeight: 1.4, marginTop: 3 }}>Still want Instagram<br />in 7 seconds?</div>
    </div>
  </div>;

const ThawBody = () =>
<>
    <ThawPreview />
    <GroupLabel>The wait</GroupLabel>
    <SetGroup style={{ marginBottom: 20 }}>
      <SetRow icon="shield" label="Resistance" sub="Standard · 10 seconds, every time" chevron last />
    </SetGroup>
    <GroupLabel>Thaw length</GroupLabel>
    <SetGroup style={{ padding: 12, marginBottom: 8 }}>
      <div style={{ display: 'flex', gap: 8 }}>
        {[2, 5, 10, 15].map((m) =>
        <div key={m} style={{ flex: 1, height: 36, borderRadius: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 700, background: m === 2 ? INK : BG, color: m === 2 ? '#fff' : TEXT, cursor: 'pointer' }}>{m} min</div>
        )}
      </div>
    </SetGroup>
    <div style={{ fontSize: 13, color: MED, lineHeight: 1.5, margin: '0 4px 20px' }}>Picked for you each time you thaw. You can still change it.</div>
    <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', margin: '0 4px' }}>
      <Ic n="never_open" style={{ fontSize: 17, color: DIM, flexShrink: 0, marginTop: 1 }} />
      <span style={{ fontSize: 13, color: MED, lineHeight: 1.5 }}>Deep freeze frosts skip all of this. No thawing while they run.</span>
    </div>
  </>;

const ICE_THAW_SETTINGS = () => <SetScreen title="Thaw"><ThawBody /></SetScreen>;

const ICE_THAW_RESISTANCE = () =>
<SettingsSheet
  body={<SetBody title="Thaw"><ThawBody /></SetBody>}
  panel={
  <SheetPanel title="Resistance">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          <FzPick icon="shield" label="Standard" sub="10 seconds, every time" sel />
          <FzPick icon="trend" label="Increasing" sub="Adds 10 seconds each thaw, up to a minute. Resets each morning." />
        </div>
        <div style={{ fontSize: 13, color: DIM, textAlign: 'center', lineHeight: 1.5, marginTop: 12 }}>Applies to every thaw, including Thaw everything.</div>
      </SheetPanel>
  } />;

// Thaw everything: every frost stands down. A running Deep freeze keeps its deal.
const ThawAllPanel = ({ deep }) =>
<SheetPanel title="Thaw everything">
    <div style={{ fontSize: 15, color: MED, lineHeight: 1.5, marginTop: -8, marginBottom: 14 }}>Every frost stands down until you're back. Never open stays frozen.</div>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginBottom: 14 }}>
      <FzPick icon="today" label="Just today" sub="Back tomorrow at 7:00 AM" sel={!deep} />
      <FzPick icon="date_range" label="A week" sub="Back in 7 days" sel={deep} />
      <FzPick icon="all_inclusive" label="Until I bring it back" sub="No end date" />
    </div>
    {deep &&
  <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: BG, borderRadius: 16, padding: '11px 14px', marginBottom: 14 }}>
        <Ic n="never_open" style={{ fontSize: 20, color: ACC, flexShrink: 0 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 800 }}>Lecture hours holds until 1:00 PM</div>
          <div style={{ fontSize: 13, color: MED, marginTop: 1, lineHeight: 1.4 }}>It's in Deep freeze. After that, it stands down too.</div>
        </div>
      </div>}
    <PBtn>{deep ? 'Thaw everything else' : 'Thaw everything'}</PBtn>
    <div style={{ fontSize: 13, color: DIM, textAlign: 'center', lineHeight: 1.5, marginTop: 10 }}>Takes the usual breath first.</div>
  </SheetPanel>;

const ICE_THAW_ALL = () => <SettingsSheet body={<SetBody title="App freeze"><IceSettingsBody /></SetBody>} panel={<ThawAllPanel />} />;
const ICE_THAW_ALL_DEEP = () => <SettingsSheet body={<SetBody title="App freeze"><IceSettingsBody /></SetBody>} panel={<ThawAllPanel deep />} />;

const ICE_BATTERY_SHEET = () =>
<SettingsSheet
  body={<SetBody title="App freeze"><IceSettingsBody /></SetBody>}
  panel={
  <SheetPanel title="Your battery manager can stop this">
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginTop: -8, marginBottom: 14 }}>Some phones shut background work down to save power. If that happens here, apps quietly stop freezing, and you'd have no way to know.</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, background: BG, borderRadius: 16, padding: '12px 14px', marginBottom: 14 }}>
          <Ic n="battery" style={{ fontSize: 20, color: WARN, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 800 }}>Aqademiq · Battery</div>
            <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>Currently restricted by your phone</div>
          </div>
          <span style={{ background: WARN, color: '#fff', borderRadius: 100, padding: '3px 8px', fontSize: 12, fontWeight: 800, letterSpacing: '0.04em', flexShrink: 0 }}>FIX</span>
        </div>
        <PBtn style={{ marginBottom: 10 }}>Open battery settings</PBtn>
        <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 600, color: MED, cursor: 'pointer' }}>Leave it as it is</div>
      </SheetPanel>
  } />;


const HAPTICS_SHEET = () =>
<SettingsSheet
  body={<SetBody title="Settings" big gear><HomeBody /></SetBody>}
  panel={
  <SheetPanel title="Haptics">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {[['do_not_disturb_on', 'Off', 'No vibration anywhere', false],
    ['vibration', 'Essential', 'Session start, end, and a thaw', true],
    ['mi:graphic_eq', 'Full', 'Every tap and toggle', false]].map(([icon, label, sub, sel]) =>
    <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 16, background: sel ? ACCL : HILITE, border: `1.5px solid ${sel ? ACC : 'transparent'}` }}>
              <Ic n={icon} style={{ fontSize: 21, color: sel ? ACC : TEXT }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: 800, color: sel ? ACC : TEXT }}>{label}</div>
                <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>{sub}</div>
              </div>
              {sel && <Ic n="check_circle:fill" style={{ fontSize: 21, color: ACC }} />}
            </div>
    )}
        </div>
      </SheetPanel>
  } />;


/* fc-end-ice - session end with the trim offer. Thaws are counted and never
   scolded: a numeral beside focus minutes, with no adjective attached. The
   offer is app-agnostic because iOS genuinely never told us the name. */
const SESSION_END_ICE = () => {
  const E_INK = '#1a1320';
  const E_SUB = 'rgba(36,24,52,0.62)';
  return (
    <Phone bg={`linear-gradient(160deg, #f5f2ff 0%, #c9bcf8 46%, ${ACC} 100%)`}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '14px 20px', textAlign: 'center' }}>
        <div style={{ background: 'rgba(255,255,255,0.6)', borderRadius: 100, padding: '5px 13px', fontSize: 13, fontWeight: 700, color: E_INK, display: 'flex', gap: 6, alignItems: 'center', marginBottom: 18, backdropFilter: 'blur(6px)' }}>
          <Ic n="prism" style={{ fontSize: 16, color: ACC }} /> Deep Work · Prism
        </div>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, marginBottom: 5, color: E_INK }}>Session done</div>
        <div style={{ fontSize: 15, color: E_SUB, marginBottom: 14 }}>LL(1) parsing notes · CC 401</div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 14 }}>
          <div style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 46, fontWeight: 800, letterSpacing: 0.5, color: E_INK, lineHeight: 1 }}>25:00</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 7 }}>
            <span style={{ fontSize: 17, fontWeight: 600, color: E_SUB }}>Focused</span>
            <span style={{ width: 3, height: 3, borderRadius: '50%', background: E_SUB }} />
            <span style={{ fontSize: 17, fontWeight: 600, color: E_SUB }}>2 thaws</span>
          </div>
        </div>
        <div style={{ background: 'rgba(255,255,255,0.78)', borderRadius: 18, padding: '12px 13px', width: '100%', marginBottom: 10, backdropFilter: 'blur(8px)' }}>
          <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 10, color: E_INK }}>How was that session?</div>
          <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 6 }}>
            {[0, 1, 2, 3, 4].map((idx) => {
              const active = idx === 3;
              return (
                <div key={idx} style={{ padding: 2.5, borderRadius: '50%', border: active ? `2px solid ${MOODS[idx].color}` : '2px solid transparent', background: active ? MOODS[idx].color + '22' : 'transparent' }}>
                  <MoodBlob idx={idx} size={active ? 30 : 27} />
                </div>);

            })}
          </div>
        </div>
        <div style={{ display: 'flex', gap: 9, alignItems: 'center', background: 'rgba(255,255,255,0.62)', borderRadius: 14, padding: '10px 12px', width: '100%', marginBottom: 12, backdropFilter: 'blur(6px)' }}>
          <Ic n="freeze" style={{ fontSize: 21, color: ACC, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: E_INK }}>One app did both thaws</div>
            <div style={{ fontSize: 12, color: E_SUB, lineHeight: 1.45, marginTop: 1 }}>iOS won't tell us which. Trim The usual?</div>
          </div>
          <span style={{ fontSize: 13, fontWeight: 800, color: ACC, flexShrink: 0, cursor: 'pointer' }}>Trim</span>
        </div>
        <div style={{ width: '100%', height: 50, boxSizing: 'border-box', padding: '0 16px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: E_INK, borderRadius: 100, color: '#fff', fontSize: 17, fontWeight: 700, textAlign: 'center', cursor: 'pointer' }}>Back to today →</div>
      </div>
    </Phone>);

};

const FOCUS_ICE_CHIP = () =>
<Phone bg={WHITE}>
    <FocusSetupShell ice="set" />
  </Phone>;


/* ─── CANVAS + APP ────────────────────────────────────────────────────── */
/* ─── 04-A APP FREEZE ───────────────────────────────────────────────────
   Pushed from Focus - the ❄ App freeze pill. Freeze now, or let a frost (a
   rule: a session or a schedule) do it. Thawing takes a breath - ten seconds
   - then 2–15 minutes, and it refreezes by itself. Groups: Always open (the
   floor, never frozen), Never open, Distracting (Ada checks in, nothing
   freezes). Deep freeze (no thawing) and Keep only these are free. */
const FZ_DANGER = '#e85476';
// iOS large button: a 50pt capsule.
const FzBtn = ({ style, ...p }) => <PBtn {...p} style={{ height: 50, padding: '0 16px', fontSize: 15, ...style }} />;
const FZ_FLOOR = ['Phone', 'Messages', 'Maps', 'Wallet'];
// Fallback tiles for apps without an icon file. The build renders the OS
// icon (FamilyControls Label on iOS, PackageManager on Android).
const FZ_APP = {
  Instagram: { l: 'I', h: 330, s: 62 }, TikTok: { l: 'T', h: 220, s: 6 }, YouTube: { l: 'Y', h: 4, s: 68 },
  Reddit: { l: 'R', h: 20, s: 78 }, Netflix: { l: 'N', h: 354, s: 58 }, X: { l: 'X', h: 0, s: 0 },
  Snapchat: { l: 'S', h: 50, s: 80 },
  Phone: { ic: 'call', h: 140, s: 48 }, Messages: { ic: 'chat_bubble', h: 140, s: 48 }, Maps: { ic: 'map', h: 205, s: 58 },
  Wallet: { ic: 'account_balance_wallet', h: 0, s: 0 }, Notion: { ic: 'description', h: 0, s: 0 },
  Canvas: { ic: 'school', h: 8, s: 66 }, Spotify: { ic: 'graphic_eq', h: 145, s: 52 }
};
const fzTint = (a) => IS_DARK ?
{ bg: `hsl(${a.h} ${Math.round(a.s * 0.4)}% 21%)`, ink: `hsl(${a.h} ${Math.max(a.s, 8)}% 80%)` } :
{ bg: `hsl(${a.h} ${a.s}% 93%)`, ink: `hsl(${a.h} ${Math.round(Math.max(a.s * 0.8, 6))}% 36%)` };

// Apple's icon outline: continuous corners - the curve starts ~34% in and
// lands at a ~22% radius. One mask for photos, tiles and the frost alike.
const FZ_SQ_PATH = 'M50 0H66C93.4 0 100 6.6 100 34V66C100 93.4 93.4 100 66 100H34C6.6 100 0 93.4 0 66V34C0 6.6 6.6 0 34 0Z';
const FZ_SQ = 'url("data:image/svg+xml,' + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100' preserveAspectRatio='none'><path d='" + FZ_SQ_PATH + "'/></svg>") + '")';
const fzMask = { WebkitMaskImage: FZ_SQ, maskImage: FZ_SQ, WebkitMaskSize: '100% 100%', maskSize: '100% 100%', WebkitMaskRepeat: 'no-repeat', maskRepeat: 'no-repeat' };
// Real icons live in assets/app-icons/<name>.png - listed here so a missing
// file never 404s. Anything not listed falls back to a tinted tile.
const FZ_HAVE = new Set(['messages', 'youtube', 'reddit']);
const fzSlug = (n) => n.toLowerCase().replace(/[^a-z0-9]/g, '');

const FzIcon = ({ name, size = 30, frozen }) => {
  const a = FZ_APP[name] || { l: name[0], h: 0, s: 0 },t = fzTint(a),slug = fzSlug(name);
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <div style={{ position: 'absolute', inset: 0, ...fzMask, background: t.bg, color: t.ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {FZ_HAVE.has(slug) ?
        <img src={window.__resources && window.__resources['icon_' + slug] || 'assets/app-icons/' + slug + '.png'} alt={name} style={{ width: '100%', height: '100%', display: 'block' }} /> :
        a.ic ?
        <span className="material-icons-outlined" style={{ fontSize: Math.round(size * 0.5) }}>{a.ic}</span> :
        <span style={{ fontFamily: SANS, fontSize: Math.round(size * 0.46), fontWeight: 800, lineHeight: 1 }}>{a.l}</span>}
      </div>
      {frozen &&
      <div style={{ position: 'absolute', inset: 0, ...fzMask, background: IS_DARK ? 'rgba(26,22,48,0.62)' : 'rgba(255,255,255,0.64)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Ic n="freeze" style={{ fontSize: Math.round(size * 0.46), color: ACC }} />
        </div>}
      {frozen &&
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', overflow: 'visible' }}>
          <path d={FZ_SQ_PATH} fill="none" stroke={ACC} strokeOpacity="0.55" strokeWidth={(150 / size).toFixed(2)} />
        </svg>}
    </div>);
};

// A tile with its state: frozen (frost + "Thaw"), thawed (a ring running down
// to the refreeze + minutes left), or plain (name). 60 is the Home Screen size.
const FzApp = ({ name, size = 60, state, mins, progress = 0.6 }) => {
  const o = size + 10,sw = (300 / o).toFixed(2);
  const cap = state === 'frozen' ? 'Thaw' : state === 'thawed' ? mins + 'm' : name;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5 }}>
      <div style={{ position: 'relative', width: o, height: o, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {state === 'thawed' &&
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', overflow: 'visible' }}>
            <path d={FZ_SQ_PATH} pathLength="100" fill="none" stroke={HILITE} strokeWidth={sw} />
            <path d={FZ_SQ_PATH} pathLength="100" fill="none" stroke={ACC} strokeWidth={sw} strokeLinecap="round" strokeDasharray={(progress * 100).toFixed(1) + ' 100'} />
          </svg>}
        <FzIcon name={name} size={size} frozen={state === 'frozen'} />
      </div>
      <div style={{ fontSize: 15, fontWeight: 600, color: state === 'frozen' ? ACC : TEXT, whiteSpace: 'nowrap' }}>{cap}</div>
    </div>);
};

const FzStack = ({ apps, more, size = 28, edge = WHITE }) =>
<div style={{ display: 'flex', alignItems: 'center' }}>
    {apps.map((n, i) => <div key={n} style={{ marginLeft: i ? -8 : 0, width: size + 4, height: size + 4, ...fzMask, background: edge, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><FzIcon name={n} size={size} /></div>)}
    {more ? <span style={{ marginLeft: -7, height: size + 4, minWidth: size + 4, boxSizing: 'border-box', borderRadius: 100, border: `2px solid ${edge}`, background: HILITE, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 6px', fontSize: 13, fontWeight: 800, color: MED }}>+{more}</span> : null}
  </div>;

const FzSec = ({ title, action, quiet, chevron, style }) =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, ...style }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 2, cursor: chevron ? 'pointer' : 'default' }}>
      <span style={{ fontFamily: SANS, fontSize: 20, fontWeight: 700, letterSpacing: -0.2 }}>{title}</span>
      {chevron && <Ic n="chevron_right" style={{ fontSize: 24, color: DIM }} />}
    </div>
    {action && <span style={{ fontSize: 17, fontWeight: 600, color: quiet ? MED : ACC, cursor: 'pointer' }}>{action}</span>}
  </div>;

const FzPageHead = ({ title, sub, add = true }) =>
<>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
      <BackBtn />
      {add && <BarCircle icon="add" />}
    </div>
    <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.6, lineHeight: 1.12 }}>{title}</div>
    {sub && <div style={{ fontSize: 15, color: MED, lineHeight: 1.35, marginTop: 4 }}>{sub}</div>}
  </>;

const FzClaim = ({ icon, title, body, tone }) =>
<div style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}>
    <Ic n={icon} style={{ width: 32, textAlign: 'center', fontSize: 28, color: tone || ACC, flexShrink: 0 }} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 15, fontWeight: 700, color: TEXT, lineHeight: 1.33 }}>{title}</div>
      <div style={{ fontSize: 15, color: MED, lineHeight: 1.33, marginTop: 1 }}>{body}</div>
    </div>
  </div>;

const FZ_LECTURE = { name: 'Lecture hours', type: 'schedule', when: '9:00 AM – 1:00 PM', days: 'Weekdays', apps: ['Instagram', 'TikTok', 'YouTube'], more: 3 };
const FZ_EXAM = { name: 'Exam week', type: 'schedule', when: 'All day', days: 'Mon 12 – Sun 18', apps: ['Instagram', 'Reddit', 'Netflix'], more: 4, deep: true };
// trigger → freeze, the frost's signature glyph (used on cards and the running sheet)
const FzTrigger = ({ type = 'schedule', live, size = 26 }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
    <Ic n={type === 'session' ? 'timer' : 'calendar_month'} style={{ fontSize: size, color: live ? ACC : DIM }} />
    <Ic n="forward" style={{ fontSize: Math.round(size * 0.8), color: DIM }} />
    <Ic n="freeze" style={{ fontSize: size, color: live ? ACC : DIM }} />
  </div>;
const FzFrostCard = ({ f, status, live, w = 168, h = 180 }) =>
<div style={{ width: w, height: h, flexShrink: 0, boxSizing: 'border-box', background: live ? `linear-gradient(180deg, ${ACCL} 0%, ${WHITE} 62%)` : WHITE, borderRadius: 34, boxShadow: SHADOW, padding: '20px 16px 16px 18px', display: 'flex', flexDirection: 'column' }}>
    <FzTrigger type={f.type} live={live} />
    <div style={{ flex: 1 }}></div>
    <span style={{ alignSelf: 'flex-start', height: 26, display: 'inline-flex', alignItems: 'center', background: live ? ACCL : 'transparent', border: live ? 'none' : `1px solid ${BORDER}`, color: live ? ACC : TEXT, borderRadius: 13, padding: '0 10px', fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap' }}>{status}</span>
    <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 700, letterSpacing: -0.2, marginTop: 8, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{f.name}</div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
      <span style={{ fontSize: 17, color: MED }}>Freezes</span>
      <FzStack apps={f.apps.slice(0, 2)} size={22} />
    </div>
  </div>;

const FZ_GROUPS = [['Always open', ['Phone', 'Messages', 'Maps', 'Wallet']], ['Never open', []], ['Distracting', ['YouTube', 'Instagram', 'Reddit', 'Netflix', 'TikTok', 'X']]];
const FzGroups = ({ counts }) =>
<div style={{ display: 'flex', gap: 8 }}>
    {FZ_GROUPS.map(([name, apps], gi) => {
    const n = counts ? counts[gi] : apps.length,list = apps.slice(0, n),over = list.length > 4;
    const cells = [0, 1, 2, 3].map((i) => over && i === 3 ? { more: list.length - 3 } : list[i] ? { app: list[i] } : {});
    return (
      <div key={name} style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', cursor: 'pointer' }}>
          <div style={{ width: '100%', aspectRatio: '1', boxSizing: 'border-box', background: WHITE, borderRadius: 30, boxShadow: SHADOW, padding: 15, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 9 }}>
            {cells.map((c, i) =>
          <div key={i} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', aspectRatio: '1', ...fzMask, background: c.app ? 'transparent' : HILITE }}>
                {c.app ? <FzIcon name={c.app} size={38} /> : c.more ? <span style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>+{c.more}</span> : null}
              </div>
          )}
          </div>
          <div style={{ fontSize: 17, fontWeight: 600, marginTop: 10, textAlign: 'center', whiteSpace: 'nowrap' }}>{name}</div>
          <div style={{ fontSize: 15, color: MED, marginTop: 1 }}>{n} {n === 1 ? 'app' : 'apps'}</div>
        </div>);
  })}
  </div>;

const FZ_TEMPLATES = [['school', 'Lecture hours', '9 AM – 1 PM · Mon–Fri'], ['task_exam', 'Exam week', 'All day · 7 days'], ['center_focus_strong', 'Deep work', '2 hr session'], ['bedtime', 'Wind down', '10 PM – 7 AM · Daily']];
const FzTemplate = ({ t: [ic, name, meta], well, w }) =>
<div style={{ width: w, flexShrink: 0, boxSizing: 'border-box', background: well ? BG : WHITE, boxShadow: well ? 'none' : SHADOW, borderRadius: 26, padding: '14px 14px 15px 16px', display: 'flex', flexDirection: 'column', gap: 10, cursor: 'pointer' }}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <Ic n={ic} style={{ fontSize: 21, color: ACC }} />
      <span style={{ width: 28, height: 28, borderRadius: '50%', background: well ? WHITE : BG, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic n="add" style={{ fontSize: 18, color: TEXT }} /></span>
    </div>
    <div>
      <div style={{ fontSize: 15, fontWeight: 800 }}>{name}</div>
      <div style={{ fontSize: 13, color: MED, marginTop: 2 }}>{meta}</div>
    </div>
  </div>;

// The hub. One body for the page and for every sheet raised over it.
const FzHubBody = ({ empty, thawed, standdown }) =>
<div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
    <FzPageHead title="App freeze" />
    {empty ?
  <>
        <Card style={{ marginTop: 28, borderRadius: 34, padding: '22px 20px 20px', textAlign: 'center' }}>
          <div style={{ display: 'flex', justifyContent: 'center' }}><CubeSVG size={52} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={2} /></div>
          <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 700, marginTop: 10 }}>Nothing frozen</div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.35, margin: '4px 0 16px' }}>Freeze apps now, or on a schedule.</div>
          <FzBtn>Freeze apps</FzBtn>
        </Card>
        <FzSec title="Student frosts" chevron style={{ marginTop: 28 }} />
        <div style={{ display: 'flex', gap: 12, margin: '0 -16px', padding: '0 16px', overflow: 'hidden' }}>
          {FZ_TEMPLATES.map((t) => <FzTemplate key={t[1]} t={t} w={150} />)}
        </div>
      </> : standdown ?
  <>
        <Card style={{ marginTop: 28, borderRadius: 34, padding: '22px 20px 20px', textAlign: 'center' }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto' }}><Ic n="thaw" style={{ fontSize: 28, color: ACC }} /></div>
          <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 700, marginTop: 12 }}>Everything's thawed</div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.35, margin: '4px 0 16px' }}>Back tomorrow at 7:00 AM.</div>
          <FzBtn>Bring it back now</FzBtn>
        </Card>
        <FzSec title="Frosts" chevron style={{ marginTop: 28 }} />
        <div style={{ display: 'flex', gap: 14, margin: '0 -16px', padding: '0 16px', overflow: 'hidden' }}>
          <FzFrostCard f={FZ_LECTURE} status="Paused" />
          <FzFrostCard f={FZ_EXAM} status="Paused" />
          <FzFrostCard f={{ ...FZ_LECTURE, name: 'Wind down' }} status="Paused" />
        </div>
      </> :
  <>
        <FzSec title="Frozen" action="Thaw all" style={{ marginTop: 28 }} />
        <div style={{ display: 'flex', gap: 18 }}>
          <FzApp name="Instagram" state={thawed ? 'thawed' : 'frozen'} mins={5} progress={0.97} />
          <FzApp name="TikTok" state="thawed" mins={thawed ? 11 : 13} progress={thawed ? 0.74 : 0.8} />
          {!thawed && <FzApp name="YouTube" state="frozen" />}
        </div>
        <FzSec title="Frosts" chevron style={{ marginTop: 28 }} />
        <div style={{ display: 'flex', gap: 14, margin: '0 -16px', padding: '0 16px', overflow: 'hidden' }}>
          <FzFrostCard f={FZ_LECTURE} status="1h 40m left" live />
          <FzFrostCard f={FZ_EXAM} status="Starts in 4d" />
          <FzFrostCard f={{ ...FZ_LECTURE, name: 'Wind down' }} status="Starts 10 PM" />
        </div>
      </>}
    <FzSec title="Groups" style={{ marginTop: 28 }} />
    <FzGroups counts={empty ? [4, 0, 0] : undefined} />
  </div>;

// A sheet raised over a dimmed screen (the hub by default). iOS 26 partial
// sheet: floats 8 clear of the sides and bottom, corners concentric with the
// display (55 − 8 = 47). lift raises it above a keyboard.
const FzOver = ({ under, children, after, dim = 0.4, pad = '6px 16px 28px', lift = 0 }) =>
<Phone>
    <div style={{ height: 816, position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.35, pointerEvents: 'none' }}>{under || <><FzHubBody /><BNav active={2} /></>}</div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,' + dim + ')' }}></div>
      <div style={{ position: 'absolute', bottom: 8 + lift, left: 8, right: 8, background: WHITE, borderRadius: 47, boxShadow: '0 12px 44px rgba(0,0,0,0.24)', padding: pad }}>
        <div style={{ width: 36, height: 5, borderRadius: 2.5, background: IS_DARK ? 'rgba(255,255,255,0.22)' : '#dcd9e2', margin: '0 auto 12px' }}></div>
        {children}
      </div>
      {after}
    </div>
  </Phone>;

// Editor header: ✕ or back · centred title · an optional action.
const FzSheetHead = ({ back, title, right, editable, mb = 14 }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: mb }}>
    {back ? <BarCircle fill="well" icon="chevron_left" /> : <BarDismiss edge="left" />}
    <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5, fontFamily: SANS, fontSize: 17, fontWeight: 700, whiteSpace: 'nowrap' }}>
      {title}{editable && <Ic n="edit" style={{ fontSize: 16, color: DIM }} />}
    </div>
    {right || <span style={{ width: back ? HEAD_BTN : HEAD_BTN - 12, flexShrink: 0 }}></span>}
  </div>;

const FzSeg = ({ options, on = 0 }) =>
<div style={{ display: 'flex', background: BG, borderRadius: 100, padding: 3, marginBottom: 12 }}>
    {options.map((o, i) =>
  <div key={o} style={{ flex: 1, height: 32, borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 600, color: i === on ? TEXT : MED, background: i === on ? WHITE : 'transparent', boxShadow: i === on ? '0 1px 6px rgba(0,0,0,0.10)' : 'none', cursor: 'pointer' }}>{o}</div>
  )}
  </div>;

const FzRow = ({ name, sub, last, remove = true, add }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
    {add ?
  <div style={{ width: 30, height: 30, ...fzMask, background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n="add" style={{ fontSize: 20, color: ACC }} /></div> :
  <FzIcon name={name} size={30} />}
    {/* the separator starts at the text, as iOS lists do */}
    <div style={{ flex: 1, minWidth: 0, minHeight: sub ? 60 : 52, display: 'flex', alignItems: 'center', gap: 10, borderBottom: last ? 'none' : '1px solid ' + BORDER }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: add ? 700 : 500, color: add ? ACC : TEXT }}>{add ? 'Add apps or sites' : name}</div>
        {sub && <div style={{ fontSize: 15, color: MED, marginTop: 1 }}>{sub}</div>}
      </div>
      {!add && remove && <BarDismiss tight />}
    </div>
  </div>;

const FzSuggest = ({ name }) =>
<div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
    <div style={{ position: 'relative' }}>
      <FzIcon name={name} size={60} />
      <span style={{ position: 'absolute', right: -6, top: -6, width: 24, height: 24, boxSizing: 'border-box', borderRadius: '50%', background: ACC, border: '2px solid ' + WHITE, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic n="add" style={{ fontSize: 15, color: '#fff' }} /></span>
    </div>
    <span style={{ fontSize: 13, fontWeight: 600, color: MED }}>{name}</span>
  </div>;

const FzField = ({ label, children, style }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 52, background: BG, borderRadius: 26, padding: '0 12px 0 16px', ...style }}>
    <span style={{ flex: 1, fontSize: 17, fontWeight: 500 }}>{label}</span>
    {children}
  </div>;
const FzChev = () => <Ic n="chevron_right" style={{ fontSize: 20, color: DIM }} />;
const FzChoice = ({ children, on }) =>
<div style={{ height: 36, boxSizing: 'border-box', borderRadius: 18, padding: '0 14px', display: 'flex', alignItems: 'center', fontSize: 15, fontWeight: 600, background: on ? INK : BG, color: on ? '#fff' : TEXT, whiteSpace: 'nowrap', cursor: 'pointer' }}>{children}</div>;
const FzToggleRow = ({ title, sub, on, style }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 60, boxSizing: 'border-box', background: BG, borderRadius: 26, padding: '10px 14px 10px 16px', ...style }}>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 17, fontWeight: 500 }}>{title}</div>
      <div style={{ fontSize: 15, color: MED, marginTop: 1, lineHeight: 1.3 }}>{sub}</div>
    </div>
    <Toggle on={on} />
  </div>;
const FzSheetTitle = ({ children }) =>
<div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 6 }}>
    <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800, lineHeight: 1.25 }}>{children}</div>
    <BarDismiss tight />
  </div>;

const FzIceBlock = ({ size = 104 }) =>
<div style={{ position: 'relative', width: size, height: size, ...fzMask, background: `linear-gradient(160deg, ${IS_DARK ? 'rgba(255,255,255,0.10)' : '#ffffff'} 0%, ${ACCL} 100%)`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <CubeSVG size={Math.round(size * 0.62)} tone={CUBE_TONES[4]} melt={0} expr="happy" cheeks bubbles={0} />
    <Ic n="freeze" style={{ position: 'absolute', top: 9, right: 10, fontSize: 17, color: ACC }} />
  </div>;


/* ── First run ─────────────────────────────────────────────────────────── */

const FZ_INTRO = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 20px' }}>
      <BackBtn style={{ marginBottom: 10 }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 20 }}><FzIceBlock /></div>
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, letterSpacing: -0.4, lineHeight: 1.15, textAlign: 'center', marginBottom: 8 }}>App freeze</div>
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, textAlign: 'center', textWrap: 'pretty', marginBottom: 24 }}>Freeze the apps that pull you away.</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <FzClaim icon="ac_unit" title="Freeze now, or with a frost" body="For this session, or on a schedule." />
          <FzClaim icon="thaw" title="Thawing takes a breath" body="Wait 10 seconds. Get 2–15 minutes." />
          <FzClaim icon="visibility_off" title="We never see your picks" body="Your list stays on this phone." />
        </div>
      </div>
      <FzBtn style={{ marginBottom: 12 }}>Set up App freeze</FzBtn>
      <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 600, color: MED, cursor: 'pointer' }}>Not now</div>
    </div>
  </Phone>;

const FZ_PERM_IOS = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 20px' }}>
      <BackBtn style={{ marginBottom: 16 }} />
      <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.2, marginBottom: 8 }}>Screen Time does<br />the freezing</div>
      <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginBottom: 22 }}>iOS asks once. Your picks stay on this phone.</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 20 }}>
        <FzClaim icon="check_circle_outline" title="What it can do" body="Freeze and unfreeze your picks on time." tone={SUCC} />
        <FzClaim icon="hidden" title="What it can't do" body="See, log or sync your picks." tone={MED} />
        <FzClaim icon="schedule" title="It keeps time without us" body="Frosts run even when Aqademiq is closed." />
      </div>
      <div style={{ flex: 1 }}></div>
      <FzBtn style={{ marginBottom: 12 }}>Continue</FzBtn>
      <div style={{ textAlign: 'center', fontSize: 13, color: DIM }}>iOS will ask on the next screen</div>
    </div>
  </Phone>;

const FZ_PERM_ANDROID = () => {
  const grants = [['Usage access', 'Shows which app is open.', true], ['Display over other apps', 'Puts the frozen screen on top.', false]];
  return (
    <Phone bg={WHITE}>
      <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 20px' }}>
        <BackBtn style={{ marginBottom: 16 }} />
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.3, lineHeight: 1.2, marginBottom: 8 }}>Two permissions,<br />then you're set</div>
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginBottom: 20 }}>Grant both in Settings. We'll bring you back.</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
          {grants.map(([t, s, done], i) =>
          <div key={t} style={{ display: 'flex', gap: 12, alignItems: 'center', minHeight: 64, boxSizing: 'border-box', background: done ? ACCL : BG, border: `1.5px solid ${done ? ACC + '55' : 'transparent'}`, borderRadius: 26, padding: '10px 16px' }}>
              <div style={{ width: 30, height: 30, borderRadius: '50%', background: done ? ACC : WHITE, boxShadow: done ? 'none' : SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 15, fontWeight: 800, color: done ? '#fff' : TEXT }}>
                {done ? <Ic n="check" style={{ fontSize: 18 }} /> : i + 1}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: 600 }}>{t}</div>
                <div style={{ fontSize: 15, color: MED, lineHeight: 1.33, marginTop: 1 }}>{s}</div>
              </div>
              {!done && <span style={{ fontSize: 17, fontWeight: 600, color: ACC, flexShrink: 0 }}>Grant</span>}
            </div>
          )}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, background: BG, borderRadius: 26, padding: '14px 16px' }}>
          <div style={{ display: 'flex', gap: 9, alignItems: 'flex-start' }}>
            <Ic n="shield" style={{ fontSize: 17, color: SUCC, flexShrink: 0 }} />
            <span style={{ flex: 1, fontSize: 13, color: TEXT, lineHeight: 1.5 }}>We never read your screen.</span>
          </div>
        </div>
        <div style={{ flex: 1 }}></div>
        <FzBtn>Open system settings</FzBtn>
      </div>
    </Phone>);
};

const FZ_PERM_BATTERY = () =>
<FzOver under={<><FzHubBody empty /><BNav active={2} /></>}>
    <FzSheetTitle>Your battery manager can stop App freeze</FzSheetTitle>
    <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginBottom: 16 }}>Some phones close background apps. Frosts stop with them.</div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: BG, borderRadius: 26, padding: '13px 16px', marginBottom: 18 }}>
      <Ic n="battery" style={{ fontSize: 22, color: WARN, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 800 }}>Aqademiq · Battery</div>
        <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>Restricted by your phone</div>
      </div>
      <span style={{ background: WARN, color: '#fff', borderRadius: 100, padding: '4px 9px', fontSize: 11, fontWeight: 800, letterSpacing: '0.04em', flexShrink: 0 }}>FIX</span>
    </div>
    <FzBtn style={{ marginBottom: 14 }}>Open battery settings</FzBtn>
    <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 600, color: MED, cursor: 'pointer' }}>Leave it as it is</div>
  </FzOver>;

const FZ_PERM_DENIED = () =>
<Phone bg={WHITE}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', padding: '4px 22px 20px' }}>
      <BackBtn style={{ marginBottom: 10 }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <CubeSVG size={64} tone={CUBE_TONES[1]} melt={0.25} expr="happy" mouth="sad" bubbles={1} />
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.3, marginTop: 16, marginBottom: 8 }}>App freeze is off</div>
        <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, textWrap: 'pretty', maxWidth: 300 }}>Nothing freezes without Screen Time.</div>
      </div>
      <FzBtn ghost style={{ marginBottom: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7 }}>
        <Ic n="freeze" style={{ fontSize: 18, color: ACC }} />Turn it on
      </FzBtn>
      <div style={{ textAlign: 'center', fontSize: 13, color: DIM, lineHeight: 1.5 }}>Find it anytime in Settings → App freeze.</div>
    </div>
  </Phone>;


/* ── The hub, and freezing ─────────────────────────────────────────────── */

const FZ_HUB_EMPTY = () => <Phone><FzHubBody empty /><BNav active={2} /></Phone>;
const FZ_HUB = () => <Phone><FzHubBody /><BNav active={2} /></Phone>;
const FZ_HUB_STANDDOWN = () => <Phone><FzHubBody standdown /><BNav active={2} /></Phone>;

// Freeze now = a one-off session frost. Its default length is the focus
// session it was opened from, so the common case is one tap.
const FZ_SESSION = () =>
<FzOver under={<><FzHubBody empty /><BNav active={2} /></>}>
    <FzSheetHead title="Freeze now" />
    <FzField label="Freezes"><FzStack apps={['Instagram', 'TikTok', 'YouTube']} more={3} edge={BG} /><FzChev /></FzField>
    <div style={{ fontSize: 15, fontWeight: 800, margin: '18px 2px 10px' }}>For how long</div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
      <FzChoice on>This session · 25 min</FzChoice>
      <FzChoice>1 hr</FzChoice>
      <FzChoice>2 hr</FzChoice>
      <FzChoice>Until I stop</FzChoice>
    </div>
    <FzToggleRow title="Deep freeze" sub="No thawing until it ends" style={{ marginTop: 18 }} />
    <div style={{ fontSize: 13, color: MED, textAlign: 'center', margin: '16px 0 12px' }}>Thaws when your focus session ends · 3:25 PM</div>
    <FzBtn>Freeze 6 apps</FzBtn>
    <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 800, color: ACC, marginTop: 14, cursor: 'pointer' }}>Save as a frost</div>
  </FzOver>;

const FZ_SELECT = () =>
<FzOver under={<><FzHubBody empty /><BNav active={2} /></>}>
    <FzSheetHead title="Selected" right={<span style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: ACC, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n="check" style={{ fontSize: 24, color: '#fff' }} /></span>} />
    <FzSeg options={['Freeze these', 'Keep only these']} />
    <div style={{ background: BG, borderRadius: 26, padding: '0 16px' }}>
      <FzRow add />
      {['Instagram', 'TikTok', 'YouTube'].map((n, i, a) => <FzRow key={n} name={n} last={i === a.length - 1} />)}
    </div>
    <div style={{ fontFamily: SANS, fontSize: 15, fontWeight: 800, margin: '20px 4px 12px' }}>Suggested</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', justifyItems: 'center' }}>{['Reddit', 'Netflix', 'X', 'Snapchat'].map((n) => <FzSuggest key={n} name={n} />)}</div>
  </FzOver>;

const FZ_SELECT_KEEP = () =>
<FzOver under={<><FzHubBody empty /><BNav active={2} /></>}>
    <FzSheetHead title="Selected" right={<span style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: ACC, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n="check" style={{ fontSize: 24, color: '#fff' }} /></span>} />
    <FzSeg options={['Freeze these', 'Keep only these']} on={1} />
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', background: ACCL, borderRadius: 26, padding: '13px 16px', marginBottom: 10 }}>
      <Ic n="freeze" style={{ fontSize: 18, color: ACC, flexShrink: 0 }} />
      <span style={{ fontSize: 13, color: TEXT, lineHeight: 1.5 }}>Everything else freezes, new apps too.</span>
    </div>
    <div style={{ background: BG, borderRadius: 26, padding: '0 16px' }}>
      <FzRow add />
      {['Notion', 'Canvas', 'Spotify'].map((n, i, a) => <FzRow key={n} name={n} last={i === a.length - 1} />)}
    </div>
  </FzOver>;

// iOS only: picking goes through Apple's own list. Our one line above it is
// the privacy claim, said at the moment someone wonders who will see this.
const FZ_PICKER = ({ dots }) => {
  const rows = [['Social', '3 apps', true], ['Games', 'All', true], ['Entertainment', '', false], ['Shopping', '', false], ['Information & Reading', '', false]];
  return (
    <Phone bg={PAGE}>
      <div style={{ height: 816, position: 'relative' }}>
        <div style={{ padding: '6px 18px 0' }}>
          {dots}
          <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, letterSpacing: -0.3, marginBottom: 6 }}>Choose what freezes.</div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginBottom: 14, textWrap: 'pretty' }}>We never see what you pick.</div>
          <div style={{ background: ACCL, borderRadius: 26, padding: '14px 16px' }}>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.09em', color: ACC, marginBottom: 8 }}>ALWAYS OPEN · NEVER FROZEN</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {FZ_FLOOR.map((a) => <span key={a} style={{ background: WHITE, borderRadius: 100, padding: '5px 11px', fontSize: 13, fontWeight: 700, color: TEXT }}>{a}</span>)}
            </div>
          </div>
        </div>
        {/* Apple's sheet, in Apple's chrome - deliberately not our design */}
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 540, background: '#f2f2f7', borderRadius: '14px 14px 0 0', boxShadow: '0 -8px 40px rgba(0,0,0,0.20)', fontFamily: SYSFONT, overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 16px 12px' }}>
            <span style={{ fontSize: 17, color: '#007aff' }}>Cancel</span>
            <span style={{ fontSize: 17, fontWeight: 600, color: '#000' }}>Choose Activities</span>
            <span style={{ fontSize: 17, fontWeight: 600, color: '#007aff' }}>Done</span>
          </div>
          <div style={{ padding: '0 16px 12px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, height: 36, background: '#e3e3e8', borderRadius: 10, padding: '0 9px' }}>
              <span className="material-icons-outlined" style={{ fontSize: 19, color: '#8e8e93' }}>search</span>
              <span style={{ fontSize: 17, color: '#8e8e93' }}>Search</span>
            </div>
          </div>
          <div style={{ margin: '0 16px', background: '#fff', borderRadius: 12, overflow: 'hidden' }}>
            {rows.map(([name, sel, on], i) =>
            <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 52, padding: '0 14px', borderTop: i ? '0.5px solid #e5e5ea' : 'none' }}>
                <span className="material-icons-outlined" style={{ fontSize: 23, color: on ? '#007aff' : '#c7c7cc' }}>{on ? 'check_circle' : 'radio_button_unchecked'}</span>
                <span style={{ flex: 1, fontSize: 17, color: '#000' }}>{name}</span>
                <span style={{ fontSize: 15, color: '#8e8e93' }}>{sel}</span>
                <span className="material-icons-outlined" style={{ fontSize: 20, color: '#c7c7cc' }}>chevron_right</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </Phone>);
};


/* ── Onboarding · App freeze (Steps 5–7) ──────────────────────────────── */
// Two frosts from Step 5: Study hours on the picked days, and Wellness time
// (9 AM – noon) on every day left over. All 7 picked → no Wellness time.
const OB_DAY3 = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const OB_STUDY = [0, 1, 2, 3, 4];
const OB_STUDY_CUSTOM = [0, 1, 3, 4];
const OB_STUDY_ALL = [0, 1, 2, 3, 4, 5, 6];
const obRest = (study) => [0, 1, 2, 3, 4, 5, 6].filter((i) => !study.includes(i));
const obRun = (s) => s.length > 1 && s[s.length - 1] - s[0] === s.length - 1;
const obDays = (idx) => obRun(idx) ? `${OB_DAY3[idx[0]]}–${OB_DAY3[idx[idx.length - 1]]}` : idx.map((i) => OB_DAY3[i]).join(', ');
const obDaysProse = (idx) => {const n = idx.map((i) => OB_DAY3[i]);return n.length < 2 ? n[0] : obRun(idx) && n.length > 2 ? `${n[0]} to ${n[n.length - 1]}` : n.slice(0, -1).join(', ') + ' and ' + n[n.length - 1];};
const obFrosts = (study) => {const rest = obRest(study);return [...(rest.length ? [{ name: 'Wellness time', days: obDays(rest), when: '9 AM – 12 PM' }] : []), { name: 'Study hours', days: obDays(study), when: '9 AM – 1 PM' }];};
const ObFrostList = ({ study = OB_STUDY }) =>
<div style={{ background: BG, borderRadius: 26, padding: '0 16px', marginBottom: 18 }}>
    {obFrosts(study).map((f, i) =>
  <div key={f.name} style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 64, borderTop: i ? `1px solid ${BORDER}` : 'none' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 17, fontWeight: 600 }}>{f.name}</div>
          <div style={{ fontSize: 15, color: MED, marginTop: 1 }}>{f.days} · {f.when}</div>
        </div>
        <FzTrigger type="schedule" live size={20} />
      </div>
  )}
  </div>;

const ObLink = ({ children }) => <div style={{ textAlign: 'center', fontSize: 15, color: MED, fontWeight: 600, marginTop: 12, cursor: 'pointer' }}>{children}</div>;

const OB_HOURS = ({ study = OB_STUDY }) => {
  const rest = obRest(study);
  const dayLabel = rest.length === 0 ? 'Every day' : study.join() === OB_STUDY.join() ? 'Weekdays' : obDays(study);
  return (
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={7} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>When are your<br />study hours?</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 18 }}>Classes, lectures or set study time. We'll freeze distractions then.</div>
      <div style={{ background: BG, borderRadius: 26, padding: '14px 16px 16px', marginBottom: 8 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 12 }}>
          <span style={{ fontSize: 17, fontWeight: 500 }}>On these days</span>
          <span style={{ fontSize: 15, color: MED }}>{dayLabel}</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          {FZ_DAYS.map((d, i) => <div key={i} style={{ width: 38, height: 38, borderRadius: '50%', background: study.includes(i) ? ACC : WHITE, color: study.includes(i) ? '#fff' : MED, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 800, cursor: 'pointer' }}>{d}</div>)}
        </div>
      </div>
      <div style={{ background: BG, borderRadius: 26, padding: '0 12px 0 16px', marginBottom: 14 }}>
        {[['From', '9:00 AM'], ['Until', '1:00 PM']].map(([k, v], i) =>
      <div key={k} style={{ display: 'flex', alignItems: 'center', minHeight: 52, borderTop: i ? `1px solid ${BORDER}` : 'none' }}>
            <span style={{ flex: 1, fontSize: 17, fontWeight: 500 }}>{k}</span>
            <span style={{ height: 34, display: 'flex', alignItems: 'center', background: WHITE, borderRadius: 17, padding: '0 12px', fontSize: 15, fontWeight: 700, cursor: 'pointer' }}>{v}</span>
          </div>
      )}
      </div>
      <Card style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginBottom: 20, background: ACCL, boxShadow: 'none' }}>
        <AdaBlob size={28} mood="happy" />
        <span style={{ fontSize: 15, color: TEXT, lineHeight: 1.6 }}>App freeze blocks distracting apps during these hours. Thawing unblocks one when you really need it. {rest.length ? `${obDaysProse(rest)} ${rest.length > 1 ? 'get' : 'gets'} Wellness time, frozen 9 AM to noon.` : 'Every day is a study day, so no Wellness time.'}</span>
      </Card>
      <PBtn>Continue →</PBtn>
      <ObLink>I don't have set hours</ObLink>
    </div>
  </Phone>);
};

const ObGrants = ({ done = 1 }) =>
<div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
    {[['Usage access', 'Shows which app is open.'], ['Display over other apps', 'Puts the frozen screen on top.']].map(([t, sub], i) => {
    const ok = i < done;
    return (
      <div key={t} style={{ display: 'flex', gap: 12, alignItems: 'center', minHeight: 64, boxSizing: 'border-box', background: ok ? ACCL : BG, border: `1.5px solid ${ok ? ACC + '55' : 'transparent'}`, borderRadius: 26, padding: '10px 16px' }}>
          <div style={{ width: 30, height: 30, borderRadius: '50%', background: ok ? ACC : WHITE, boxShadow: ok ? 'none' : SHADOW, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 15, fontWeight: 800, color: ok ? '#fff' : TEXT }}>{ok ? <Ic n="check" style={{ fontSize: 18 }} /> : i + 1}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 600 }}>{t}</div>
            <div style={{ fontSize: 15, color: MED, lineHeight: 1.33, marginTop: 1 }}>{sub}</div>
          </div>
          {!ok && <span style={{ fontSize: 17, fontWeight: 600, color: ACC, flexShrink: 0 }}>Grant</span>}
        </div>);
  })}
  </div>;

// iOS: one Screen Time ask, then Apple's picker. Android: two grants in Settings, then our list.
const OB_FREEZE = ({ os = 'ios', study = OB_STUDY }) => {
  const android = os === 'android';
  const ready = obRest(study).length ? 'Two frosts are ready.' : 'One frost is ready.';
  return (
    <Phone bg={WHITE}>
      <div style={{ padding: '4px 22px 0', height: 792 }}>
        <Dots total={11} active={8} />
        <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>Freeze what<br />pulls you away</div>
        <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 18 }}>{android ? `${ready} Android needs two permissions to run them.` : `${ready} iOS asks once for Screen Time to run them.`}</div>
        <ObFrostList study={study} />
        {android ?
        <>
            <ObGrants />
            <div style={{ display: 'flex', gap: 9, alignItems: 'center', padding: '0 4px', marginBottom: 22 }}>
              <Ic n="shield" style={{ fontSize: 17, color: SUCC, flexShrink: 0 }} />
              <span style={{ fontSize: 13, color: MED, lineHeight: 1.5 }}>We never read your screen.</span>
            </div>
          </> :
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 24 }}>
            <FzClaim icon="hidden" title="We never see your picks" body="Your list stays on this phone." tone={MED} />
            <FzClaim icon="schedule" title="Runs without us" body="Frosts start even when Aqademiq is closed." />
          </div>}
        <PBtn>{android ? 'Open system settings' : 'Turn on App freeze'}</PBtn>
        <ObLink>Not now</ObLink>
      </div>
    </Phone>);
};

const ObAppTile = ({ name, on }) =>
<div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
    <div style={{ position: 'relative', opacity: on ? 1 : 0.5 }}>
      <FzIcon name={name} size={60} />
      <span style={{ position: 'absolute', right: -6, top: -6, width: 24, height: 24, boxSizing: 'border-box', borderRadius: '50%', background: on ? ACC : WHITE, border: `2px solid ${on ? WHITE : BORDER}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{on && <Ic n="check" style={{ fontSize: 15, color: '#fff' }} />}</span>
    </div>
    <span style={{ fontSize: 13, fontWeight: 600, color: on ? TEXT : MED }}>{name}</span>
  </div>;

const OB_APPS_ANDROID = () =>
<Phone bg={WHITE}>
    <div style={{ padding: '4px 22px 0', height: 792 }}>
      <Dots total={11} active={9} />
      <div style={{ fontFamily: SANS, fontSize: 34, fontWeight: 800, lineHeight: 1.2, marginBottom: 4 }}>Pick what<br />freezes</div>
      <div style={{ fontSize: 17, color: MED, lineHeight: 1.6, marginBottom: 20 }}>We ticked the usual suspects. Tap to change.</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', justifyItems: 'center', rowGap: 18, marginBottom: 18 }}>
        {[['Instagram', 1], ['TikTok', 1], ['YouTube', 1], ['Snapchat', 1], ['Reddit', 1], ['X', 1], ['Netflix', 0], ['Discord', 0]].map(([a, on]) => <ObAppTile key={a} name={a} on={!!on} />)}
      </div>
      <FzField label="All apps" style={{ marginBottom: 10 }}><FzChev /></FzField>
      <div style={{ background: ACCL, borderRadius: 26, padding: '14px 16px', marginBottom: 22 }}>
        <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.09em', color: ACC, marginBottom: 8 }}>ALWAYS OPEN · NEVER FROZEN</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>{FZ_FLOOR.map((a) => <span key={a} style={{ background: WHITE, borderRadius: 100, padding: '5px 11px', fontSize: 13, fontWeight: 700, color: TEXT }}>{a}</span>)}</div>
      </div>
      <PBtn>Freeze 6 apps</PBtn>
    </div>
  </Phone>;

/* ── Thawing ───────────────────────────────────────────────────────────── */

// The breath. Reached from a frozen tile's "Thaw", or from the shield. The
// way out is always there; it just costs ten seconds of watching ice melt.
const FZ_THAW_PAUSE = ({ left = 7, total = 10, note }) =>
<Phone bg={FROST_BG}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '0 22px 22px', textAlign: 'center' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <IceTimer progress={1 - left / total} size={150} drip />
        <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 800, color: FROST_INK, marginTop: 22 }}>Take a breath.</div>
        <div style={{ fontSize: 15, fontWeight: 600, color: FROST_SUB, lineHeight: 1.5, marginTop: 6, maxWidth: 270 }}>Still want Instagram in {left} seconds?</div>
        {note && <div style={{ marginTop: 16, minHeight: 32, display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(255,255,255,0.72)', borderRadius: 16, padding: '0 12px', fontSize: 13, fontWeight: 700, color: FROST_INK }}><Ic n="shield" style={{ fontSize: 16, color: ACC }} />{note}</div>}
      </div>
      <div style={{ position: 'relative', width: '100%', height: 50, borderRadius: 25, background: 'rgba(255,255,255,0.5)', overflow: 'hidden', marginBottom: 16 }}>
        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: Math.round((1 - left / total) * 100) + '%', background: 'rgba(255,255,255,0.8)' }}></div>
        <div style={{ position: 'relative', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 600, color: FROST_SUB }}>Thaw in {left}s</div>
      </div>
      <div style={{ fontSize: 15, fontWeight: 700, color: FROST_INK, cursor: 'pointer' }}>Keep it frozen</div>
    </div>
  </Phone>;

// Increasing resistance: a later thaw the same day waits longer. Seconds only, never a count.
const FZ_THAW_PAUSE_MORE = () => <FZ_THAW_PAUSE left={27} total={30} note="Each thaw today waits a little longer" />;

const FzStep = ({ icon }) =>
<div style={{ width: HEAD_BTN, height: HEAD_BTN, borderRadius: '50%', background: 'rgba(255,255,255,0.88)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, cursor: 'pointer' }}>
    <Ic n={icon} style={{ fontSize: 22, color: FROST_INK }} />
  </div>;

const FZ_THAW_MINUTES = () =>
<Phone bg={FROST_BG}>
    <div style={{ height: 792, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '0 22px 22px', textAlign: 'center' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 22 }}>
          <FzIcon name="Instagram" size={40} />
          <span style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800, color: FROST_INK }}>Thaw Instagram for</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
          <FzStep icon="remove" />
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 6, minWidth: 112 }}>
            <span style={{ fontFamily: '"Plus Jakarta Sans"', fontSize: 64, fontWeight: 800, color: FROST_INK, lineHeight: 1 }}>5</span>
            <span style={{ fontSize: 17, fontWeight: 700, color: FROST_SUB }}>min</span>
          </div>
          <FzStep icon="add" />
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 24 }}>
          {[2, 5, 10, 15].map((m) =>
          <div key={m} style={{ height: 36, minWidth: 58, boxSizing: 'border-box', borderRadius: 18, padding: '0 14px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 800, background: m === 5 ? INK : 'rgba(255,255,255,0.88)', color: m === 5 ? '#fff' : FROST_INK, cursor: 'pointer' }}>{m} min</div>
          )}
        </div>
      </div>
      <FzBtn style={{ marginBottom: 16 }}>Thaw for 5 min</FzBtn>
      <div style={{ fontSize: 15, fontWeight: 700, color: FROST_INK, cursor: 'pointer' }}>Keep it frozen</div>
    </div>
  </Phone>;

const FZ_THAWED = () =>
<Phone>
    <FzHubBody thawed />
    <div style={{ position: 'absolute', left: 16, right: 16, bottom: 112, background: INK, borderRadius: 26, minHeight: 52, boxSizing: 'border-box', padding: '12px 14px 12px 16px', display: 'flex', alignItems: 'center', gap: 10, boxShadow: '0 10px 30px rgba(0,0,0,0.22)' }}>
      <Ic n="check_circle:fill" style={{ fontSize: 19, color: '#fff' }} />
      <span style={{ flex: 1, fontSize: 15, fontWeight: 700, color: '#fff' }}>Instagram thawed · refreezes 3:47</span>
      <span style={{ fontSize: 15, fontWeight: 800, color: '#cfc8ff', cursor: 'pointer' }}>Refreeze</span>
    </div>
    <BNav active={2} />
  </Phone>;

// Deep freeze: the deal holds. Says when it ends and what still works, and
// offers the one useful action - going back to the work.
const FZ_DEEP = () =>
<FzOver>
    <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 2 }}><BarDismiss tight /></div>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
      <div style={{ width: 56, height: 56, borderRadius: '50%', background: ACCL, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}><Ic n="never_open" style={{ fontSize: 28, color: ACC }} /></div>
      <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 800 }}>Deep freeze until 1:00 PM</div>
      <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginTop: 6, maxWidth: 300, textWrap: 'pretty' }}>No thawing during Lecture hours. Back in 1h 40m.</div>
    </div>
    <div style={{ background: BG, borderRadius: 26, padding: '14px 16px', margin: '18px 0' }}>
      <div style={{ fontSize: 13, fontWeight: 800, color: MED, marginBottom: 10 }}>Still open, always</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px 16px' }}>
        {FZ_FLOOR.map((n) => <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 7 }}><FzIcon name={n} size={30} /><span style={{ fontSize: 15, fontWeight: 600 }}>{n}</span></div>)}
      </div>
    </div>
    <FzBtn style={{ marginBottom: 12 }}>Back to focus</FzBtn>
    <div style={{ textAlign: 'center', fontSize: 13, color: DIM }}>Changes to this frost unlock at 1:00 PM</div>
  </FzOver>;


/* ── Frosts ────────────────────────────────────────────────────────────── */

const FZ_NEW = () =>
<FzOver>
    <FzSheetHead title="New frost" mb={18} />
    <div style={{ display: 'flex', gap: 8 }}>
      {[['timer', 'Session', 'e.g. 30m or until I stop'], ['calendar_month', 'Schedule', 'e.g. 9–5, weekdays']].map(([ic, t, s]) =>
    <div key={t} style={{ flex: 1, minHeight: 132, boxSizing: 'border-box', background: BG, borderRadius: 30, padding: '16px 16px 16px 18px', display: 'flex', flexDirection: 'column', cursor: 'pointer' }}>
          <Ic n={ic} style={{ fontSize: 26, color: ACC }} />
          <div style={{ flex: 1 }}></div>
          <div style={{ fontSize: 20, fontWeight: 700 }}>{t}</div>
          <div style={{ fontSize: 15, color: MED, lineHeight: 1.3, marginTop: 2 }}>{s}</div>
        </div>
    )}
    </div>
    <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 700, marginTop: 26 }}>Student frosts</div>
    <div style={{ fontSize: 15, color: MED, marginTop: 2, marginBottom: 14 }}>Start from one. Change anything.</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) minmax(0,1fr)', gap: 8 }}>{FZ_TEMPLATES.map((t) => <FzTemplate key={t[1]} t={t} well />)}</div>
  </FzOver>;

const FZ_DAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const FzEditBody = () =>
<>
    <FzSheetHead back title="Lecture hours" editable right={<BarPill fill="ink" label="Save" />} />
    <FzField label="Freezes"><FzStack apps={['Instagram', 'TikTok', 'YouTube']} more={3} edge={BG} /><FzChev /></FzField>
    <div style={{ background: BG, borderRadius: 26, padding: '0 12px 0 16px', marginTop: 8 }}>
      {[['From', '9:00 AM'], ['Until', '1:00 PM']].map(([k, v], i) =>
    <div key={k} style={{ display: 'flex', alignItems: 'center', minHeight: 52, borderTop: i ? `1px solid ${BORDER}` : 'none' }}>
          <span style={{ flex: 1, fontSize: 17, fontWeight: 500 }}>{k}</span>
          <span style={{ height: 34, display: 'flex', alignItems: 'center', background: WHITE, borderRadius: 17, padding: '0 12px', fontSize: 15, fontWeight: 700, cursor: 'pointer' }}>{v}</span>
        </div>
    )}
    </div>
    <div style={{ background: BG, borderRadius: 26, padding: '14px 16px 16px', marginTop: 8 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 12 }}>
        <span style={{ fontSize: 17, fontWeight: 500 }}>On these days</span>
        <span style={{ fontSize: 15, color: MED }}>Weekdays</span>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        {FZ_DAYS.map((d, i) =>
      <div key={i} style={{ width: 38, height: 38, borderRadius: '50%', background: i < 5 ? ACC : WHITE, color: i < 5 ? '#fff' : MED, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 800, cursor: 'pointer' }}>{d}</div>
      )}
      </div>
    </div>
    <FzToggleRow title="Deep freeze" sub="No thawing while it runs" style={{ marginTop: 8 }} />
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: 20, color: FZ_DANGER, fontSize: 15, fontWeight: 800, cursor: 'pointer' }}>
      <Ic n="delete" style={{ fontSize: 18 }} />Delete frost
    </div>
  </>;

const FZ_EDIT = () => <FzOver><FzEditBody /></FzOver>;

const FZ_EDIT_TIME = () =>
<FzOver after={<>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,15,28,0.36)' }}></div>
      <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: 268, background: WHITE, borderRadius: 34, boxShadow: '0 20px 64px rgba(0,0,0,0.34)', padding: '17px 18px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 3 }}>
          <div style={{ fontFamily: SANS, fontSize: 20, fontWeight: 700, whiteSpace: 'nowrap' }}>Starts at</div>
          <BarDismiss tight />
        </div>
        <div style={{ fontSize: 13, color: MED, marginBottom: 14 }}>Lecture hours freezes from here</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1, position: 'relative' }}>
            <div style={{ position: 'absolute', top: '50%', left: -2, right: -2, transform: 'translateY(-50%)', height: 36, background: ACCL, borderRadius: 8 }}></div>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <TimeWheelCol rows={[{ t: '8' }, { t: '9', sel: true }, { t: '10' }]} />
              <div style={{ fontSize: 20, fontWeight: 800, color: TEXT, paddingBottom: 2 }}>:</div>
              <TimeWheelCol rows={[{ t: '45' }, { t: '00', sel: true }, { t: '15' }]} />
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div style={{ height: 32, minWidth: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 16, background: ACC, color: '#fff', fontSize: 15, fontWeight: 600 }}>AM</div>
            <div style={{ height: 32, minWidth: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 16, background: BG, color: MED, fontSize: 15, fontWeight: 600 }}>PM</div>
          </div>
        </div>
        <div style={{ marginTop: 16, background: INK, borderRadius: 100, padding: '13px 0', textAlign: 'center', fontSize: 15, fontWeight: 800, color: '#fff' }}>Set · 9:00 AM</div>
      </div>
    </>}>
    <FzEditBody />
  </FzOver>;

const FZ_NAME = () =>
<FzOver lift={IOS_KB_H} pad="6px 16px 20px" after={<IOSKeyboard words={['“hours”', 'hour', 'Hours']} />}>
    <FzSheetHead back title="Name this frost" right={<BarPill fill="ink" label="Save" />} />
    <div style={{ height: 52, boxSizing: 'border-box', background: BG, borderRadius: 26, padding: '0 16px', display: 'flex', alignItems: 'center', fontSize: 15, fontWeight: 600 }}>
      Lecture hours<span style={{ width: 2, height: 22, background: ACC, marginLeft: 1, borderRadius: 1 }}></span>
    </div>
    <div style={{ fontSize: 13, color: MED, margin: '10px 2px 0' }}>Shown on the frozen screen.</div>
  </FzOver>;

// A running frost, opened from its card.
const FZ_ACTIVE = () =>
<FzOver>
    <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
      <BarDismiss edge="left" />
      <div style={{ position: 'absolute', left: '50%', top: 0, transform: 'translateX(-50%)', height: 46, display: 'flex', alignItems: 'center', padding: '0 18px', borderRadius: 23, background: ACCL }}><FzTrigger live /></div>
      <BarPill fill="well" label="Edit" />
    </div>
    <div style={{ textAlign: 'center', marginTop: 22 }}>
      <div style={{ fontSize: 15, fontWeight: 600, color: ACC }}>Schedule, 1h 40m left</div>
      <div style={{ fontFamily: SANS, fontSize: 28, fontWeight: 700, letterSpacing: -0.3, marginTop: 2 }}>Lecture hours</div>
    </div>
    <div style={{ background: BG, borderRadius: 30, padding: '16px 18px 14px', marginTop: 20 }}>
      <div style={{ fontSize: 17, fontWeight: 600, marginBottom: 12 }}>Frozen</div>
      <div style={{ display: 'flex', gap: 18 }}>
        <FzApp name="Instagram" state="frozen" />
        <FzApp name="TikTok" state="thawed" mins={13} progress={0.8} />
      </div>
    </div>
    <div style={{ background: BG, borderRadius: 30, padding: '0 18px', marginTop: 8 }}>
      {[['During this time', '9:00 AM – 1:00 PM'], ['On these days', 'Weekdays'], ['Deep freeze', 'Off']].map(([k, v], i) =>
    <div key={k} style={{ display: 'flex', alignItems: 'center', minHeight: 52, borderTop: i ? `1px solid ${BORDER}` : 'none' }}>
          <span style={{ flex: 1, fontSize: 17 }}>{k}</span>
          <span style={{ fontSize: 17, color: MED }}>{v}</span>
        </div>
    )}
    </div>
    <FzBtn style={{ marginTop: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7 }}>
      <Ic n="thaw" style={{ fontSize: 19 }} />Thaw apps
    </FzBtn>
    <div style={{ height: 44, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: 6, fontSize: 17, fontWeight: 600, cursor: 'pointer' }}>
      <Ic n="pause" style={{ fontSize: 19 }} />End early
    </div>
  </FzOver>;

const FZ_END = () =>
<FzOver>
    <FzSheetTitle>End Lecture hours for today?</FzSheetTitle>
    <div style={{ fontSize: 15, color: MED, lineHeight: 1.55, marginBottom: 20 }}>Apps unfreeze now. Back tomorrow at 9:00 AM.</div>
    <FzBtn style={{ marginBottom: 14 }}>End for today</FzBtn>
    <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 700, color: MED, cursor: 'pointer' }}>Keep it running</div>
  </FzOver>;


/* ── Groups ────────────────────────────────────────────────────────────── */

// iOS list anatomy: the group, then its explanation as a footer beneath it.
const FzGroupPage = ({ title, blurb, children }) =>
<Phone>
    <div style={{ padding: '0 16px', height: 742, overflow: 'hidden' }}>
      <FzPageHead title={title} />
      <div style={{ background: WHITE, borderRadius: 26, boxShadow: SHADOW, padding: '0 16px', marginTop: 18 }}>{children}</div>
      <div style={{ fontSize: 13, color: MED, lineHeight: 1.38, padding: '8px 16px 0', textWrap: 'pretty' }}>{blurb}</div>
    </div>
    <BNav active={2} />
  </Phone>;

const FZ_ALWAYS = () =>
<FzGroupPage title="Always open" blurb="Never frozen, by any frost.">
    <FzRow name="Phone" sub="Calls always get through" remove={false} />
    <FzRow name="Messages" />
    <FzRow name="Maps" />
    <FzRow name="Wallet" />
    <FzRow add last />
  </FzGroupPage>;

const FZ_NEVER = () =>
<FzGroupPage title="Never open" blurb="Frozen all the time. Thawing doesn't reach these.">
    <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
      <div style={{ width: 30, height: 30, ...fzMask, background: HILITE, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 13, fontWeight: 800, color: MED }}>18+</div>
      <div style={{ flex: 1, minWidth: 0, minHeight: 60, display: 'flex', alignItems: 'center', gap: 10, borderBottom: '1px solid ' + BORDER }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 600 }}>Adult sites</div>
          <div style={{ fontSize: 13, color: MED, marginTop: 1 }}>Every browser · private browsing off</div>
        </div>
        <Toggle />
      </div>
    </div>
    <FzRow add last />
  </FzGroupPage>;

const FZ_DISTRACT = () =>
<FzGroupPage title="Distracting" blurb="Never frozen. Ada checks in when you open one.">
    {['Instagram', 'YouTube', 'Reddit', 'Netflix', 'TikTok', 'X'].map((n) => <FzRow key={n} name={n} />)}
    <FzRow add last />
  </FzGroupPage>;


/* ─── 04-B · AMBIENT SURFACES ───────────────────────────────────────────
   The v1.2 Ambient Ada layout on the current pack. aq_cube_session IS the
   timer: trimmed to time left (Variable Draw, iOS 26+; static aq_cube_frozen
   below). Ice is pinned: --aq-ice on light grounds, --aq-ice-on-dark on black.
   aq_brand_ada for Ada, aq_brand_ada_mono for Android's small icon, OS chrome
   keeps OS glyphs. Freeze holds a session, as it does in the app. Island,
   StandBy and Watch are black in both appearances; the rest follows the theme. */
const LA_LEFT = 0.58, LA_TIME = '14:32'; // 14:32 left of a 25:00 Deep Work session
const LA_TASK = 'LL(1) parsing notes';
const LA_SUB = 'rgba(255,255,255,0.64)';
const laT = () => IS_DARK ? {
  wall: '#1b1824', wallInk: '#ffffff', wallSub: 'rgba(255,255,255,0.86)', chip: 'rgba(255,255,255,0.14)',
  plat: 'rgba(28,25,38,0.88)', platInk: '#ffffff', platSub: 'rgba(255,255,255,0.66)', ice: AQ_ICE_ON_DARK, well: 'rgba(255,255,255,0.10)', track: 'rgba(255,255,255,0.14)', btn: '#ffffff', btnInk: '#111111', lift: 'none',
  home: '#1d1a26', tile: 'rgba(255,255,255,0.10)', sysInk: '#ffffff', card: '#1c1c1e', cardInk: '#ffffff', cardSub: '#a1a1a8', sheet: '#141416', notif: 'rgba(38,35,48,0.86)', notifInk: '#ffffff', notifSub: 'rgba(235,235,245,0.62)'
} : {
  wall: '#d9d3e8', wallInk: '#1a1625', wallSub: 'rgba(26,22,37,0.74)', chip: 'rgba(255,255,255,0.5)',
  plat: 'rgba(255,255,255,0.82)', platInk: '#111111', platSub: '#5e5a6b', ice: AQ_ICE, well: '#ece9fb', track: 'rgba(0,0,0,0.08)', btn: '#111111', btnInk: '#ffffff', lift: '0 8px 30px rgba(40,30,70,0.12)',
  home: '#e6e3ee', tile: 'rgba(40,30,70,0.08)', sysInk: '#111111', card: '#ffffff', cardInk: '#111111', cardSub: '#6e6e73', sheet: '#f2f2f7', notif: 'rgba(255,255,255,0.82)', notifInk: '#111111', notifSub: '#5e5a6b'
};
const droidT = () => IS_DARK ?
{ shell: '#141218', card: '#2b2930', ink: '#e6e0e9', sub: '#cac4d0', ice: AQ_ICE_ON_DARK, onIce: '#1b1430', track: 'rgba(255,255,255,0.12)', line: 'rgba(255,255,255,0.08)' } :
{ shell: '#f3edf7', card: '#ffffff', ink: '#1d1b20', sub: '#49454f', ice: AQ_ICE, onIce: '#ffffff', track: 'rgba(0,0,0,0.08)', line: 'rgba(0,0,0,0.08)' };
const LA_LOGO = () => window.__resources && window.__resources.logo || 'assets/aqademiq-logo-opt.png';
const AqSvg = ({ html, size, style }) => <span style={{ display: 'inline-block', width: size, height: size, flexShrink: 0, lineHeight: 0, ...style }} dangerouslySetInnerHTML={{ __html: html }} />;
const SessionCube = ({ size, left = LA_LEFT, color = AQ_ICE_ON_DARK }) =>
<span style={{ position: 'relative', display: 'inline-block', width: size, height: size, flexShrink: 0, color }}>
    <AqSvg html={window.AQ.svg('cube_frozen')} size={size} style={{ position: 'absolute', inset: 0, opacity: 0.26 }} />
    <AqSvg html={window.AQ.svg('cube_session', { progress: left })} size={size} style={{ position: 'absolute', inset: 0 }} />
  </span>;
const BrandAda = ({ size, pose }) => {
  const p = pose && window.AQ.POSES.find((x) => x[0] === pose);
  return <AqSvg html={p ? window.AQ.adaPose(p[2]) : window.AQ.adaColor()} size={size} />;
};
const LaRail = ({ ice = AQ_ICE_ON_DARK, track = 'rgba(255,255,255,0.14)', frozen, style }) =>
<div style={{ height: 6, borderRadius: 3, background: track, overflow: 'hidden', ...style }}><div style={{ width: `${(1 - LA_LEFT) * 100}%`, height: '100%', borderRadius: 3, background: ice, opacity: frozen ? 0.5 : 1 }}></div></div>;
const LaShell = ({ bg, radius = 55, w = 402, h = 874, children }) =>
<div data-phone="1" style={{ width: w, height: h, borderRadius: radius, overflow: 'hidden', position: 'relative', background: bg, fontFamily: SYSFONT, flexShrink: 0, boxShadow: '0 14px 52px rgba(0,0,0,0.14), 0 0 0 1px rgba(0,0,0,0.06)' }}>{children}</div>;
const LaAppTile = ({ size = 40 }) =>
<div style={{ width: size, height: size, borderRadius: size * 0.24, background: '#fff', boxShadow: '0 0 0 0.5px rgba(0,0,0,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', flexShrink: 0 }}>
    <img src={LA_LOGO()} alt="Aqademiq" style={{ width: '86%', height: '86%', objectFit: 'contain' }} />
  </div>;
const LaPills = ({ items }) =>
<div style={{ display: 'flex', gap: 8 }}>
    {items.map(([ic, l]) =>
  <div key={l} style={{ flex: 1, height: 44, borderRadius: 22, background: 'rgba(255,255,255,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, fontSize: 15, fontWeight: 700, color: '#fff' }}><Ic n={ic} style={{ fontSize: 19, color: AQ_ICE_ON_DARK }} />{l}</div>
  )}
  </div>;

// Lock Screen accessories: focus today as a ring, the next block as a line.
const LaAccessories = () => {
  const t = laT();
  return (
    <div style={{ position: 'absolute', top: 226, left: 26, right: 26, display: 'flex', gap: 10, fontFamily: SANS, color: t.wallInk }}>
      <div style={{ width: 72, height: 72, borderRadius: '50%', background: t.chip, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <svg width="62" height="62" viewBox="0 0 62 62" style={{ position: 'absolute', transform: 'rotate(-90deg)' }}><circle cx="31" cy="31" r="27" fill="none" stroke="currentColor" strokeOpacity="0.22" strokeWidth="4"></circle><circle cx="31" cy="31" r="27" fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeDasharray="169.6" strokeDashoffset="59"></circle></svg>
        <span style={{ fontSize: 15, fontWeight: 800 }}>42m</span>
      </div>
      <div style={{ flex: 1, minWidth: 0, height: 72, boxSizing: 'border-box', borderRadius: 20, background: t.chip, padding: '0 14px', display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 1 }}>
        <span style={{ fontSize: 13, fontWeight: 700, color: t.wallSub }}>Next · 2:00 PM</span>
        <span style={{ fontSize: 15, fontWeight: 800, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>Networks revision</span>
      </div>
    </div>);
};
const LockPhone = ({ acc, children }) => {
  const t = laT();
  return (
    <LaShell bg={t.wall}>
      <div style={{ position: 'absolute', left: '50%', top: 11, marginLeft: -62, width: 124, height: 36, background: '#000', borderRadius: 20 }}></div>
      <span style={{ position: 'absolute', top: 20, right: 34, fontSize: 14, letterSpacing: -1, color: t.wallInk }}>●▊</span>
      <div style={{ textAlign: 'center', paddingTop: 74, color: t.wallInk }}>
        <div style={{ fontSize: 20, fontWeight: 600, color: t.wallSub }}>Wednesday 3 June</div>
        <div style={{ fontSize: 104, fontWeight: 700, lineHeight: 1, letterSpacing: -3, marginTop: 4 }}>9:41</div>
      </div>
      {acc && <LaAccessories />}
      {children}
      {[['flashlight_on', 'left'], ['photo_camera', 'right']].map(([ic, side]) =>
      <div key={ic} style={{ position: 'absolute', bottom: 44, [side]: 44, width: 50, height: 50, borderRadius: '50%', background: t.chip, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><span className="material-icons-outlined" style={{ fontSize: 22, color: t.wallInk }}>{ic}</span></div>
      )}
      <div style={{ position: 'absolute', bottom: 8, left: '50%', marginLeft: -67, width: 134, height: 5, borderRadius: 3, background: t.wallInk, opacity: 0.7 }}></div>
    </LaShell>);
};
const HomePhone = ({ icons = true, children }) => {
  const t = laT();
  return (
    <LaShell bg={t.home}>
      <span style={{ position: 'absolute', top: 18, left: 44, fontSize: 17, fontWeight: 600, color: t.sysInk }}>9:41</span>
      <span style={{ position: 'absolute', top: 20, right: 34, fontSize: 14, letterSpacing: -1, color: t.sysInk }}>●▊</span>
      {icons &&
      <div style={{ position: 'absolute', top: 92, left: 28, right: 28, display: 'grid', gridTemplateColumns: 'repeat(4, 62px)', justifyContent: 'space-between', rowGap: 32 }}>
          {Array.from({ length: 20 }, (_, i) => <div key={i} style={{ width: 62, height: 62, borderRadius: 15, background: t.tile }}></div>)}
        </div>}
      <div style={{ position: 'absolute', left: 14, right: 14, bottom: 14, height: 94, borderRadius: 38, background: IS_DARK ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'space-around', padding: '0 10px' }}>
        {[0, 1, 2, 3].map((i) => <div key={i} style={{ width: 62, height: 62, borderRadius: 15, background: t.tile }}></div>)}
      </div>
      {children}
    </LaShell>);
};

// Lock Screen Live Activity: Ada's well · intent and clock · one-press Freeze.
const LaCard = ({ state = 'run' }) => {
  const t = laT(), fz = state === 'frozen', done = state === 'done';
  return (
    <div style={{ position: 'absolute', left: 12, right: 12, bottom: 118, background: t.plat, borderRadius: 28, boxShadow: t.lift, padding: '15px 14px 15px 15px', display: 'flex', alignItems: 'center', gap: 13, fontFamily: SANS }}>
      <div style={{ width: 60, height: 60, borderRadius: '50%', background: t.well, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {done ? <Ic n="cube_done" style={{ fontSize: 38, color: t.ice }} /> : <SessionCube size={38} color={t.ice} />}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 13, fontWeight: 700, color: fz || done ? t.ice : t.platSub }}>
          {fz ? <><Ic n="freeze" style={{ fontSize: 14 }} />Frozen</> : done ? 'Session done' : <><Ic n="state_deep_focus" style={{ fontSize: 14 }} />Deep Work</>}
        </div>
        <div style={{ fontSize: 15, fontWeight: 700, color: t.platInk, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{LA_TASK}</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
          <span style={{ fontSize: 30, fontWeight: 800, lineHeight: 1.1, letterSpacing: -1, color: fz ? t.ice : t.platInk, fontVariantNumeric: 'tabular-nums' }}>{done ? '25:00' : LA_TIME}</span>
          <span style={{ fontSize: 13, fontWeight: 600, color: t.platSub }}>{done ? 'focused' : 'left'}</span>
        </div>
      </div>
      {!done &&
      <div style={{ width: 50, height: 50, borderRadius: '50%', background: t.btn, color: t.btnInk, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, cursor: 'pointer' }}>
          <Ic n={fz ? 'play_arrow' : 'freeze'} style={{ fontSize: 23 }} />
        </div>}
    </div>);
};
const LA_LOCK = ({ state }) => <LockPhone acc><LaCard state={state} /></LockPhone>;
const LA_LOCK_FROZEN = () => <LA_LOCK state="frozen" />;
const LA_LOCK_DONE = () => <LA_LOCK state="done" />;

// Dynamic Island: black in both appearances. Live clock white, frozen clock ice.
const LA_ISLAND = { position: 'absolute', top: 11, background: '#000', boxSizing: 'border-box', fontFamily: SANS };
const IslandCompact = ({ frozen }) =>
<div style={{ ...LA_ISLAND, left: '50%', width: 236, height: 37, marginLeft: -118, borderRadius: 19, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 14px 0 9px' }}>
    <SessionCube size={22} />
    <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 15, fontWeight: 800, color: frozen ? AQ_ICE_ON_DARK : '#fff', fontVariantNumeric: 'tabular-nums' }}>{frozen && <Ic n="freeze" style={{ fontSize: 14 }} />}{LA_TIME}</span>
  </div>;
const LA_ISLAND_COMPACT = () => <HomePhone><IslandCompact /></HomePhone>;
const LA_ISLAND_FROZEN = () => <HomePhone><IslandCompact frozen /></HomePhone>;
const LA_ISLAND_EXPANDED = () =>
<HomePhone>
    <div style={{ ...LA_ISLAND, left: 11, right: 11, borderRadius: 46, padding: '18px 20px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
        <SessionCube size={46} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{LA_TASK}</div>
          <div style={{ fontSize: 13, fontWeight: 600, color: LA_SUB, marginTop: 2 }}>CC 401 · Deep Work</div>
        </div>
        <span style={{ fontSize: 28, fontWeight: 800, color: '#fff', fontVariantNumeric: 'tabular-nums' }}>{LA_TIME}</span>
      </div>
      <LaRail style={{ marginTop: 14 }} />
      <div style={{ marginTop: 14 }}><LaPills items={[['freeze', 'Freeze'], ['end', 'End']]} /></div>
    </div>
  </HomePhone>;
const LA_ISLAND_MINIMAL = () =>
<HomePhone>
    <div style={{ ...LA_ISLAND, left: '50%', width: 150, height: 37, marginLeft: -96, borderRadius: 19, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 13px' }}>
      <span className="material-icons-outlined" style={{ fontSize: 18, color: '#30d158' }}>call</span>
      <span style={{ fontFamily: SYSFONT, fontSize: 15, fontWeight: 600, color: '#30d158' }}>2:14</span>
    </div>
    <div style={{ ...LA_ISLAND, left: '50%', width: 37, height: 37, marginLeft: 62, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><SessionCube size={21} /></div>
  </HomePhone>;

// Widgets: three, one job each. Next · This week · Focus (Start 5 min).
const wgBox = (t, w, h) => ({ width: w, height: h, boxSizing: 'border-box', background: t.card, borderRadius: 24, fontFamily: SANS, display: 'flex', flexDirection: 'column', flexShrink: 0, boxShadow: IS_DARK ? 'none' : '0 2px 10px rgba(40,30,70,0.06)' });
const WgNext = () => {
  const t = laT();
  return (
    <div style={{ ...wgBox(t, 170, 170), padding: 16 }}>
      <span style={{ fontSize: 13, fontWeight: 700, color: t.cardSub }}>Next</span>
      <span style={{ flex: 1, fontSize: 17, fontWeight: 800, lineHeight: 1.25, color: t.cardInk, marginTop: 6 }}>Networks revision</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ width: 8, height: 8, borderRadius: '50%', background: IS_DARK ? '#5cbbff' : AQ_TAG_INK.lecture, flexShrink: 0 }}></span>
        <span style={{ fontSize: 13, fontWeight: 600, color: t.cardSub }}>2:00 PM · CN 302</span>
      </div>
    </div>);
};
const WgFocus = () => {
  const t = laT();
  return (
    <div style={{ ...wgBox(t, 170, 170), padding: 14 }}>
      <span style={{ fontSize: 13, fontWeight: 700, color: t.cardSub, paddingLeft: 2 }}>Focus</span>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><BrandAda size={54} /></div>
      <div style={{ height: 44, borderRadius: 22, background: AQ_ICE, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 800, cursor: 'pointer' }}>Start 5 min</div>
    </div>);
};
const WgWeek = () => {
  const t = laT();
  return (
    <div style={{ ...wgBox(t, 364, 170), padding: '16px 18px 18px', justifyContent: 'space-between' }}>
      <span style={{ fontSize: 13, fontWeight: 700, color: t.cardSub }}>This week</span>
      <MoodWeekRow cube={30} />
    </div>);
};
const WG_HOME = () => {
  const t = laT();
  return (
    <HomePhone icons={false}>
      <IslandCompact />
      <div style={{ position: 'absolute', top: 74, left: 19, right: 19, display: 'grid', gridTemplateColumns: '170px 170px', justifyContent: 'space-between', rowGap: 24 }}>
        <WgNext /><WgFocus />
        <div style={{ gridColumn: '1 / -1' }}><WgWeek /></div>
      </div>
      <div style={{ position: 'absolute', top: 470, left: 28, right: 28, display: 'grid', gridTemplateColumns: 'repeat(4, 62px)', justifyContent: 'space-between', rowGap: 32 }}>
        {Array.from({ length: 8 }, (_, i) => <div key={i} style={{ width: 62, height: 62, borderRadius: 15, background: t.tile }}></div>)}
      </div>
    </HomePhone>);
};
const WG_GALLERY = () => {
  const t = laT();
  return (
    <HomePhone>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.32)' }}></div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, background: t.sheet, borderRadius: '38px 38px 55px 55px', padding: '10px 20px 30px', fontFamily: SANS, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
        <div style={{ width: 36, height: 5, borderRadius: 3, background: IS_DARK ? 'rgba(255,255,255,0.24)' : 'rgba(0,0,0,0.16)' }}></div>
        <div style={{ alignSelf: 'stretch', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><LaAppTile size={32} /><span style={{ fontSize: 17, fontWeight: 800, color: t.cardInk }}>Aqademiq</span></div>
          <div style={{ width: 44, height: 44, borderRadius: '50%', background: t.card, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}><Ic n="close" style={{ fontSize: 18, color: t.cardSub }} /></div>
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 24, fontWeight: 800, color: t.cardInk }}>Focus</div>
          <div style={{ fontSize: 15, lineHeight: 1.45, color: t.cardSub, marginTop: 4, maxWidth: 260, textWrap: 'pretty' }}>Start five minutes without opening anything.</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, alignSelf: 'stretch', justifyContent: 'center', overflow: 'hidden' }}>
          <div style={{ width: 24, height: 150, borderRadius: 18, background: t.tile, flexShrink: 0 }}></div>
          <WgFocus />
          <div style={{ width: 24, height: 150, borderRadius: 18, background: t.tile, flexShrink: 0 }}></div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>{[0, 1, 2].map((i) => <span key={i} style={{ width: 8, height: 8, borderRadius: '50%', background: i === 2 ? t.cardInk : t.tile }}></span>)}</div>
        <div style={{ alignSelf: 'stretch', height: 52, borderRadius: 26, background: AQ_ICE, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 800, cursor: 'pointer' }}>Add widget</div>
      </div>
    </HomePhone>);
};

// StandBy: charging, landscape, propped on the desk. Always black.
const LA_STANDBY = () =>
<LaShell bg="#000" w={874} h={402}>
    <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', gap: 44, padding: '0 64px', fontFamily: SANS }}>
      <SessionCube size={200} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 17, fontWeight: 700, color: AQ_ICE_ON_DARK }}><Ic n="state_deep_focus" style={{ fontSize: 18 }} />Deep Work</span>
        <span style={{ fontSize: 100, fontWeight: 800, lineHeight: 1, letterSpacing: -3, color: '#fff', fontVariantNumeric: 'tabular-nums' }}>{LA_TIME}</span>
        <span style={{ fontSize: 20, fontWeight: 700, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{LA_TASK}</span>
        <LaRail style={{ marginTop: 6 }} />
        <div style={{ width: 300, marginTop: 10 }}><LaPills items={[['freeze', 'Freeze'], ['end', 'End']]} /></div>
      </div>
    </div>
  </LaShell>;
// StandBy, frozen: clock goes ice, Freeze becomes Resume.
const LA_STANDBY_FROZEN = () =>
<LaShell bg="#000" w={874} h={402}>
    <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', gap: 44, padding: '0 64px', fontFamily: SANS }}>
      <SessionCube size={200} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 17, fontWeight: 700, color: AQ_ICE_ON_DARK }}><Ic n="freeze" style={{ fontSize: 18 }} />Frozen</span>
        <span style={{ fontSize: 100, fontWeight: 800, lineHeight: 1, letterSpacing: -3, color: AQ_ICE_ON_DARK, fontVariantNumeric: 'tabular-nums' }}>{LA_TIME}</span>
        <span style={{ fontSize: 20, fontWeight: 700, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{LA_TASK}</span>
        <LaRail frozen style={{ marginTop: 6 }} />
        <div style={{ width: 300, marginTop: 10 }}><LaPills items={[['play_arrow', 'Resume'], ['end', 'End']]} /></div>
      </div>
    </div>
  </LaShell>;

const NotifCard = ({ lead, title, when, body, thumb }) => {
  const t = laT();
  return (
    <div style={{ background: t.notif, borderRadius: 22, padding: '12px 14px', display: 'flex', gap: 11, alignItems: 'center', color: t.notifInk, boxShadow: t.lift }}>
      {lead}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span style={{ flex: 1, fontSize: 15, fontWeight: 700 }}>{title}</span>
          <span style={{ fontSize: 13, color: t.notifSub }}>{when}</span>
        </div>
        <div style={{ fontSize: 15, lineHeight: 1.35, marginTop: 1, textWrap: 'pretty' }}>{body}</div>
      </div>
      {thumb}
    </div>);
};
const NOTIF_IOS = () =>
<LockPhone>
    <div style={{ position: 'absolute', top: 262, left: 12, right: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
      <NotifCard title="Ada" when="now" body="Your 2:00 PM block starts in 5 minutes. Tap to start the session."
    lead={<div style={{ position: 'relative', width: 40, height: 40, flexShrink: 0 }}><BrandAda size={40} /><div style={{ position: 'absolute', right: -4, bottom: -4 }}><LaAppTile size={18} /></div></div>} />
      <NotifCard title="Session done" when="9:18" body="25:00 on LL(1) parsing notes." lead={<LaAppTile />} thumb={<BrandAda size={44} pose="session_done" />} />
    </div>
  </LockPhone>;

// Android: status chip + ongoing notification (the floor), App freeze below.
const DroidHead = ({ d, children, right }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: d.sub }}>
    <span style={{ width: 22, height: 22, borderRadius: '50%', background: d.ice, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Ic n="brand_ada_mono" fill style={{ fontSize: 15, color: d.onIce }} /></span>
    <span style={{ flex: 1 }}>{children}</span>
    {right && <span>{right}</span>}
  </div>;
const NOTIF_ANDROID = () => {
  const d = droidT();
  return (
    <LaShell bg={d.shell} radius={44}>
      <div style={{ position: 'absolute', top: 15, left: '50%', marginLeft: -7, width: 14, height: 14, borderRadius: '50%', background: '#000', boxShadow: '0 0 0 1.5px ' + (IS_DARK ? '#26232c' : '#d8d2dd') }}></div>
      <div style={{ position: 'absolute', top: 10, left: 22, display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, fontWeight: 500, color: d.ink }}>
        9:41
        <span style={{ height: 26, borderRadius: 13, background: d.ice, color: d.onIce, display: 'flex', alignItems: 'center', gap: 5, padding: '0 10px 0 7px', fontSize: 13, fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}><Ic n="brand_ada_mono" fill style={{ fontSize: 15 }} />{LA_TIME}</span>
      </div>
      <span style={{ position: 'absolute', top: 14, right: 26, fontSize: 14, letterSpacing: -1, color: d.ink }}>●▊</span>
      <div style={{ position: 'absolute', top: 58, left: 26, fontSize: 15, color: d.sub }}>Wed, 3 June</div>
      <div style={{ position: 'absolute', top: 92, left: 12, right: 12, display: 'flex', flexDirection: 'column', gap: 6, fontFamily: SANS }}>
        <div style={{ background: d.card, borderRadius: 24, padding: '14px 16px 6px' }}>
          <DroidHead d={d} right="Ongoing">Aqademiq · Focus</DroidHead>
          <div style={{ display: 'flex', alignItems: 'center', gap: 13, marginTop: 12 }}>
            <SessionCube size={44} color={d.ice} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: d.ink, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{LA_TASK}</div>
              <div style={{ fontSize: 14, color: d.sub, marginTop: 2 }}>Running · Deep Work</div>
            </div>
            <span style={{ fontSize: 22, fontWeight: 800, color: d.ink, fontVariantNumeric: 'tabular-nums' }}>{LA_TIME}</span>
          </div>
          <LaRail ice={d.ice} track={d.track} style={{ marginTop: 14 }} />
          <div style={{ height: 1, background: d.line, margin: '14px -16px 0' }}></div>
          <div style={{ display: 'flex', gap: 8, marginLeft: -12 }}>
            {[['Freeze', d.ice], ['End', d.sub]].map(([l, c]) => <span key={l} style={{ height: 44, padding: '0 12px', display: 'flex', alignItems: 'center', fontSize: 15, fontWeight: 700, color: c, cursor: 'pointer' }}>{l}</span>)}
          </div>
        </div>
        <div style={{ background: d.card, borderRadius: 24, padding: '14px 16px 15px' }}>
          <DroidHead d={d}>Aqademiq · App freeze</DroidHead>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 9 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: d.ink }}>9 apps on ice</div>
              <div style={{ fontSize: 14, color: d.sub, marginTop: 2, lineHeight: 1.4 }}>Back at 3:42. Phone and Messages stay open.</div>
            </div>
            <Ic n="freeze" style={{ fontSize: 30, color: d.ice }} />
          </div>
        </div>
      </div>
      <div style={{ position: 'absolute', bottom: 10, left: '50%', marginLeft: -54, width: 108, height: 4, borderRadius: 2, background: d.ink, opacity: 0.5 }}></div>
    </LaShell>);
};

// The cheap surfaces: one intent (start five minutes) in four clothes.
const LaQuickRow = ({ label, sub, children }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 22 }}>
    <div style={{ width: 170, display: 'flex', justifyContent: 'center', flexShrink: 0 }}>{children}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 15, fontWeight: 800, color: '#111717' }}>{label}</div>
      <div style={{ fontSize: 13, color: '#646464', marginTop: 2, lineHeight: 1.4 }}>{sub}</div>
    </div>
  </div>;
const LA_QUICK = () => {
  const d = droidT();
  return (
    <div style={{ width: 402, display: 'flex', flexDirection: 'column', gap: 44, fontFamily: SANS }}>
      <LaQuickRow label="Control Center" sub="iOS 18+ control. Starts 5 min.">
        <div style={{ width: 92, height: 92, borderRadius: 26, background: 'rgba(38,36,46,0.92)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
          <BrandAda size={38} /><span style={{ fontSize: 13, fontWeight: 800, color: '#fff' }}>Start 5</span>
        </div>
      </LaQuickRow>
      <LaQuickRow label="Action button" sub="15 Pro and later. No launch, no hunt.">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 6, height: 40, borderRadius: 3, background: IS_DARK ? '#55535c' : '#b9b6c0' }}></div>
          <span style={{ height: 44, borderRadius: 22, background: WHITE, boxShadow: SHADOW, padding: '0 16px', display: 'flex', alignItems: 'center', gap: 7, fontSize: 15, fontWeight: 800, color: TEXT }}><Ic n="freeze" style={{ fontSize: 17, color: AQ_ICE }} />Press · 5 min</span>
        </div>
      </LaQuickRow>
      <LaQuickRow label="Quick Settings tile" sub="Android. Same five minutes.">
        <div style={{ width: 170, height: 72, borderRadius: 36, background: d.ice, color: d.onIce, display: 'flex', alignItems: 'center', gap: 10, padding: '0 18px', boxSizing: 'border-box' }}>
          <Ic n="brand_ada_mono" fill style={{ fontSize: 24 }} />
          <div><div style={{ fontSize: 15, fontWeight: 800 }}>Focus</div><div style={{ fontSize: 13, fontWeight: 600, opacity: 0.85 }}>5 min</div></div>
        </div>
      </LaQuickRow>
      <LaQuickRow label="Apple Watch" sub="Freeze from the wrist. Always black.">
        <div style={{ width: 132, height: 160, borderRadius: 38, background: '#000', boxShadow: '0 0 0 6px ' + (IS_DARK ? '#2a2830' : '#c9c6cf'), display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
          <SessionCube size={34} />
          <span style={{ fontSize: 24, fontWeight: 800, color: '#fff', fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>{LA_TIME}</span>
          <div style={{ display: 'flex', gap: 8, marginTop: 2 }}>
            <span style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(203,188,253,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic n="freeze" style={{ fontSize: 20, color: AQ_ICE_ON_DARK }} /></span>
            <span style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic n="end" style={{ fontSize: 20, color: '#c9c6d0' }} /></span>
          </div>
        </div>
      </LaQuickRow>
    </div>);
};

const LandFrame = ({ children }) =>
<div style={{ width: 924, height: 452, display: 'flex', alignItems: 'center', justifyContent: 'center', background: FRAME_BG }}>{children}</div>;

const W = 420,H = 924;
const Frame = ({ children }) =>
<div style={{ width: W, height: H, display: 'flex', alignItems: 'center', justifyContent: 'center', background: FRAME_BG }}>
    {children}
  </div>;


const App = () => {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  applyTweaks(tweaks);
  return (
    <>
      <DesignCanvas title="Aqademiq V1 · Full Flow v11 · Aqademiq icon pack · iPhone 17 (402×874)">
        <DCSection id="entry" title="00 · Entry" subtitle="Splash → Welcome forks into Guest or Sign-up">
          <DCArtboard id="splash" label="Splash · state-mark loader" width={W} height={H}><Frame><SPLASH /></Frame></DCArtboard>
          <DCArtboard id="welcome" label="Welcome · Jump in / Sign up" width={W} height={H}><Frame><WELCOME /></Frame></DCArtboard>
          <DCArtboard id="auth" label="Sign in · password" width={W} height={H}><Frame><AUTH /></Frame></DCArtboard>
          <DCArtboard id="auth-signup" label="Create an account" width={W} height={H}><Frame><AUTH_SIGNUP /></Frame></DCArtboard>
          <DCArtboard id="auth-otp" label="OTP verification" width={W} height={H}><Frame><AUTH_OTP /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="guest" title="00b · Guest Mode" subtitle="Jump right in · core features work · onboarding prompted contextually">
          <DCArtboard id="guest-home" label="Guest home + setup nudge" width={W} height={H}><Frame><GUEST_HOME /></Frame></DCArtboard>
          <DCArtboard id="guest-subjects" label="Guest Subjects (empty)" width={W} height={H}><Frame><GUEST_SUBJECTS /></Frame></DCArtboard>
          <DCArtboard id="guest-ada" label="Tap Ada → onboarding prompt" width={W} height={H}><Frame><GUEST_ADA_PROMPT /></Frame></DCArtboard>
          <DCArtboard id="guest-stats" label="Tap Stats → onboarding prompt" width={W} height={H}><Frame><GUEST_STATS_PROMPT /></Frame></DCArtboard>
          <DCArtboard id="guest-save" label="After session → save prompt" width={W} height={H}><Frame><GUEST_SAVE_PROMPT /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="onboarding" title="01 · Onboarding" subtitle="Both Sign-up and Guest 'Set up' land here · spacious, Ada-coached">
          <DCArtboard id="ob-age" label="Step 1 · Age" width={W} height={H}><Frame><OB_AGE /></Frame></DCArtboard>
          <DCArtboard id="ob-age-gate" label="Age gate · under 18" width={W} height={H}><Frame><OB_AGE_GATE /></Frame></DCArtboard>
          <DCArtboard id="ob-consent" label="Consent · data use" width={W} height={H}><Frame><OB_CONSENT /></Frame></DCArtboard>
          <DCArtboard id="ob-consent-declined" label="Consent · declined (blocked)" width={W} height={H}><Frame><OB_CONSENT_DECLINED /></Frame></DCArtboard>
          <DCArtboard id="ob-referral" label="Referral code (optional)" width={W} height={H}><Frame><OB_REFERRAL /></Frame></DCArtboard>
          <DCArtboard id="ob-source" label="How you heard about us" width={W} height={H}><Frame><OB_SOURCE /></Frame></DCArtboard>
          <DCArtboard id="ob-source-other" label="How you heard · Other" width={W} height={H}><Frame><OB_SOURCE pick="Other" /></Frame></DCArtboard>
          <DCArtboard id="ob1" label="Step 2 · Name" width={W} height={H}><Frame><OB1 /></Frame></DCArtboard>
          <DCArtboard id="ob2" label="Step 3 · What you study" width={W} height={H}><Frame><OB2 /></Frame></DCArtboard>
          <DCArtboard id="ob2-add" label="Step 3 · Add subject popup" width={W} height={H}><Frame><OB2_ADD_SUBJECT /></Frame></DCArtboard>
          <DCArtboard id="ob-mood" label="Step 4 · Feelings per subject" width={W} height={H}><Frame><OB_MOOD /></Frame></DCArtboard>
          <DCArtboard id="ob-hours" label="Step 5 · Study hours" width={W} height={H}><Frame><OB_HOURS /></Frame></DCArtboard>
          <DCArtboard id="ob-hours-custom" label="Step 5 · Edge · not every weekday, Wellness time takes the rest" width={W} height={H}><Frame><OB_HOURS study={OB_STUDY_CUSTOM} /></Frame></DCArtboard>
          <DCArtboard id="ob-hours-all" label="Step 5 · Edge · all 7 days, no Wellness time" width={W} height={H}><Frame><OB_HOURS study={OB_STUDY_ALL} /></Frame></DCArtboard>
          <DCArtboard id="ob-freeze-ios" label="Step 6 · App freeze · iOS, one Screen Time ask" width={W} height={H}><Frame><OB_FREEZE /></Frame></DCArtboard>
          <DCArtboard id="ob-freeze-android" label="Step 6 · App freeze · Android, two grants" width={W} height={H}><Frame><OB_FREEZE os="android" /></Frame></DCArtboard>
          <DCArtboard id="ob-freeze-custom" label="Step 6 · Edge · frosts from custom study days" width={W} height={H}><Frame><OB_FREEZE study={OB_STUDY_CUSTOM} /></Frame></DCArtboard>
          <DCArtboard id="ob-freeze-all" label="Step 6 · Edge · all 7 days, one frost" width={W} height={H}><Frame><OB_FREEZE study={OB_STUDY_ALL} /></Frame></DCArtboard>
          <DCArtboard id="ob-apps-ios" label="Step 7 · Pick apps · iOS, Apple's picker" width={W} height={H}><Frame><FZ_PICKER dots={<Dots total={11} active={9} />} /></Frame></DCArtboard>
          <DCArtboard id="ob-apps-android" label="Step 7 · Pick apps · Android, pre-ticked" width={W} height={H}><Frame><OB_APPS_ANDROID /></Frame></DCArtboard>
          <DCArtboard id="ob5" label="Step 8 · Meet Prism" width={W} height={H}><Frame><OB5 /></Frame></DCArtboard>
          <DCArtboard id="adaload" label="Ada loading" width={W} height={H}><Frame><ADA_LOAD /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="home" title="02 · Plan / Home" subtitle="Day timeline · collapsible sections · month picker · ··· menu · reschedule">
          <DCArtboard id="plan-timeline" label="Plan · Timeline (default)" width={W} height={H}><Frame><PLAN_TIMELINE /></Frame></DCArtboard>
          <DCArtboard id="plan-breakdown" label="Task broken into microtasks" width={W} height={H}><Frame><PLAN_BREAKDOWN /></Frame></DCArtboard>
          <DCArtboard id="plan-list" label="Plan · List grouping" width={W} height={H}><Frame><PLAN_LIST /></Frame></DCArtboard>
          <DCArtboard id="plan-anytime-collapsed" label="Anytime collapsed" width={W} height={H}><Frame><PLAN_ANYTIME_COLLAPSED /></Frame></DCArtboard>
          <DCArtboard id="plan-planned-collapsed" label="Planned collapsed" width={W} height={H}><Frame><PLAN_PLANNED_COLLAPSED /></Frame></DCArtboard>
          <DCArtboard id="plan-otherday" label="Another day + Today button" width={W} height={H}><Frame><PLAN_OTHERDAY /></Frame></DCArtboard>
          <DCArtboard id="plan-month" label="Month picker (June)" width={W} height={H}><Frame><PLAN_MONTH /></Frame></DCArtboard>
          <DCArtboard id="plan-month-next" label="Month picker → July" width={W} height={H}><Frame><PLAN_MONTH_NEXT /></Frame></DCArtboard>
          <DCArtboard id="plan-monthyear" label="Month + year wheel" width={W} height={H}><Frame><PLAN_MONTHYEAR /></Frame></DCArtboard>
          <DCArtboard id="plan-quickadd" label="Quick add (+ button)" width={W} height={H}><Frame data-comment-anchor="860172f646-div-2495-1"><PLAN_QUICKADD /></Frame></DCArtboard>
          <DCArtboard id="plan-menu" label="··· overflow menu" width={W} height={H}><Frame><PLAN_MENU /></Frame></DCArtboard>
          <DCArtboard id="plan-grouping" label="Grouping submenu" width={W} height={H}><Frame><PLAN_GROUPING /></Frame></DCArtboard>
          <DCArtboard id="plan-logmood" label="Log mood (popup)" width={W} height={H}><Frame><PLAN_LOGMOOD /></Frame></DCArtboard>
          <DCArtboard id="plan-resched" label="Reschedule · remaining" width={W} height={H}><Frame><RESCHEDULE_REMAINING /></Frame></DCArtboard>
          <DCArtboard id="plan-move" label="Reschedule · move date" width={W} height={H}><Frame><RESCHEDULE_MOVE /></Frame></DCArtboard>
          <DCArtboard id="plan-addtask" label="Add task · full form" width={W} height={H}><Frame><ADD_TASK_FULL /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-time" label="Add task · Time of day picker" width={W} height={H}><Frame><PICK_TIMEOFDAY /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-time-custom" label="Add task · Specific time (dialog)" width={W} height={H}><Frame><PICK_TIME_SPECIFIC /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-date" label="Add task · Date picker" width={W} height={H}><Frame><PICK_DATE /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-duration" label="Add task · Duration picker" width={W} height={H}><Frame><PICK_DURATION /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-duration-custom" label="Add task · Custom duration (dialog)" width={W} height={H}><Frame><PICK_DURATION_CUSTOM /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-repeat" label="Add task · Repeat picker" width={W} height={H}><Frame><PICK_REPEAT /></Frame></DCArtboard>
          <DCArtboard id="plan-pick-repeat-custom" label="Add task · Custom repeat (dialog)" width={W} height={H}><Frame><PICK_REPEAT_CUSTOM /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="subjects" title="03 · Subjects" subtitle="Academic structure · info · files bucket · add/edit · semesters">
          <DCArtboard id="subj-list" label="Subjects · list (Grid via Tweak)" width={W} height={H}><Frame><SUBJECTS_LIST /></Frame></DCArtboard>
          <DCArtboard id="subj-detail" label="Subject detail + files" width={W} height={H}><Frame><SUBJECT_DETAIL /></Frame></DCArtboard>
          <DCArtboard id="subj-add" label="Add / edit subject" width={W} height={H}><Frame><ADD_SUBJECT /></Frame></DCArtboard>
          <DCArtboard id="subj-add-gpa" label="Add subject · Target as GPA" width={W} height={H}><Frame><ADD_SUBJECT_GPA /></Frame></DCArtboard>
          <DCArtboard id="subj-add-pct" label="Add subject · Target as %" width={W} height={H}><Frame><ADD_SUBJECT_PCT /></Frame></DCArtboard>
          <DCArtboard id="subj-file" label="Add file to subject" width={W} height={H}><Frame><ADD_FILE_SHEET /></Frame></DCArtboard>
          <DCArtboard id="subj-menu" label="··· semester menu" width={W} height={H}><Frame><SUBJECT_MENU /></Frame></DCArtboard>
          <DCArtboard id="subj-add-sem" label="Add semester" width={W} height={H}><Frame><SUBJECT_ADD_SEM /></Frame></DCArtboard>
          <DCArtboard id="subj-edit-sem" label="Edit semesters" width={W} height={H}><Frame><SUBJECT_EDIT_SEM /></Frame></DCArtboard>
          <DCArtboard id="subj-sort" label="Sort subjects" width={W} height={H}><Frame><SUBJECT_SORT /></Frame></DCArtboard>
          <DCArtboard id="subj-share" label="Share / referral sheet" width={W} height={H}><Frame><TASK_SHARE /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="focus" title="04 · Focus" subtitle="Melting-ice timer (Ada melts as you focus) · live demo · pause freezes · Prism">
          <DCArtboard id="fc-set" label="Focus · Set timer" width={W} height={H}><Frame><FOCUS /></Frame></DCArtboard>
          <DCArtboard id="fc-link" label="Link a task (tap chip)" width={W} height={H}><Frame><FOCUS_LINK_TASK /></Frame></DCArtboard>
          <DCArtboard id="fc-ice" label="Ice chip in the setup row" width={W} height={H}><Frame><FOCUS_ICE_CHIP /></Frame></DCArtboard>
          <DCArtboard id="fc-duration" label="Set time (tap 25:00)" width={W} height={H}><Frame><DURATION_MENU /></Frame></DCArtboard>
          <DCArtboard id="fc-prism" label="Prism mode picker" width={W} height={H}><Frame><PRISM_MENU /></Frame></DCArtboard>
          <DCArtboard id="fc-running" label="Running · live melt" width={W} height={H}><Frame><FOCUS_RUNNING /></Frame></DCArtboard>
          <DCArtboard id="fc-paused" label="Paused · frozen" width={W} height={H}><Frame><FOCUS_PAUSED /></Frame></DCArtboard>
          <DCArtboard id="fc-end" label="Session complete" width={W} height={H}><Frame><SESSION_END /></Frame></DCArtboard>
          <DCArtboard id="fc-end-ice" label="Session end · trim-the-set offer" width={W} height={H}><Frame><SESSION_END_ICE /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="freeze" title="04-A · App freeze" subtitle="Pushed from Focus (❄ App freeze) · freeze now or with a frost · thawing takes a breath, then 2–15 min · deep freeze and keep-only are free">
          <DCArtboard id="fz-intro" label="First tap · what App freeze is" width={W} height={H}><Frame><FZ_INTRO /></Frame></DCArtboard>
          <DCArtboard id="fz-perm-ios" label="iOS · Screen Time pre-prompt" width={W} height={H}><Frame><FZ_PERM_IOS /></Frame></DCArtboard>
          <DCArtboard id="fz-perm-android" label="Android · two grants" width={W} height={H}><Frame><FZ_PERM_ANDROID /></Frame></DCArtboard>
          <DCArtboard id="fz-perm-battery" label="Android · battery manager (sheet)" width={W} height={H}><Frame><FZ_PERM_BATTERY /></Frame></DCArtboard>
          <DCArtboard id="fz-perm-denied" label="Declined · no nagging" width={W} height={H}><Frame><FZ_PERM_DENIED /></Frame></DCArtboard>
          <DCArtboard id="fz-hub-empty" label="Hub · first visit" width={W} height={H}><Frame><FZ_HUB_EMPTY /></Frame></DCArtboard>
          <DCArtboard id="fz-session" label="Freeze now (sheet)" width={W} height={H}><Frame><FZ_SESSION /></Frame></DCArtboard>
          <DCArtboard id="fz-select" label="Choose apps · Suggested is Android-only" width={W} height={H}><Frame><FZ_SELECT /></Frame></DCArtboard>
          <DCArtboard id="fz-picker" label="iOS · Apple's picker, our line above" width={W} height={H}><Frame><FZ_PICKER /></Frame></DCArtboard>
          <DCArtboard id="fz-select-keep" label="Keep only these" width={W} height={H}><Frame><FZ_SELECT_KEEP /></Frame></DCArtboard>
          <DCArtboard id="fz-hub" label="Hub · frozen now, frosts, groups" width={W} height={H}><Frame><FZ_HUB /></Frame></DCArtboard>
          <DCArtboard id="fz-hub-standdown" label="Hub · everything thawed" width={W} height={H}><Frame><FZ_HUB_STANDDOWN /></Frame></DCArtboard>
          <DCArtboard id="ice-shield-first" label="Shield · first open, playful" width={W} height={H}><Frame><ICE_SHIELD_FIRST /></Frame></DCArtboard>
          <DCArtboard id="ice-shield-second" label="Shield · second open, shorter" width={W} height={H}><Frame><ICE_SHIELD_SECOND /></Frame></DCArtboard>
          <DCArtboard id="ice-shield-third" label="Shield · third open, nearly silent" width={W} height={H}><Frame><ICE_SHIELD_THIRD /></Frame></DCArtboard>
          <DCArtboard id="fz-thaw-pause" label="Thaw · a breath first (10s)" width={W} height={H}><Frame><FZ_THAW_PAUSE /></Frame></DCArtboard>
          <DCArtboard id="fz-thaw-pause-more" label="Thaw · Increasing resistance (30s)" width={W} height={H}><Frame><FZ_THAW_PAUSE_MORE /></Frame></DCArtboard>
          <DCArtboard id="fz-thaw-minutes" label="Thaw · how long (2–15 min)" width={W} height={H}><Frame><FZ_THAW_MINUTES /></Frame></DCArtboard>
          <DCArtboard id="fz-thawed" label="Thawed · countdown + refreeze" width={W} height={H}><Frame><FZ_THAWED /></Frame></DCArtboard>
          <DCArtboard id="fz-deep" label="Deep freeze holds (sheet)" width={W} height={H}><Frame><FZ_DEEP /></Frame></DCArtboard>
          <DCArtboard id="fz-new" label="New frost (sheet)" width={W} height={H}><Frame><FZ_NEW /></Frame></DCArtboard>
          <DCArtboard id="fz-edit" label="Schedule frost · editor" width={W} height={H}><Frame><FZ_EDIT /></Frame></DCArtboard>
          <DCArtboard id="fz-edit-time" label="Editor · start time" width={W} height={H}><Frame><FZ_EDIT_TIME /></Frame></DCArtboard>
          <DCArtboard id="fz-name" label="Name this frost" width={W} height={H}><Frame><FZ_NAME /></Frame></DCArtboard>
          <DCArtboard id="fz-active" label="A running frost (sheet)" width={W} height={H}><Frame><FZ_ACTIVE /></Frame></DCArtboard>
          <DCArtboard id="fz-end" label="End early (sheet)" width={W} height={H}><Frame><FZ_END /></Frame></DCArtboard>
          <DCArtboard id="fz-always" label="Group · Always open" width={W} height={H}><Frame><FZ_ALWAYS /></Frame></DCArtboard>
          <DCArtboard id="fz-never" label="Group · Never open" width={W} height={H}><Frame><FZ_NEVER /></Frame></DCArtboard>
          <DCArtboard id="fz-distract" label="Group · Distracting" width={W} height={H}><Frame><FZ_DISTRACT /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="native" title="04-B · Ambient surfaces" subtitle="v1.2 Ambient Ada layout on the current pack · aq_cube_session is the timer · follows Light / Dark (Island, StandBy and Watch stay black)">
          <DCArtboard id="la-lock" label="Lock Screen · Live Activity, running" width={W} height={H}><Frame><LA_LOCK /></Frame></DCArtboard>
          <DCArtboard id="la-lock-frozen" label="Lock Screen · frozen, one press to resume" width={W} height={H}><Frame><LA_LOCK_FROZEN /></Frame></DCArtboard>
          <DCArtboard id="la-lock-done" label="Lock Screen · session done" width={W} height={H}><Frame><LA_LOCK_DONE /></Frame></DCArtboard>
          <DCArtboard id="la-island-compact" label="Dynamic Island · compact" width={W} height={H}><Frame><LA_ISLAND_COMPACT /></Frame></DCArtboard>
          <DCArtboard id="la-island-frozen" label="Dynamic Island · compact, frozen" width={W} height={H}><Frame><LA_ISLAND_FROZEN /></Frame></DCArtboard>
          <DCArtboard id="la-island-expanded" label="Dynamic Island · expanded (long press)" width={W} height={H}><Frame><LA_ISLAND_EXPANDED /></Frame></DCArtboard>
          <DCArtboard id="la-island-minimal" label="Dynamic Island · minimal, shared with a call" width={W} height={H}><Frame><LA_ISLAND_MINIMAL /></Frame></DCArtboard>
          <DCArtboard id="wg-home" label="Home Screen · Next, Focus, This week" width={W} height={H}><Frame><WG_HOME /></Frame></DCArtboard>
          <DCArtboard id="wg-gallery" label="Widget gallery · Focus" width={W} height={H}><Frame><WG_GALLERY /></Frame></DCArtboard>
          <DCArtboard id="la-standby" label="StandBy · charging, landscape" width={924} height={452}><LandFrame><LA_STANDBY /></LandFrame></DCArtboard>
          <DCArtboard id="la-standby-frozen" label="StandBy · frozen, Resume" width={924} height={452}><LandFrame><LA_STANDBY_FROZEN /></LandFrame></DCArtboard>
          <DCArtboard id="notif-ios" label="iOS · Ada and session notifications" width={W} height={H}><Frame><NOTIF_IOS /></Frame></DCArtboard>
          <DCArtboard id="notif-android" label="Android · status chip, ongoing session, App freeze" width={W} height={H}><Frame><NOTIF_ANDROID /></Frame></DCArtboard>
          <DCArtboard id="la-quick" label="Quick surfaces · Control Center, Action button, QS tile, Watch" width={W} height={H}><Frame><LA_QUICK /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="ada" title="05 · Ada AI" subtitle="Conversational planner · chat history · ice-cube mascot · every change waits for approval">
          <DCArtboard id="ada-empty" label="Ada · intro state" width={W} height={H}><Frame><ADA_SCREEN /></Frame></DCArtboard>
          <DCArtboard id="ada-chat" label="Ada · active chat" width={W} height={H}><Frame><ADA_CHAT /></Frame></DCArtboard>
          <DCArtboard id="ada-history" label="Chat history (tap ☰)" width={W} height={H}><Frame><CHAT_HISTORY /></Frame></DCArtboard>
          <DCArtboard id="ada-thinking" label="Thinking · state-mark loader · send becomes stop" width={W} height={H}><Frame><ADA_THINKING /></Frame></DCArtboard>
          <DCArtboard id="ada-proposals" label="Proposals · 3 waiting" width={W} height={H}><Frame><ADA_PROPOSALS /></Frame></DCArtboard>
          <DCArtboard id="ada-proposals-end" label="Proposals · scrolled under the header" width={W} height={H}><Frame><ADA_PROPOSALS_END /></Frame></DCArtboard>
          <DCArtboard id="ada-applied" label="Proposals · added, with undo" width={W} height={H}><Frame><ADA_APPLIED /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="profile" title="06 · Profile" subtitle="Full profile page · top (streak & mood) → bottom (hub) · referral">
          <DCArtboard id="profile-top" label="Profile · top (streak & mood)" width={W} height={H}><Frame><PROFILE_TOP_A /></Frame></DCArtboard>
          <DCArtboard id="profile-main" label="Profile · bottom (hub)" width={W} height={H}><Frame><PROFILE /></Frame></DCArtboard>
          <DCArtboard id="referral" label="Referral sheet (tap ↑)" width={W} height={H}><Frame><REFERRAL /></Frame></DCArtboard>
        </DCSection>

        <DCSection id="analytics" title="08 · The Core (weekly report)" subtitle="Nine beats · a record, not a score · no denominators, no back-browsing, mood never leaves in a picture">
          <DCArtboard id="core-entry" label="Entry · waits in the tab" width={W} height={H}><Frame><CORE_ENTRY /></Frame></DCArtboard>
          <DCArtboard id="core-freeze" label="01 · The core freezes in" width={W} height={H}><Frame><CORE_FREEZE /></Frame></DCArtboard>
          <DCArtboard id="core-shape" label="02 · The shape of the week" width={W} height={H}><Frame><CORE_SHAPE /></Frame></DCArtboard>
          <DCArtboard id="core-hero" label="03 · The core itself" width={W} height={H}><Frame><CORE_HERO /></Frame></DCArtboard>
          <DCArtboard id="core-moment" label="04 · One thing that happened" width={W} height={H}><Frame><CORE_MOMENT /></Frame></DCArtboard>
          <DCArtboard id="core-numeral" label="05 · The one numeral" width={W} height={H}><Frame><CORE_NUMERAL /></Frame></DCArtboard>
          <DCArtboard id="core-attention" label="06 · Where attention went" width={W} height={H}><Frame><CORE_ATTENTION /></Frame></DCArtboard>
          <DCArtboard id="core-thawed" label="07 · When you thawed · drawn, not counted" width={W} height={H}><Frame><CORE_THAWED /></Frame></DCArtboard>
          <DCArtboard id="core-gaveback" label="08 · What the week gave back (needs focus GET)" width={W} height={H}><Frame><CORE_GAVE_BACK /></Frame></DCArtboard>
          <DCArtboard id="core-landing" label="09 · One small thing" width={W} height={H}><Frame><CORE_LANDING /></Frame></DCArtboard>
          <DCArtboard id="core-thin" label="A thin week · same register" width={W} height={H}><Frame><CORE_THIN_WEEK /></Frame></DCArtboard>
          <DCArtboard id="core-share" label="Share the shape · story preview" width={W} height={H}><Frame><CORE_SHARE /></Frame></DCArtboard>
          <DCArtboard id="core-story" label="Story image · 1080 × 1920, shape only, no mood" width={W} height={H}><Frame><CORE_STORY /></Frame></DCArtboard>
          <DCArtboard id="core-screenshot" label="Screenshot caught · any screen · tag @tryaqademiq" width={W} height={H}><Frame><CORE_SCREENSHOT /></Frame></DCArtboard>
          <DCArtboard id="core-off" label="A real off switch" width={W} height={H}><Frame><CORE_OFF_SWITCH /></Frame></DCArtboard>
          <DCArtboard id="core-support" label="A bad season · quiet support line" width={W} height={H}><Frame><CORE_SUPPORT_LINE /></Frame></DCArtboard>
        </DCSection>

        <DCSection id="feedback" title="12 · Feedback" subtitle="From Profile → Share feedback · list + board · make suggestion · sort">
          <DCArtboard id="feedback-list" label="Feedback · list (empty)" width={W} height={H}><Frame><FEEDBACK_LIST /></Frame></DCArtboard>
          <DCArtboard id="feedback-list-filled" label="Feedback · list (18 suggestions)" width={W} height={H}><Frame><FEEDBACK_LIST_FILLED /></Frame></DCArtboard>
          <DCArtboard id="feedback-list-filters" label="Feedback · list (filters scrolled)" width={W} height={H}><Frame><FEEDBACK_LIST_FILTERS /></Frame></DCArtboard>
          <DCArtboard id="feedback-suggest" label="Make a suggestion (sheet)" width={W} height={H}><Frame><MAKE_SUGGESTION_SHEET /></Frame></DCArtboard>
          <DCArtboard id="feedback-board" label="Feedback · board (empty)" width={W} height={H}><Frame><FEEDBACK_BOARD /></Frame></DCArtboard>
          <DCArtboard id="feedback-sort" label="Sort suggestions (sheet)" width={W} height={H}><Frame><SORT_SHEET /></Frame></DCArtboard>
        </DCSection>

        <DCSection id="checkin" title="07 · Mood Check-in" subtitle="Ada blob morphs per mood · morning + evening">
          <DCArtboard id="mood-morning" label="Morning check-in" width={W} height={H}><Frame><MOOD_CHECKIN /></Frame></DCArtboard>
          <DCArtboard id="mood-evening" label="Evening reflection" width={W} height={H}><Frame><MOOD_EVENING /></Frame></DCArtboard>
        </DCSection>

        <DCSection id="context" title="09 · Context &amp; Overflow" subtitle="Action sheet · swipe-reveal actions">
          <DCArtboard id="task-overflow" label="Task action sheet" width={W} height={H}><Frame><TASK_OVERFLOW /></Frame></DCArtboard>
          <DCArtboard id="task-swipe" label="Swipe actions" width={W} height={H}><Frame><TASK_SWIPE /></Frame></DCArtboard>
        </DCSection>

        <DCSection id="settings" title="13 · Settings" subtitle="Settings home · profile · study tags · notifications · appearance · Prism · account · email · App freeze">
          <DCArtboard id="settings-home" label="Settings · home" width={W} height={H}><Frame><SETTINGS_HOME /></Frame></DCArtboard>
          <DCArtboard id="settings-addtag" label="Add new tag (sheet)" width={W} height={H}><Frame><ADD_TAG_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-profile" label="Profile (edit personal info)" width={W} height={H}><Frame><SETTINGS_PROFILE /></Frame></DCArtboard>
          <DCArtboard id="settings-editname" label="Edit profile name (sheet)" width={W} height={H}><Frame><EDIT_NAME_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-gender" label="Gender (sheet)" width={W} height={H}><Frame><GENDER_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-email-change" label="Change email (sheet)" width={W} height={H}><Frame><CHANGE_EMAIL_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-password" label="Change password (sheet)" width={W} height={H}><Frame><CHANGE_PASSWORD_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-university" label="University (sheet)" width={W} height={H}><Frame><EDIT_UNI_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-program" label="Program (sheet)" width={W} height={H}><Frame><EDIT_PROGRAM_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-account" label="Account & about (scrolled)" width={W} height={H}><Frame><SETTINGS_ACCOUNT /></Frame></DCArtboard>
          <DCArtboard id="settings-delete" label="Delete account (confirm)" width={W} height={H}><Frame><DELETE_ACCOUNT_DIALOG /></Frame></DCArtboard>
          <DCArtboard id="settings-rate" label="Rate Aqademiq (sheet)" width={W} height={H}><Frame><RATE_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-notif" label="Notifications" width={W} height={H}><Frame><NOTIFICATIONS /></Frame></DCArtboard>
          <DCArtboard id="settings-notif-sound" label="Notification sound (sheet)" width={W} height={H}><Frame><NOTIF_SOUND_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-notif-more" label="Notifications · scrolled" width={W} height={H}><Frame><NOTIFICATIONS_MORE /></Frame></DCArtboard>
          <DCArtboard id="settings-appearance" label="Appearance picker" width={W} height={H}><Frame><APPEARANCE_PICKER /></Frame></DCArtboard>
          <DCArtboard id="settings-sounds" label="Prism" width={W} height={H}><Frame><SOUNDS_SETTING /></Frame></DCArtboard>
          <DCArtboard id="settings-email" label="Email settings" width={W} height={H}><Frame><EMAIL_SETTINGS /></Frame></DCArtboard>
          <DCArtboard id="settings-haptics" label="Haptics (sheet)" width={W} height={H}><Frame><HAPTICS_SHEET /></Frame></DCArtboard>
          <DCArtboard id="settings-ice" label="App freeze · iOS" width={W} height={H}><Frame><ICE_SETTINGS /></Frame></DCArtboard>
          <DCArtboard id="settings-ice-android" label="App freeze · Android, battery restricted (scrolled)" width={W} height={H}><Frame><ICE_SETTINGS_ANDROID /></Frame></DCArtboard>
          <DCArtboard id="settings-ice-off" label="App freeze · Screen Time turned off" width={W} height={H}><Frame><ICE_SETTINGS_OFF /></Frame></DCArtboard>
          <DCArtboard id="settings-thaw" label="Thaw · resistance + length" width={W} height={H}><Frame><ICE_THAW_SETTINGS /></Frame></DCArtboard>
          <DCArtboard id="settings-thaw-resistance" label="Resistance (sheet)" width={W} height={H}><Frame><ICE_THAW_RESISTANCE /></Frame></DCArtboard>
          <DCArtboard id="settings-thaw-all" label="Thaw everything (sheet)" width={W} height={H}><Frame><ICE_THAW_ALL /></Frame></DCArtboard>
          <DCArtboard id="settings-thaw-all-deep" label="Thaw everything · Deep freeze holds (sheet)" width={W} height={H}><Frame><ICE_THAW_ALL_DEEP /></Frame></DCArtboard>
          <DCArtboard id="settings-thaw-all-on" label="App freeze · everything thawed" width={W} height={H}><Frame><ICE_SETTINGS_STANDDOWN /></Frame></DCArtboard>
        </DCSection>
        <DCSection id="icebreakers" title="14 · Ice Breakers" subtitle="Six recordings shot so far, all first-session · the second door out of the empty planner · surfaced contextually, never on a timer">
          <DCArtboard id="ib-empty-plan" label="Empty planner · the second door" width={W} height={H}><Frame><IB_EMPTY_PLAN /></Frame></DCArtboard>
          <DCArtboard id="ib-section-s" label="The first session · six, in order" width={W} height={H}><Frame><IB_SECTION_S /></Frame></DCArtboard>
          <DCArtboard id="ib-player" label="A video open (inline, no autoplay)" width={W} height={H}><Frame><IB_PLAYER /></Frame></DCArtboard>
          <DCArtboard id="ib-profile-card" label="Shelf card on Profile" width={W} height={H}><Frame><IB_PROFILE_CARD /></Frame></DCArtboard>
          <DCArtboard id="ib-watched" label="One left · watched pile collapsed" width={W} height={H}><Frame><IB_WATCHED /></Frame></DCArtboard>
          <DCArtboard id="ib-guest" label="Guest · shelf stays unlocked" width={W} height={H}><Frame><IB_GUEST_CARD /></Frame></DCArtboard>
        </DCSection>
      </DesignCanvas>
      <TweaksPanel>
        <TweakSection title="Dark mode">
          <TweakToggle label="Dark" value={tweaks.darkMode} onChange={(v) => setTweak('darkMode', v)} />
        </TweakSection>
        <TweakSection title="Brand accent">
          <TweakColor options={['#6b5cf0', '#e85476', '#2a9d6b']} value={tweaks.accent} onChange={(v) => setTweak('accent', v)} />
        </TweakSection>
        <TweakSection title="Background warmth">
          <TweakRadio options={['Warm', 'Neutral', 'Cool']} value={tweaks.warmth} onChange={(v) => setTweak('warmth', v)} />
        </TweakSection>
        <TweakSection title="Subjects layout">
          <TweakRadio options={['List', 'Grid']} value={tweaks.subjectsLayout} onChange={(v) => setTweak('subjectsLayout', v)} />
        </TweakSection>
        <TweakSection title="Focus timer">
          <TweakRadio options={['Ice melt', 'Glass fill']} value={tweaks.focusTimer} onChange={(v) => setTweak('focusTimer', v)} />
        </TweakSection>
      </TweaksPanel>
    </>);

};

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
