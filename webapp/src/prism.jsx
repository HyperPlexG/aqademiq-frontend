/* ─── PRISM · focus soundscapes on the web ───────────────────────────────
   A Web Audio port of the app's engine (lib/sound_engine): four layers —
   a looping pad, a looping texture, pulse one-shots on a beat clock and
   stochastic sparks — through a master low-pass, reverb and pan LFO.
   Presets, stems, levels and timings follow the Dart code; the stems are
   the same .m4a files aqademiq.app streams. */

const PRISM_MODES = [
  { label: 'Deep Work', color: '#6B5CF0', glyph: 'state_deep_focus', desc: 'Low-freq focus carrier. Hard cognitive tasks.' },
  { label: 'Flow', color: '#2A9D6B', glyph: 'state_focus', desc: 'Smooth ambient. Sustained concentration.' },
  { label: 'Review', color: '#E8A430', glyph: 'state_creative', desc: 'Steady midtempo. Reading, flashcards, revision.' },
  { label: 'Wind-down', color: '#777777', glyph: 'state_relax', desc: 'Slow, calming. End-of-session decompression.' },
];
const PRISM_OFF = 'No sound';
const prismColor = (label) => (PRISM_MODES.find((m) => m.label === label) || { color: '#C0C0C0' }).color;

const PRISM_FILES = {
  padSlow: 'prism/pad-slow.mp4', padChoir: 'prism/pad-choir.mp4',
  rain: 'prism/tex-rain.mp4', hum: 'prism/tex-hum.mp4', sea: 'prism/tex-sea.mp4',
  dreams: 'prism/pulse-dreams.mp4', e808: 'prism/pulse-808.mp4',
  kalimba: 'prism/spark-kalimba.mp4', pluck: 'prism/spark-pluck.mp4', rBassy: 'prism/spark-rhodes-bassy.mp4', rFull: 'prism/spark-rhodes-full.mp4', rWarm: 'prism/spark-rhodes-warm.mp4',
};
// sound_manifest.dart: textures carry their noise colour, pulses their pick weight.
const PRISM_MANIFESTS = {
  focus: { pads: ['padSlow', 'padChoir'], textures: [['rain', 'pink'], ['hum', 'brown'], ['sea', 'pink']], pulses: [['dreams', 0.6], ['e808', 0.4]], sparks: ['kalimba', 'pluck', 'rBassy', 'rFull', 'rWarm'] },
  relax: { pads: ['padChoir'], textures: [['sea', 'pink']], pulses: [], sparks: ['rWarm'] },
  breakMode: { pads: ['padSlow'], textures: [['rain', 'pink']], pulses: [['dreams', 0.6]], sparks: [] },
};
const prismManifestKey = (label) => label === 'Review' ? 'breakMode' : label === 'Wind-down' ? 'relax' : 'focus';

// soundscape_params.dart defaults and presets (heart rate 72, as the app uses with no wearable).
const PRISM_BASE = { padReverbWet: 0.4, textureVolumeDb: -18, textureBrownNoise: false, pulseBpm: 72, pulseDensity: 1, pulseVolume: 0.6, sparkTriggerProb: 0.2, sparkPanLfoRate: 0.2, masterLpfCutoff: 8000, masterGain: 0.8 };
function prismPreset(label) {
  if (label === 'Review') return { ...PRISM_BASE, pulseBpm: 60, pulseVolume: 0.3, padReverbWet: 0.6, masterLpfCutoff: 3000, textureVolumeDb: -24 };
  if (label === 'Wind-down') return { ...PRISM_BASE, masterLpfCutoff: 600, textureBrownNoise: true, pulseBpm: 62, sparkTriggerProb: 0.05, masterGain: 0.5, pulseVolume: 0, padReverbWet: 0.55, sparkPanLfoRate: 0.1 };
  const focus = { ...PRISM_BASE, masterLpfCutoff: 18000, pulseBpm: 77, masterGain: 1, pulseVolume: 0.8, pulseDensity: 2, sparkTriggerProb: 0.3 };
  if (label === 'Flow') return { ...focus, pulseDensity: 1, pulseVolume: focus.pulseVolume * 0.6, masterLpfCutoff: 8000, sparkTriggerProb: 0.15 };
  return focus; // Deep Work
}
const DEFAULT_PRISM = { mode: 'Deep Work', autoplay: true, master: 0.8, env: 0.6, rhythm: 0.4 };

const PAD_VOLUME = 0.6, SPARK_VOLUME = 0.4, SPARK_PAN = 0.7, SPARK_GAP = 3, MAX_SPARKS = 8;
const FADE_START = 5, FADE_MODE = 10, FADE_QUICK = 3;

class PrismEngine {
  constructor() {
    this.ctx = null; this.buffers = new Map(); this.loads = new Map();
    this.state = 'stopped'; // stopped | loading | playing | paused | blocked | error
    this.label = null; this.vol = { ...DEFAULT_PRISM };
    this.gen = 0; this.pauseTok = 0; this.loops = []; this.pad = null; this.tex = null; this.sparks = new Set();
    this.timer = 0; this.nextBeat = 0; this.nextSpark = 0; this.lastSpark = -99; this.params = prismPreset('Deep Work');
    this.subs = new Set(); this.error = '';
  }
  on(fn) { this.subs.add(fn); return () => this.subs.delete(fn); }
  emit() { this.subs.forEach((f) => f(this.state, this.label)); }
  set(state) { this.state = state; this.emit(); }

  // Browsers only allow audio after a tap: call this inside a click handler.
  unlock() {
    try {
      if (!this.ctx) {
        const C = window.AudioContext || window.webkitAudioContext;
        if (!C) { this.error = 'This browser can\'t play Prism.'; return false; }
        this.ctx = new C();
        this.buildDsp();
      }
      if (this.ctx.state === 'suspended') this.ctx.resume().catch(() => {});
      // iPhone: play even with the ring/silent switch on, like the app.
      try { if (navigator.audioSession) navigator.audioSession.type = 'playback'; } catch (e) { /* older Safari */ }
      return true;
    } catch (e) { this.error = 'This browser can\'t play Prism.'; return false; }
  }
  get unlocked() { return !!this.ctx && this.ctx.state === 'running'; }

  // Decode a mode's stems ahead of time. A context made without a tap starts
  // suspended, which is fine for decoding; unlock() resumes it on the tap.
  prefetch(label) {
    if (!label || label === PRISM_OFF) return;
    try {
      if (!this.ctx) {
        const C = window.AudioContext || window.webkitAudioContext;
        if (!C) return;
        this.ctx = new C();
        this.buildDsp();
      }
      this.loadManifest(PRISM_MANIFESTS[prismManifestKey(label)]).catch(() => {});
    } catch (e) { /* no audio here: Play shows the reason */ }
  }

  buildDsp() {
    const c = this.ctx;
    this.input = c.createGain();
    this.lpf = c.createBiquadFilter(); this.lpf.type = 'lowpass'; this.lpf.frequency.value = 8000; this.lpf.Q.value = 2;
    this.reverb = c.createConvolver(); this.reverb.buffer = this.impulse(2.6, 2.4);
    this.dry = c.createGain(); this.wet = c.createGain(); this.dry.gain.value = 0.6; this.wet.gain.value = 0.4;
    this.run = c.createGain(); this.run.gain.value = 0;     // play/freeze/stop fades
    this.master = c.createGain(); this.master.gain.value = 0.8; // preset gain × your Master volume
    this.input.connect(this.lpf); this.lpf.connect(this.dry); this.lpf.connect(this.reverb); this.reverb.connect(this.wet);
    this.dry.connect(this.run); this.wet.connect(this.run); this.run.connect(this.master); this.master.connect(c.destination);
    // Spark pan LFO: ±0.7 sine, rescaled to the ±0.3 wobble around each spark's placement (dsp_chain.dart).
    this.lfo = c.createOscillator(); this.lfo.frequency.value = 0.2;
    this.lfoDepth = c.createGain(); this.lfoDepth.gain.value = 0.3;
    this.lfo.connect(this.lfoDepth); this.lfo.start();
  }
  impulse(seconds, decay) {
    const c = this.ctx, len = Math.floor(c.sampleRate * seconds), buf = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) { const d = buf.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay); }
    return buf;
  }
  ramp(param, value, seconds) {
    const t = this.ctx.currentTime;
    param.cancelScheduledValues(t);
    param.setValueAtTime(param.value, t);
    param.linearRampToValueAtTime(value, t + Math.max(0.01, seconds));
  }

  load(key) {
    if (this.buffers.has(key)) return Promise.resolve(this.buffers.get(key));
    if (!this.loads.has(key)) {
      this.loads.set(key, fetch(PRISM_FILES[key]).then((r) => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); })
        .then((ab) => new Promise((res, rej) => this.ctx.decodeAudioData(ab, res, rej)))
        .then((b) => { this.buffers.set(key, b); return b; })
        .catch((e) => { this.loads.delete(key); throw e; }));
    }
    return this.loads.get(key);
  }
  async loadManifest(m) {
    const keys = [...m.pads, ...m.textures.map((t) => t[0]), ...m.pulses.map((p) => p[0]), ...m.sparks];
    const got = await Promise.allSettled(keys.map((k) => this.load(k)));
    if (!got.some((g) => g.status === 'fulfilled')) throw new Error('no stems');
  }

  effective(label) {
    const p = prismPreset(label), v = this.vol;
    return { ...p, texLinear: Math.min(1, Math.pow(10, p.textureVolumeDb / 20) * v.env), pulseLinear: Math.min(1, p.pulseVolume * v.rhythm), masterLinear: Math.min(1, p.masterGain * v.master) };
  }
  applyBus(p, seconds) {
    this.ramp(this.lpf.frequency, Math.min(20000, Math.max(200, p.masterLpfCutoff)), seconds);
    this.ramp(this.wet.gain, p.padReverbWet, seconds);
    this.ramp(this.dry.gain, 1 - p.padReverbWet, seconds);
    this.ramp(this.master.gain, p.masterLinear, seconds);
    this.ramp(this.lfo.frequency, p.sparkPanLfoRate, seconds);
  }
  loop(key, target, fade) {
    const b = this.buffers.get(key);
    if (!b) return null;
    const src = this.ctx.createBufferSource(); src.buffer = b; src.loop = true;
    const g = this.ctx.createGain(); g.gain.value = 0;
    src.connect(g); g.connect(this.input); src.start();
    this.ramp(g.gain, target, fade);
    const v = { src, g }; this.loops.push(v); return v;
  }
  retire(v, fade) {
    if (!v) return;
    this.ramp(v.g.gain, 0, fade);
    setTimeout(() => { try { v.src.stop(); } catch (e) { /* already stopped */ } v.g.disconnect(); this.loops = this.loops.filter((x) => x !== v); }, fade * 1000 + 200);
  }
  // A random pad and the noise-colour-matched texture (stem_layer_manager.dart _startPad/_selectTexture).
  choose(m, p) {
    const pad = m.pads[Math.floor(Math.random() * m.pads.length)] || null;
    const wanted = p.textureBrownNoise ? 'brown' : 'pink';
    const tex = (m.textures.find((t) => t[1] === wanted) || m.textures[0] || [])[0] || null;
    return { pad, tex };
  }
  // The loops are what you hear first: wait for those two, fetch the one-shots behind them.
  async loadLoops(m, pick) {
    const need = [pick.pad, pick.tex].filter(Boolean);
    const got = await Promise.allSettled(need.map((k) => this.load(k)));
    this.loadManifest(m).catch(() => {});
    if (need.length && !got.some((g) => g.status === 'fulfilled')) throw new Error('no loops');
  }
  startLayers(pick, p, fade) {
    this.pad = pick.pad && this.buffers.has(pick.pad) ? this.loop(pick.pad, PAD_VOLUME, fade) : null;
    this.tex = pick.tex && this.buffers.has(pick.tex) ? this.loop(pick.tex, p.texLinear, fade) : null;
  }

  // Lookahead clock (audio time), so beats stay steady even when the tab is in the background.
  startClock() {
    clearInterval(this.timer);
    const now = this.ctx.currentTime;
    this.nextBeat = now + 0.1; this.nextSpark = now + 1;
    this.timer = setInterval(() => this.tick(), 200);
    this.tick();
  }
  stopClock() { clearInterval(this.timer); this.timer = 0; }
  tick() {
    if (this.state !== 'playing') return;
    const now = this.ctx.currentTime;
    // After a stall (a throttled background tab), skip missed beats rather than firing them all at once.
    if (this.nextBeat < now) this.nextBeat = now + 0.05;
    if (this.nextSpark < now) this.nextSpark = now + 0.05;
    const m = PRISM_MANIFESTS[prismManifestKey(this.label)], p = this.params, ahead = now + 1.5;
    const beat = 60 / Math.min(300, Math.max(20, p.pulseBpm));
    while (this.nextBeat < ahead) {
      this.pulse(m, p, this.nextBeat);
      if (p.pulseDensity > 1.5) this.pulse(m, p, this.nextBeat + beat / 2);
      this.nextBeat += beat;
    }
    while (this.nextSpark < ahead) { this.spark(m, p, this.nextSpark); this.nextSpark += 1; }
  }
  pulse(m, p, when) {
    if (!m.pulses.length || p.pulseLinear <= 0) return;
    const total = m.pulses.reduce((a, x) => a + x[1], 0);
    let roll = Math.random() * total, key = m.pulses[m.pulses.length - 1][0];
    for (const [k, w] of m.pulses) { roll -= w; if (roll <= 0) { key = k; break; } }
    const b = this.buffers.get(key);
    if (!b) return;
    const src = this.ctx.createBufferSource(); src.buffer = b;
    const g = this.ctx.createGain(); g.gain.value = p.pulseLinear;
    src.connect(g); g.connect(this.input); src.start(when);
    src.onended = () => g.disconnect();
  }
  spark(m, p, when) {
    if (!m.sparks.length || when - this.lastSpark < SPARK_GAP || Math.random() > p.sparkTriggerProb || this.sparks.size >= MAX_SPARKS) return;
    const b = this.buffers.get(m.sparks[Math.floor(Math.random() * m.sparks.length)]);
    if (!b) return;
    this.lastSpark = when;
    const src = this.ctx.createBufferSource(); src.buffer = b;
    const pan = this.ctx.createStereoPanner ? this.ctx.createStereoPanner() : null;
    const g = this.ctx.createGain(); g.gain.value = SPARK_VOLUME;
    if (pan) { pan.pan.value = (Math.random() * 2 - 1) * SPARK_PAN; this.lfoDepth.connect(pan.pan); src.connect(pan); pan.connect(g); } else src.connect(g);
    g.connect(this.input); src.start(when);
    this.sparks.add(src);
    src.onended = () => { this.sparks.delete(src); if (pan) { try { this.lfoDepth.disconnect(pan.pan); } catch (e) { /* gone */ } } g.disconnect(); };
  }

  async start(label) {
    if (label === PRISM_OFF) { this.stop(); return; }
    if (!this.ctx) { this.label = label; this.set('blocked'); return; }
    // Take the token first: a stop() while resume() is pending must win.
    const gen = ++this.gen;
    this.pauseTok++;
    if (this.ctx.state !== 'running') { try { await this.ctx.resume(); } catch (e) { /* stays suspended */ } }
    if (gen !== this.gen) return;
    if (this.ctx.state !== 'running') { this.label = label; this.set('blocked'); return; }
    this.hardStop();
    this.label = label; this.set('loading');
    const m = PRISM_MANIFESTS[prismManifestKey(label)];
    const pick = this.choose(m, this.effective(label));
    try { await this.loadLoops(m, pick); } catch (e) { if (gen === this.gen) { this.error = 'Prism\'s sounds couldn\'t load. Check your connection.'; this.set('error'); } return; }
    if (gen !== this.gen) return;
    const p = this.params = this.effective(label);
    this.applyBus(p, 0.05);
    this.startLayers(pick, p, FADE_START);
    this.ramp(this.run.gain, 1, 0.3);
    this.set('playing');
    this.startClock();
  }
  async switchMode(label) {
    if (label === PRISM_OFF) { this.stop(); return; }
    if (this.state === 'loading') { this.start(label); return; } // restart the load for the new mode
    if (this.state !== 'playing' && this.state !== 'paused') { this.label = label; this.emit(); return; }
    if (label === this.label) return;
    const gen = ++this.gen, wasPaused = this.state === 'paused';
    const m = PRISM_MANIFESTS[prismManifestKey(label)];
    this.label = label; this.emit();
    const pick = this.choose(m, this.effective(label));
    try { await this.loadLoops(m, pick); } catch (e) { return; }
    if (gen !== this.gen) return;
    const p = this.params = this.effective(label);
    const oldPad = this.pad, oldTex = this.tex;
    this.startLayers(pick, p, wasPaused ? 0.05 : FADE_MODE);
    this.retire(oldPad, wasPaused ? 0.05 : FADE_MODE); this.retire(oldTex, wasPaused ? 0.05 : FADE_MODE);
    this.applyBus(p, wasPaused ? 0.05 : 5);
    if (!wasPaused) { this.nextBeat = Math.max(this.nextBeat, this.ctx.currentTime + 0.1); }
  }
  setVolumes(v) {
    this.vol = { ...this.vol, ...v };
    if (!this.ctx || (this.state !== 'playing' && this.state !== 'paused')) return;
    const p = this.params = this.effective(this.label);
    this.ramp(this.master.gain, p.masterLinear, 0.4);
    if (this.tex) this.ramp(this.tex.g.gain, p.texLinear, 0.4);
  }
  pause() {
    if (this.state !== 'playing') return;
    this.stopClock();
    this.set('paused');
    this.ramp(this.run.gain, 0, FADE_QUICK);
    // Its own token: Freeze → Resume → Freeze inside 3 s must not cut the second fade short.
    const tok = ++this.pauseTok;
    setTimeout(() => { if (this.state === 'paused' && tok === this.pauseTok && this.ctx) this.ctx.suspend().catch(() => {}); }, FADE_QUICK * 1000 + 100);
  }
  async resume() {
    if (this.state !== 'paused') return;
    this.pauseTok++;
    try { await this.ctx.resume(); } catch (e) { /* ignore */ }
    if (this.state !== 'paused') return; // stopped or restarted while waiting
    if (this.ctx.state !== 'running') { this.set('blocked'); return; }
    this.set('playing');
    this.ramp(this.run.gain, 1, FADE_QUICK);
    this.startClock();
  }
  stop() {
    this.gen++;
    this.pauseTok++;
    this.stopClock();
    if (!this.ctx || this.state === 'stopped') { this.set('stopped'); return; }
    const loops = this.loops.slice(), sparks = [...this.sparks];
    this.loops = []; this.pad = this.tex = null; this.sparks.clear();
    if (this.ctx.state === 'running') this.ramp(this.run.gain, 0, FADE_QUICK);
    setTimeout(() => {
      loops.forEach((v) => { try { v.src.stop(); } catch (e) { /* ok */ } v.g.disconnect(); });
      sparks.forEach((s) => { try { s.stop(); } catch (e) { /* ok */ } });
    }, FADE_QUICK * 1000 + 100);
    this.set('stopped');
  }
  hardStop() {
    this.stopClock();
    this.loops.forEach((v) => { try { v.src.stop(); } catch (e) { /* ok */ } v.g.disconnect(); });
    this.sparks.forEach((s) => { try { s.stop(); } catch (e) { /* ok */ } });
    this.loops = []; this.pad = this.tex = null; this.sparks.clear();
    if (this.ctx) { this.run.gain.cancelScheduledValues(this.ctx.currentTime); this.run.gain.value = 0; }
  }
}
const PRISM = new PrismEngine();
window.__prism = PRISM;
// Whether this focus session wants sound: Autoplay at start, or an explicit pick/stop mid-session.
const prismWant = { current: true, preview: false };

function usePrismState() {
  const [st, setSt] = React.useState([PRISM.state, PRISM.label]);
  React.useEffect(() => PRISM.on((a, b) => setSt([a, b])), []);
  return st;
}

/* The Prism picker (Focus): modes, No sound, and the Autoplay toggle. */
function PrismMenu({ current, autoplay, onPick, onAutoplay, onClose }) {
  return (
    <div className="menu prism-menu" role="menu" aria-label="Prism mode">
      <div className="label" style={{ margin: '8px 12px 4px' }}>Prism</div>
      {PRISM_MODES.map((m) =>
      <button key={m.label} role="menuitemradio" aria-checked={current === m.label} onClick={() => onPick(m.label)} style={{ height: 'auto', padding: '10px 12px', alignItems: 'flex-start' }}>
          <Ic n={m.glyph} style={{ fontSize: 22, color: m.color, marginTop: 1 }} />
          <span style={{ flex: 1 }}><span style={{ display: 'block' }}>{m.label}</span><span className="small" style={{ display: 'block', fontWeight: 500 }}>{m.desc}</span></span>
          {current === m.label && <Ic n="check" style={{ fontSize: 18, color: ACC, marginTop: 2 }} />}
        </button>)}
      <button role="menuitemradio" aria-checked={current === PRISM_OFF} onClick={() => onPick(PRISM_OFF)}>
        <Ic n="mute" style={{ fontSize: 22, color: DIM }} /><span style={{ flex: 1 }}>No sound</span>{current === PRISM_OFF && <Ic n="check" style={{ fontSize: 18, color: ACC }} />}
      </button>
      <label className="spread" style={{ borderTop: `1px solid ${BORDER}`, margin: '4px 0 0', padding: '12px 12px 8px', fontSize: 15, fontWeight: 700, cursor: 'pointer' }}>
        Autoplay Prism
        <input type="checkbox" className="switch" checked={autoplay} onChange={(e) => onAutoplay(e.target.checked)} />
      </label>
    </div>);
}
