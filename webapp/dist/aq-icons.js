/* Aqademiq icon pack: geometry source of truth (24 x 24, stroke-centred). */
(function () {
  var r2 = function (n) { return Math.round(n * 100) / 100; };
  var rad = function (d) { return d * Math.PI / 180; };

  /* Continuous (squircle) rounded rect, 60% smoothing, radius at stroke centre.
     Starts at top centre, runs clockwise (the cube timer relies on this). */
  function rect(x, y, w, h, r, tail) {
    var s = 0.6, budget = Math.min(w, h) / 2;
    if ((1 + s) * r > budget) s = Math.max(0, Math.min(s, budget / r - 1));
    var p = Math.min((1 + s) * r, budget);
    var am = 90 * (1 - s);
    var arc = Math.sin(rad(am / 2)) * r * Math.SQRT2;
    var alpha = (90 - am) / 2;
    var p34 = r * Math.tan(rad(alpha / 2));
    var beta = 45 * s;
    var c = p34 * Math.cos(rad(beta));
    var d = c * Math.tan(rad(beta));
    var b = (p - arc - c - d) / 3, a = 2 * b;
    var A = r2(a), AB = r2(a + b), ABC = r2(a + b + c), BC = r2(b + c), C = r2(c), D = r2(d), ARC = r2(arc), R = r2(r);
    var TR = 'c' + A + ' 0 ' + AB + ' 0 ' + ABC + ' ' + D + 'a' + R + ' ' + R + ' 0 0 1 ' + ARC + ' ' + ARC + 'c' + D + ' ' + C + ' ' + D + ' ' + BC + ' ' + D + ' ' + ABC;
    var BR = 'c0 ' + A + ' 0 ' + AB + ' ' + (-D) + ' ' + ABC + 'a' + R + ' ' + R + ' 0 0 1 ' + (-ARC) + ' ' + ARC + 'c' + (-C) + ' ' + D + ' ' + (-BC) + ' ' + D + ' ' + (-ABC) + ' ' + D;
    var BL = 'c' + (-A) + ' 0 ' + (-AB) + ' 0 ' + (-ABC) + ' ' + (-D) + 'a' + R + ' ' + R + ' 0 0 1 ' + (-ARC) + ' ' + (-ARC) + 'c' + (-D) + ' ' + (-C) + ' ' + (-D) + ' ' + (-BC) + ' ' + (-D) + ' ' + (-ABC);
    var TL = 'c0 ' + (-A) + ' 0 ' + (-AB) + ' ' + D + ' ' + (-ABC) + 'a' + R + ' ' + R + ' 0 0 1 ' + ARC + ' ' + (-ARC) + 'c' + C + ' ' + (-D) + ' ' + BC + ' ' + (-D) + ' ' + ABC + ' ' + (-D);
    return 'M' + r2(x + w / 2) + ' ' + y + 'H' + r2(x + w - p) + TR + 'V' + r2(y + h - p) + BR + (tail || '') +
      'H' + r2(x + p) + BL + 'V' + r2(y + p) + TL + 'Z';
  }
  function circ(cx, cy, r) { return 'M' + cx + ' ' + r2(cy - r) + 'A' + r + ' ' + r + ' 0 1 1 ' + cx + ' ' + r2(cy + r) + 'A' + r + ' ' + r + ' 0 1 1 ' + cx + ' ' + r2(cy - r) + 'Z'; }
  function dots(pts) { return pts.map(function (p) { return circ(p[0], p[1], 0.6); }).join(''); }
  function pt(cx, cy, r, deg) { return r2(cx + r * Math.cos(rad(deg))) + ' ' + r2(cy + r * Math.sin(rad(deg))); }
  function star(cx, cy, R, ri) {
    var s = '';
    for (var i = 0; i < 10; i++) s += (i ? 'L' : 'M') + pt(cx, cy, i % 2 ? ri : R, -90 + i * 36);
    return s + 'Z';
  }
  function gear(cx, cy, R, rv) {
    var s = '';
    for (var k = 0; k < 6; k++) {
      var a = -90 + k * 60;
      s += (k ? 'L' : 'M') + pt(cx, cy, rv, a - 17) + 'L' + pt(cx, cy, R, a - 11) + 'A' + R + ' ' + R + ' 0 0 1 ' + pt(cx, cy, R, a + 11) +
        'L' + pt(cx, cy, rv, a + 17) + 'A' + rv + ' ' + rv + ' 0 0 1 ' + pt(cx, cy, rv, a + 43);
    }
    return s + 'Z';
  }
  function rays(cx, cy, r1, r2_, n) {
    var s = '';
    for (var k = 0; k < n; k++) { var a = -90 + k * 360 / n; s += 'M' + pt(cx, cy, r1, a) + 'L' + pt(cx, cy, r2_, a); }
    return s;
  }
  function flake(cx, cy, R, b0, bl) {
    var arms = '', tips = '';
    for (var k = 0; k < 3; k++) { var a = -90 + k * 60; arms += 'M' + pt(cx, cy, R, a) + 'L' + pt(cx, cy, R, a + 180); }
    for (var j = 0; j < 6; j++) {
      var a2 = -90 + j * 60, bx = cx + b0 * Math.cos(rad(a2)), by = cy + b0 * Math.sin(rad(a2));
      tips += 'M' + pt(bx, by, bl, a2 - 45) + 'L' + r2(bx) + ' ' + r2(by) + 'L' + pt(bx, by, bl, a2 + 45);
    }
    return [arms, tips];
  }
  function crystal(cx, cy, L) { return 'M' + cx + ' ' + (cy - L) + 'V' + (cy + L) + 'M' + pt(cx, cy, L, 210) + 'L' + pt(cx, cy, L, 30) + 'M' + pt(cx, cy, L, 150) + 'L' + pt(cx, cy, L, -30); }

  var PL_BODY = rect(3, 5, 18, 15.5, 3);
  var RINGS = 'M8 3V6.75M16 3V6.75';
  var CUBE = rect(3, 3, 18, 18, 4);
  var TILE = rect(3, 3, 18, 18, 4.5);
  var GLINT = 'M7 11.5V9.4C7 8.07 8.07 7 9.4 7H10.75';
  var CRACK = 'M16 3L15 6L17.25 8';
  var BUBBLE = rect(3, 4, 18, 13.75, 3, 'H12.5L9 21V17.75');
  var WAVE = 'M7.5 10.88C9 7.88 10.5 7.88 12 10.88S15 13.88 16.5 10.88';
  var DROP = 'M12 2.9C10.2 5.4 5.5 10 5.5 14.5A6.5 6.5 0 0 0 18.5 14.5C18.5 10 13.8 5.4 12 2.9Z';
  var BELL = 'M5 17.5H19M6.5 17.5V11A5.5 5.5 0 0 1 17.5 11V17.5M12 3.25V5.5M10 20.75H14';
  var EYE = 'M3.25 12C5.25 7.75 8.4 5.5 12 5.5S18.75 7.75 20.75 12C18.75 16.25 15.6 18.5 12 18.5S5.25 16.25 3.25 12Z';
  var SPEAKER = 'M4 9.5H7.5L12 5.5V18.5L7.5 14.5H4Z';
  var MOON = 'M19.5 14.25A8 8 0 1 1 9.75 4.5A6.9 6.9 0 0 0 19.5 14.25Z';
  var HORIZON = 'M3.5 16.5H20.5M8 20.5H16M7 16.5A5 5 0 0 1 17 16.5';
  var TRAY = 'M4 15V17.5A3 3 0 0 0 7 20.5H17A3 3 0 0 0 20 17.5V15';
  var SLASH = 'M4 4L20 20';
  var C9 = circ(12, 12, 9);
  var FLAKE = flake(12, 12, 9, 6, 2.5);
  var ORBIT = (function () {
    var dash = '', dot = '', R = 8;
    for (var k = 0; k < 10; k++) {
      var a = -90 + k * 36;
      if (k === 0 || k === 4 || k === 7) dot += circ(r2(12 + R * Math.cos(rad(a))), r2(12 + R * Math.sin(rad(a))), 1.1);
      else dash += 'M' + pt(12, 12, R, a - 6) + 'A' + R + ' ' + R + ' 0 0 1 ' + pt(12, 12, R, a + 6);
    }
    return [dash, dot];
  })();
  var ADA_BUBBLE = rect(3, 3, 18, 15, 4, 'H13.5C12.25 18 11.5 19.75 10 21C9.75 19.75 9.5 18.75 9.5 18');
  var CURVE = 'M3.5 16C6 16 7 11 9.75 11S12.5 14 14.75 14S18.5 7 20.5 7';

  function L(id, d, extra) { var o = { id: id, d: d }; for (var k in extra) o[k] = extra[k]; return o; }
  var B = { role: 'body' }, K = { role: 'knock' }, CUT = { role: 'cut' }, PAINT = { paint: true };

  /* role: body = filled in fill variant · knock = cut out of the fill (mask) · cut = slash that clears a gap through what it crosses.
     Layer order = animation order. */
  var ICONS = {
    /* Tabs */
    subjects: { label: 'Subjects', keyline: 'Portrait', fill: true, layers: [L('body', rect(4.5, 3, 15, 18, 3), B), L('spine', 'M8.5 3.5V20.5', { role: 'knock', fd: 'M8.5 5.75V18.25' }), L('ribbon', 'M13 3.25V9L14.75 7.6L16.5 9V3.25', K)] },
    planner: { label: 'Planner', keyline: 'Square', fill: true, layers: [L('body', PL_BODY, B), L('rings', RINGS), L('blocks', 'M7.5 11.5H12M11 15.5H16.5', K)] },
    focus: { label: 'Focus', keyline: 'Circle', fill: true, layers: [L('body', 'M12 5.5A7.75 7.75 0 1 1 12 21A7.75 7.75 0 1 1 12 5.5Z', B), L('crown', 'M10.5 2.9H13.5M12 2.9V5.5'), L('hand', 'M12 13.25L14.13 9.57', K)] },
    insights: { label: 'Insights', keyline: 'Landscape', fill: true, layers: [L('trend', CURVE), L('base', 'M3.5 20.5H20.5')], fillLayers: [L('area', CURVE + 'V20.5H3.5Z', B)] },
    /* Navigation */
    back: { label: 'Back', layers: [L('chevron', 'M14.5 5.5L8 12L14.5 18.5')] },
    forward: { label: 'Next', layers: [L('arrow', 'M4.5 12H19M13.5 6.5L19 12L13.5 17.5')] },
    close: { label: 'Close', layers: [L('x', 'M6.5 6.5L17.5 17.5M17.5 6.5L6.5 17.5')] },
    chevron_right: { label: 'Open', layers: [L('chevron', 'M9.5 5.5L16 12L9.5 18.5')] },
    chevron_down: { label: 'Expand', layers: [L('chevron', 'M5.5 9L12 15.5L18.5 9')] },
    chevron_up: { label: 'Collapse', layers: [L('chevron', 'M5.5 15L12 8.5L18.5 15')] },
    more: { label: 'More', layers: [L('dots', dots([[6, 12], [12, 12], [18, 12]]))] },
    more_vertical: { label: 'More', layers: [L('dots', dots([[12, 6], [12, 12], [12, 18]]))] },
    search: { label: 'Search', keyline: 'Circle', layers: [L('lens', circ(10.75, 10.75, 6.75)), L('handle', 'M15.75 15.75L20.25 20.25')] },
    /* Actions */
    add: { label: 'Add', layers: [L('plus', 'M12 5.5V18.5M5.5 12H18.5')] },
    remove: { label: 'Remove', layers: [L('minus', 'M5.5 12H18.5')] },
    edit: { label: 'Edit', layers: [L('pencil', 'M15.25 4.75A2.83 2.83 0 0 1 19.25 8.75L8.5 19.5H4.5V15.5Z'), L('ferrule', 'M12.75 7.25L16.75 11.25')] },
    delete: { label: 'Delete', layers: [L('lid', 'M4.5 6.5H19.5M9.5 6.5V5A1.5 1.5 0 0 1 11 3.5H13A1.5 1.5 0 0 1 14.5 5V6.5'), L('can', 'M6.5 6.5L7.4 18.7A2 2 0 0 0 9.4 20.5H14.6A2 2 0 0 0 16.6 18.7L17.5 6.5')] },
    share: { label: 'Share', layers: [L('arrow', 'M4.5 19C4.5 13.5 8 10 13.5 10H19.5M15.5 6L19.5 10L15.5 14')] },
    check: { label: 'Done', layers: [L('tick', 'M5 12.5L9.75 17.25L19 7.75')] },
    check_circle: { label: 'Completed', keyline: 'Circle', fill: true, layers: [L('ring', C9, B), L('tick', 'M8 12.25L11 15.25L16.25 9.5', K)] },
    sort: { label: 'Sort', layers: [L('up', 'M8 19V5M4.5 8.5L8 5L11.5 8.5'), L('down', 'M16 5V19M12.5 15.5L16 19L19.5 15.5')] },
    drag: { label: 'Reorder', layers: [L('dots', dots([[9, 6], [15, 6], [9, 12], [15, 12], [9, 18], [15, 18]]))] },
    adjust: { label: 'Adjust', layers: [L('track1', 'M4 8H11.75M16.25 8H20'), L('knob1', circ(14, 8, 2.25)), L('track2', 'M4 16H7.75M12.25 16H20'), L('knob2', circ(10, 16, 2.25))] },
    list_view: { label: 'List view', layers: [L('bullets', dots([[5, 7], [5, 12], [5, 17]])), L('lines', 'M9 7H19.5M9 12H19.5M9 17H19.5')] },
    sync: { label: 'Sync', keyline: 'Circle', layers: [L('arc1', 'M4.5 12A7.5 7.5 0 0 1 17.3 6.7M13.8 6.7H17.3V3.2'), L('arc2', 'M19.5 12A7.5 7.5 0 0 1 6.7 17.3M10.2 17.3H6.7V20.8')] },
    send: { label: 'Send', layers: [L('arrow', 'M12 19.5V4.5M6 10.5L12 4.5L18 10.5')] },
    /* Time */
    time: { label: 'Time', keyline: 'Circle', layers: [L('face', C9), L('hands', 'M12 7V12L15.25 14')] },
    date: { label: 'Date', layers: [L('body', PL_BODY), L('rings', RINGS), L('day', rect(12.5, 12, 4.5, 4.5, 1.7))] },
    repeat: { label: 'Repeat', layers: [L('top', 'M4.5 11.5V10A3 3 0 0 1 7.5 7H19.5M16.5 4L19.5 7L16.5 10'), L('bottom', 'M19.5 12.5V14A3 3 0 0 1 16.5 17H4.5M7.5 14L4.5 17L7.5 20')] },
    duration: { label: 'Duration', keyline: 'Portrait', layers: [L('caps', 'M6.5 3.5H17.5M6.5 20.5H17.5'), L('glass', 'M8 3.5V6.5C8 9 12 10.5 12 12C12 13.5 8 15 8 17.5V20.5M16 3.5V6.5C16 9 12 10.5 12 12C12 13.5 16 15 16 17.5V20.5')] },
    reminder: { label: 'Reminder', keyline: 'Circle', layers: [L('face', circ(12, 13, 7.5)), L('hands', 'M12 9.5V13L14.5 14.5'), L('ears', 'M3.25 6L6 3.5M20.75 6L18 3.5')] },
    history: { label: 'History', keyline: 'Circle', layers: [L('arc', 'M4.64 7.75A8.5 8.5 0 1 1 3.5 12'), L('head', 'M8 6.85L4.64 7.75L3.75 4.4'), L('hands', 'M12 7.5V12L15 13.75')] },
    carry_forward: { label: 'Moved to another day', fill: true, layers: [L('body', PL_BODY, B), L('rings', RINGS), L('arrow', 'M7.5 13.5H16M13 10.5L16 13.5L13 16.5', K)] },
    /* Session and sound */
    play: { label: 'Play', layers: [L('triangle', 'M8.5 5.5V18.5L19 12Z')] },
    pause: { label: 'Pause', layers: [L('bars', 'M9 5.5V18.5M15 5.5V18.5')] },
    end: { label: 'End session', layers: [L('square', rect(6, 6, 12, 12, 3))] },
    prism: { label: 'Prism', layers: [L('outer', 'M12 3L21 12L12 21L3 12Z'), L('inner', 'M12 8.5L15.5 12L12 15.5L8.5 12Z')] },
    mute: { label: 'Sound off', layers: [L('speaker', SPEAKER), L('x', 'M15.5 9.5L20.5 14.5M20.5 9.5L15.5 14.5')] },
    haptics: { label: 'Haptics', keyline: 'Portrait', layers: [L('phone', rect(8, 3, 8, 18, 3)), L('buzz', 'M4.5 9V15M19.5 9V15')] },
    mic: { label: 'Voice', keyline: 'Portrait', layers: [L('capsule', rect(9, 3, 6, 11, 3)), L('stand', 'M5.5 11.5A6.5 6.5 0 0 0 18.5 11.5M12 18V21')] },
    notifications: { label: 'Notifications', layers: [L('bell', BELL)] },
    notifications_off: { label: 'Notifications off', layers: [L('bell', BELL), L('slash', SLASH, CUT)] },
    /* App freeze */
    freeze: { label: 'App freeze', keyline: 'Circle', layers: [L('arms', FLAKE[0]), L('tips', FLAKE[1])] },
    thaw: { label: 'Thaw', layers: [L('tile', TILE), L('drop', 'M12 7.25C11.2 8.4 9 10.75 9 13.25A3 3 0 0 0 15 13.25C15 10.75 12.8 8.4 12 7.25Z')] },
    shield: { label: 'Shield', keyline: 'Portrait', layers: [L('shield', 'M12 3L19.25 5.75V11.25C19.25 15.6 16.25 19.25 12 21C7.75 19.25 4.75 15.6 4.75 11.25V5.75Z'), L('glint', 'M8.25 11.5V9.5C8.25 8.67 8.92 8 9.75 8H11.25')] },
    never_open: { label: 'Never open', keyline: 'Circle', layers: [L('ring', C9), L('crystal', crystal(12, 12, 4.75))] },
    always_open: { label: 'Always open', keyline: 'Landscape', layers: [L('loop', 'M12 12C10 9.5 8.5 8.5 6.75 8.5A3.5 3.5 0 0 0 6.75 15.5C8.5 15.5 10 14.5 12 12C14 9.5 15.5 8.5 17.25 8.5A3.5 3.5 0 0 1 17.25 15.5C15.5 15.5 14 14.5 12 12Z')] },
    groups: { label: 'Groups', layers: [L('back', 'M7 3.25H17.75A3 3 0 0 1 20.75 6.25V17'), L('front', rect(3, 7.5, 13.5, 13.5, 3))] },
    wind_down: { label: 'Wind down', keyline: 'Circle', layers: [L('moon', MOON), L('star', circ(15.25, 8.75, 0.6))] },
    /* Day and Ada */
    morning: { label: 'Morning', keyline: 'Landscape', layers: [L('horizon', HORIZON), L('rays', 'M12 6.25V8.25M6.17 10.67L4.75 9.25M17.83 10.67L19.25 9.25')] },
    evening: { label: 'Evening', keyline: 'Landscape', layers: [L('horizon', HORIZON), L('arrow', 'M12 3.5V8.25M9.75 6L12 8.25L14.25 6')] },
    chats: { label: 'Conversations with Ada', keyline: 'Square', fill: true, layers: [L('bubble', ADA_BUBBLE, B), L('eyes', 'M7.75 9.75Q9 7.5 10.25 9.75M13.75 9.75Q15 7.5 16.25 9.75', K), L('smile', 'M9.5 13.25Q12 15.5 14.5 13.25', K)] },
    /* Account and system */
    profile: { label: 'Profile', layers: [L('head', circ(12, 7.5, 3.5)), L('shoulders', 'M4.5 20.5C4.5 16.75 7.75 14.5 12 14.5S19.5 16.75 19.5 20.5')] },
    settings: { label: 'Settings', keyline: 'Circle', layers: [L('gear', gear(12, 12, 9, 6.75)), L('hub', circ(12, 12, 3))] },
    sign_out: { label: 'Sign out', layers: [L('door', 'M10 4H6.5A2.5 2.5 0 0 0 4 6.5V17.5A2.5 2.5 0 0 0 6.5 20H10'), L('arrow', 'M9.5 12H20M16.5 8.5L20 12L16.5 15.5')] },
    help: { label: 'Help', keyline: 'Circle', layers: [L('ring', C9), L('mark', 'M9.5 9.5A2.5 2.5 0 1 1 13.5 11.5C12.5 12.1 12 12.6 12 13.25'), L('dot', circ(12, 17.25, 0.6))] },
    info: { label: 'Info', keyline: 'Circle', layers: [L('ring', C9), L('dot', circ(12, 7.5, 0.6)), L('stem', 'M12 11.5V16.75')] },
    language: { label: 'Language', keyline: 'Circle', layers: [L('globe', C9), L('meridian', 'M12 3C9.5 5.5 8.5 8.5 8.5 12S9.5 18.5 12 21C14.5 18.5 15.5 15.5 15.5 12S14.5 5.5 12 3Z'), L('equator', 'M3 12H21')] },
    rate: { label: 'Rate', keyline: 'Circle', layers: [L('star', star(12, 12.6, 9, 4.25))] },
    light_mode: { label: 'Light', keyline: 'Circle', layers: [L('sun', circ(12, 12, 3.5)), L('rays', rays(12, 12, 6.75, 9, 8))] },
    dark_mode: { label: 'Dark', keyline: 'Circle', layers: [L('moon', MOON)] },
    auto_mode: { label: 'Match system', keyline: 'Circle', layers: [L('ring', circ(12, 12, 8.5)), L('half', 'M12 3.5A8.5 8.5 0 0 0 12 20.5Z', PAINT)] },
    visible: { label: 'Show', keyline: 'Landscape', layers: [L('eye', EYE), L('pupil', circ(12, 12, 2.75))] },
    hidden: { label: 'Hide', keyline: 'Landscape', layers: [L('eye', EYE), L('pupil', circ(12, 12, 2.75)), L('slash', SLASH, CUT)] },
    battery: { label: 'Battery', keyline: 'Landscape', layers: [L('body', rect(3, 7.5, 14.5, 9, 2.5)), L('cap', 'M21 10.5V13.5'), L('level', 'M6.5 12H10.5')] },
    guest: { label: 'Create an account to unlock', layers: [L('head', circ(9, 7.5, 3.5)), L('shoulders', 'M3.25 20.5C3.25 16.9 5.9 14.5 9 14.5S14.75 16.9 14.75 20.5'), L('plus', 'M18.5 6.5V11.5M16 9H21')] },
    /* Study and files */
    grade: { label: 'Grade', keyline: 'Portrait', layers: [L('medal', circ(12, 9, 5.5)), L('ribbon', 'M9 13.75L7.5 20.5L12 18.5L16.5 20.5L15 13.75')] },
    goal: { label: 'Goal', keyline: 'Circle', layers: [L('outer', C9), L('inner', circ(12, 12, 5)), L('centre', circ(12, 12, 0.6))] },
    trend: { label: 'Trend', layers: [L('line', 'M3.5 17L9 11.5L13 15L20.5 7.5'), L('head', 'M15.5 7.5H20.5V12.5')] },
    ice_breakers: { label: 'Ice Breakers', layers: [L('cube', CUBE), L('crack', CRACK), L('play', 'M10 8.75V15.25L15.25 12Z')] },
    file: { label: 'File', keyline: 'Portrait', layers: [L('page', 'M13.5 3H8.5A3 3 0 0 0 5.5 6V18A3 3 0 0 0 8.5 21H15.5A3 3 0 0 0 18.5 18V8Z'), L('fold', 'M13.5 3V7A1 1 0 0 0 14.5 8H18.5')] },
    attach: { label: 'Attach', keyline: 'Portrait', layers: [L('clip', 'M18 8.5V14.5A6.25 6.25 0 0 1 5.5 14.5V7.5A4.25 4.25 0 0 1 14 7.5V14.5A2.25 2.25 0 0 1 9.5 14.5V8.5')] },
    folder: { label: 'Folder', keyline: 'Landscape', layers: [L('folder', 'M3 7.5A2.5 2.5 0 0 1 5.5 5H9.25L11.25 7.5H18.5A2.5 2.5 0 0 1 21 10V17.5A2.5 2.5 0 0 1 18.5 20H5.5A2.5 2.5 0 0 1 3 17.5Z')] },
    scan: { label: 'Scan', layers: [L('corners', 'M3.5 8V6.5A3 3 0 0 1 6.5 3.5H8M16 3.5H17.5A3 3 0 0 1 20.5 6.5V8M20.5 16V17.5A3 3 0 0 1 17.5 20.5H16M8 20.5H6.5A3 3 0 0 1 3.5 17.5V16'), L('line', 'M7.5 12H16.5')] },
    note: { label: 'Note', keyline: 'Portrait', layers: [L('page', rect(5, 3, 14, 18, 3)), L('lines', 'M8.5 8.5H15.5M8.5 12H15.5M8.5 15.5H12.5')] },
    suggestion: { label: 'Suggestion', keyline: 'Portrait', layers: [L('bulb', 'M9.25 17V15.6C9.25 14.6 8.4 13.75 7.6 12.75A5.75 5.75 0 1 1 16.4 12.75C15.6 13.75 14.75 14.6 14.75 15.6V17Z'), L('base', 'M10.25 20.5H13.75')] },
    bug: { label: 'Report a bug', layers: [L('body', 'M7 11.5H17V15.5A5 5 0 0 1 7 15.5Z'), L('head', 'M8.5 11.5V10.5A3.5 3.5 0 0 1 15.5 10.5V11.5'), L('seam', 'M12 11.5V20.5'), L('legs', 'M3.5 13.5H7M17 13.5H20.5M4.5 9.75L7 11.5M19.5 9.75L17 11.5M4.5 19.25L7.5 17.5M19.5 19.25L16.5 17.5')] },
    /* Approved extras */
    duplicate: { label: 'Duplicate', layers: [L('back', 'M8 3.25H17.75A3 3 0 0 1 20.75 6.25V16'), L('front', rect(3, 8, 12.5, 12.5, 3)), L('plus', 'M9.25 11.75V16.75M6.75 14.25H11.75')] },
    undo: { label: 'Undo', layers: [L('arrow', 'M9 14.5L4.5 10L9 5.5M4.5 10H14.5A5 5 0 0 1 14.5 20H11')] },
    filter: { label: 'Filter', layers: [L('funnel', 'M4 5H20L14 12.5V18.5L10 20.5V12.5Z')] },
    link: { label: 'Link', keyline: 'Landscape', layers: [L('left', 'M10 8H7.5A4 4 0 0 0 7.5 16H10'), L('right', 'M14 8H16.5A4 4 0 0 1 16.5 16H14'), L('bar', 'M8.5 12H15.5')] },
    upload: { label: 'Upload', layers: [L('tray', TRAY), L('arrow', 'M12 15.5V4M7.5 8.5L12 4L16.5 8.5')] },
    download: { label: 'Download', layers: [L('tray', TRAY), L('arrow', 'M12 4V15.5M7.5 11L12 15.5L16.5 11')] },
    camera: { label: 'Camera', keyline: 'Landscape', layers: [L('body', rect(3, 6.5, 18, 14, 3)), L('bump', 'M8.5 6.5L9.75 4.25H14.25L15.5 6.5'), L('lens', circ(12, 13.75, 3.5))] },
    offline: { label: 'Offline', keyline: 'Landscape', layers: [L('cloud', 'M7.5 18.5A3.75 3.75 0 0 1 7.5 11A4.75 4.75 0 0 1 16.75 10A4.25 4.25 0 0 1 16.75 18.5Z'), L('slash', SLASH, CUT)] },
    skip: { label: 'Skip', layers: [L('triangle', 'M6 6V18L14.5 12Z'), L('bar', 'M18 6V18')] },
    volume: { label: 'Volume', layers: [L('speaker', SPEAKER), L('waves', 'M15.5 9A4.25 4.25 0 0 1 15.5 15M18.25 6.25A8 8 0 0 1 18.25 17.75')] },
    headphones: { label: 'Headphones', layers: [L('band', 'M4.5 14.5V12A7.5 7.5 0 0 1 19.5 12V14.5'), L('cups', rect(3.5, 14.5, 4.5, 6, 1.7) + rect(16, 14.5, 4.5, 6, 1.7))] },
    invite: { label: 'Invite friends', layers: [L('front', circ(9, 8, 3.25) + 'M3 20.5C3 16.9 5.7 14.75 9 14.75S15 16.9 15 20.5'), L('back', 'M15.5 4.75A3.25 3.25 0 0 1 15.5 11.25M17.5 14.9C19.6 15.6 21 17.4 21 20.5')] },
    gift: { label: 'Gift', layers: [L('lid', rect(3.5, 8, 17, 4.5, 1.7)), L('box', 'M5 12.5V18A2.5 2.5 0 0 0 7.5 20.5H16.5A2.5 2.5 0 0 0 19 18V12.5'), L('ribbon', 'M12 8V20.5'), L('bow', 'M12 8C10.5 8 8 7 8 5.25A1.75 1.75 0 0 1 9.75 3.5C11 3.5 12 5.5 12 8C12 5.5 13 3.5 14.25 3.5A1.75 1.75 0 0 1 16 5.25C16 7 13.5 8 12 8')] },
    mail: { label: 'Email', keyline: 'Landscape', layers: [L('envelope', rect(3, 5.5, 18, 13, 3)), L('flap', 'M3.75 8L12 13L20.25 8')] },
    streak: { label: 'Streak', keyline: 'Landscape', layers: [L('days', circ(5.25, 12, 2.25) + circ(12, 12, 2.25) + circ(18.75, 12, 2.25)), L('links', 'M7.5 12H9.75M14.25 12H16.5')] },
    /* Hero */
    cube_frozen: { tier: 'hero', label: 'Not started', layers: [L('cube', CUBE), L('glint', GLINT)] },
    cube_cracked: { tier: 'hero', label: 'Started', layers: [L('cube', CUBE), L('glint', GLINT), L('crack', CRACK)] },
    cube_session: { tier: 'hero', label: 'In session, time left', layers: [L('cube', CUBE, { timer: true }), L('glint', GLINT)] },
    cube_done: { tier: 'hero', label: 'Done', keyline: 'Portrait', layers: [L('drop', DROP), L('highlight', 'M9 14.5A3 3 0 0 0 12 17.5')] },
    /* Brand: Ada, single-colour mark for OS-tinted surfaces only (fill silhouette) */
    brand_ada_mono: { tier: 'brand', label: 'Ada', keyline: 'Portrait', fill: true, fillOnly: true, layers: [
      L('body', 'M7.75 3.08H16.25Q20.08 3.08 20.08 6.9V17.1Q20.08 20.93 16.25 20.93H7.75Q3.93 20.93 3.93 17.1V6.9Q3.93 3.08 7.75 3.08Z', B),
      L('gloss', 'M8.4 5.6Q6.6 5.75 6.65 8.6', { role: 'knock', sw: 1.5 }),
      L('eyes', 'M7.9 12.1Q9.15 10.2 10.4 12.1M13.6 12.1Q14.85 10.2 16.1 12.1', { role: 'knock', sw: 1.5 }),
      L('mouth', 'M9.24 14.5Q12 18.55 14.76 14.5Q12 15.55 9.24 14.5Z', { role: 'knock', kfill: true })] },
    /* Tier 3: state marks (static key frames; layers ordered for Rive) */
    state_focus: { tier: 3, label: 'Focus', keyline: 'Circle', layers: [L('outer', 'M18.36 5.64A9 9 0 1 1 9.67 3.31'), L('inner', 'M7.93 16.07A5.75 5.75 0 1 1 13.49 17.55'), L('core', circ(12, 12, 0.6))] },
    state_deep_focus: { tier: 3, label: 'Deep Focus', keyline: 'Circle', layers: [L('ring', C9), L('core', circ(12, 12, 4), PAINT)] },
    state_relax: { tier: 3, label: 'Relax', keyline: 'Landscape', layers: [L('wave1', 'M3 9C6 7 9 7 12 9S18 11 21 9'), L('wave2', 'M3 15C6 13 9 13 12 15S18 17 21 15')] },
    state_creative: { tier: 3, label: 'Creative', keyline: 'Circle', layers: [L('orbit', ORBIT[0]), L('dots', ORBIT[1])] },
    state_distracted: { tier: 3, label: 'Distracted', keyline: 'Circle', layers: [L('dots', circ(7, 16, 2) + circ(13, 13.5, 1.25) + circ(11, 8.5, 0.6) + circ(17, 9, 1.25) + circ(19.5, 4.25, 0.6))] },
    /* Canvas only */
    _freeze_r2: { layers: [L('tile', TILE), L('crystal', crystal(12, 12, 4.75))] },
    _chats_r2: { fill: true, layers: [L('bubble', BUBBLE, B), L('wave', WAVE, K)] },
    _ada_r1: { fill: true, layers: [L('bubble', BUBBLE, B), L('wave', WAVE, K)] },
    _corner3: { layers: [L('s', rect(3, 3, 18, 18, 3))] },
    _corner4: { layers: [L('s', rect(3, 3, 18, 18, 4))] }
  };

  var GROUPS = [
    ['Tabs', ['subjects', 'subjects:fill', 'planner', 'planner:fill', 'focus', 'focus:fill', 'insights', 'insights:fill']],
    ['Navigation', ['back', 'forward', 'close', 'chevron_right', 'chevron_down', 'chevron_up', 'more', 'more_vertical', 'search']],
    ['Actions', ['add', 'remove', 'edit', 'delete', 'share', 'check', 'check_circle', 'check_circle:fill', 'sort', 'drag', 'adjust', 'list_view', 'sync', 'send']],
    ['Time', ['time', 'date', 'repeat', 'duration', 'reminder', 'history', 'carry_forward', 'carry_forward:fill']],
    ['Session and sound', ['play', 'pause', 'end', 'prism', 'mute', 'haptics', 'mic', 'notifications', 'notifications_off']],
    ['App freeze', ['freeze', 'thaw', 'shield', 'never_open', 'always_open', 'groups', 'wind_down']],
    ['Day and Ada', ['morning', 'evening', 'chats', 'chats:fill']],
    ['Account and system', ['profile', 'settings', 'sign_out', 'help', 'info', 'language', 'rate', 'light_mode', 'dark_mode', 'auto_mode', 'visible', 'hidden', 'battery', 'guest']],
    ['Study and files', ['grade', 'goal', 'trend', 'ice_breakers', 'file', 'attach', 'folder', 'scan', 'note', 'suggestion', 'bug']],
    ['Approved extras', ['duplicate', 'undo', 'filter', 'link', 'upload', 'download', 'camera', 'offline', 'skip', 'volume', 'headphones', 'invite', 'gift', 'mail', 'streak']]
  ];

  var gl = '';
  for (var i = 1; i < 24; i++) gl += 'M' + i + ' 0V24M0 ' + i + 'H24';
  var GRID = '<g stroke="rgba(107,92,240,.16)" stroke-width=".04" stroke-linecap="butt"><path d="' + gl + '"/></g>' +
    '<path d="M0 0H24V24H0ZM2 2V22H22V2Z" fill="rgba(107,92,240,.08)" stroke="none" fill-rule="evenodd"/>' +
    '<g stroke="rgba(107,92,240,.5)" stroke-width=".06"><circle cx="12" cy="12" r="10"/><rect x="3" y="3" width="18" height="18"/><rect x="4" y="2" width="16" height="20"/><rect x="2" y="4" width="20" height="16"/></g>';

  function svg(name, o) {
    o = o || {};
    var sw = o.stroke || 1.75;
    var head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"' + (o.file ? ' width="24" height="24"' : ' width="100%" height="100%" style="display:block;overflow:visible"') +
      ' fill="none" stroke="currentColor" stroke-width="' + sw + '" stroke-linecap="round" stroke-linejoin="round">';
    if (name === '_grid') return head + GRID + '</svg>';
    var ic = ICONS[name];
    if (!ic) return head + '</svg>';
    var inner = o.grid ? GRID : '';
    var fill = o.variant === 'fill' && ic.fill;
    var base = 'aq_' + name + (fill ? '_fill' : '');
    var pre = o.file ? base + '-' : null;
    var mid = (o.file ? base : (o.uid || base)) + '-mask';
    var idA = function (l) { return pre && l.id ? ' id="' + pre + l.id + '"' : ''; };
    var dash = function (l) { return (l.timer && o.progress != null && o.progress < 1) ? ' pathLength="1" stroke-dasharray="' + o.progress + ' 1"' : ''; };
    var paint = function (l) { return l.paint ? ' fill="currentColor"' : ''; };
    var maskOpen = '<mask id="' + mid + '" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white" stroke="none"/>';
    if (!fill) {
      var cuts = ic.layers.filter(function (l) { return l.role === 'cut'; });
      var draw = function (l) { return '<path' + idA(l) + ' d="' + l.d + '"' + dash(l) + paint(l) + '/>'; };
      if (cuts.length) {
        inner += maskOpen + cuts.map(function (l) { return '<path d="' + l.d + '" stroke="black" stroke-width="' + r2(sw + 3) + '"/>'; }).join('') + '</mask>' +
          '<g mask="url(#' + mid + ')">' + ic.layers.filter(function (l) { return l.role !== 'cut'; }).map(draw).join('') + '</g>' + cuts.map(draw).join('');
      } else inner += ic.layers.map(draw).join('');
    } else {
      var layers = ic.fillLayers || ic.layers;
      var knocks = layers.filter(function (l) { return l.role === 'knock'; });
      var rest = layers.filter(function (l) { return l.role !== 'knock'; });
      var body = function (l) { return '<path' + idA(l) + ' d="' + l.d + '"' + (l.role === 'body' || l.paint ? ' fill="currentColor"' : '') + '/>'; };
      if (knocks.length) {
        inner += maskOpen + knocks.map(function (l) { return '<path' + idA(l) + ' d="' + (l.fd || l.d) + '"' + (l.kfill ? ' fill="black" stroke="none"' : ' stroke="black"' + (l.sw ? ' stroke-width="' + l.sw + '"' : '')) + '/>'; }).join('') + '</mask>' +
          '<g mask="url(#' + mid + ')">' + rest.map(body).join('') + '</g>';
      } else inner += rest.map(body).join('');
    }
    return head + inner + '</svg>';
  }

  /* Brand: Ada full colour, from the DS AdaCube at melt 0, rating 4, happy. Fixed brand colours by design. */
  function adaColor(o) {
    o = o || {};
    var size = o.file ? ' width="' + (o.px || 48) + '" height="' + (o.px || 48) + '"' : ' width="100%" height="100%" style="display:block"';
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="6 4 48 48"' + size + '>' +
      '<path id="body" d="M20 8H40Q49 8 49 17V41Q49 50 40 50Q30 50 20 50Q11 50 11 41V17Q11 8 20 8Z" fill="#cbbcfd" stroke="#5a44f1" stroke-width="3.4" stroke-linejoin="round"/>' +
      '<path id="inner" d="M20.95 13H39.05Q44 13 44 17.95V39.6Q44 45 38.6 45Q30 45 21.4 45Q16 45 16 39.6V17.95Q16 13 20.95 13Z" fill="#ffffff" fill-opacity="0.32"/>' +
      '<path id="gloss" d="M21 10.5Q14 11 14.2 22" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-opacity="0.5"/>' +
      '<g id="bubbles" fill="#ffffff"><circle cx="21" cy="17" r="2.7" fill-opacity="0.85"/><circle cx="26.5" cy="14" r="1.5" fill-opacity="0.7"/><circle cx="19.5" cy="23.5" r="1.9" fill-opacity="0.55"/></g>' +
      '<path id="eyes" d="M21 29.2Q24 25 27 29.2M33 29.2Q36 25 39 29.2" fill="none" stroke="#31237c" stroke-width="2.1" stroke-linecap="round"/>' +
      '<path id="mouth" d="M23.5 34Q30 43.5 36.5 34Q30 36.5 23.5 34Z" fill="#31237c"/>' +
      '<path id="tongue" d="M26.7 38.4Q30 41.4 33.3 38.4Q30 40 26.7 38.4Z" fill="#e8607f"/></svg>';
  }

  /* Ada poses: direct port of DS AdaCube (melt 0 crisp to 1 puddle, rating 0 Rough to 4 Great). Shared 56 box so melting reads as shrinking. */
  var TONES = [['#a79fc4', '#eae8f2', '#938eac'], ['#9286d2', '#e4ddf3', '#787299'], ['#7d70d9', '#dcd3f7', '#5c5499'], ['#6a5ce4', '#d2c5fa', '#41358f'], ['#5a44f1', '#cbbcfd', '#31237c']];
  var MOUTHS = {
    smile: function (cx, my) { return 'M' + (cx - 6) + ' ' + my + 'Q' + cx + ' ' + (my + 4.5) + ' ' + (cx + 6) + ' ' + my; },
    neutral: function (cx, my) { return 'M' + (cx - 6) + ' ' + my + 'L' + (cx + 6) + ' ' + my; },
    focused: function (cx, my) { return 'M' + (cx - 5) + ' ' + my + 'Q' + cx + ' ' + (my + 3) + ' ' + (cx + 5) + ' ' + my; },
    meh: function (cx, my) { return 'M' + (cx - 6) + ' ' + (my + 2) + 'Q' + cx + ' ' + (my - 2) + ' ' + (cx + 6) + ' ' + (my + 2); },
    sad: function (cx, my) { return 'M' + (cx - 7) + ' ' + (my + 3) + 'Q' + cx + ' ' + (my - 3.5) + ' ' + (cx + 7) + ' ' + (my + 3); }
  };
  function cubeBody(tL, tY, tR, bL, bR, bY, rT, rB, sag) {
    var f = function (n) { return r2(n); };
    return 'M' + f(tL + rT) + ' ' + f(tY) + 'L' + f(tR - rT) + ' ' + f(tY) + 'Q' + f(tR) + ' ' + f(tY) + ' ' + f(tR) + ' ' + f(tY + rT) +
      'L' + f(bR) + ' ' + f(bY - rB) + 'Q' + f(bR) + ' ' + f(bY) + ' ' + f(bR - rB) + ' ' + f(bY) + 'Q30 ' + f(bY + sag) + ' ' + f(bL + rB) + ' ' + f(bY) +
      'Q' + f(bL) + ' ' + f(bY) + ' ' + f(bL) + ' ' + f(bY - rB) + 'L' + f(tL) + ' ' + f(tY + rT) + 'Q' + f(tL) + ' ' + f(tY) + ' ' + f(tL + rT) + ' ' + f(tY) + 'Z';
  }
  function adaPose(o) {
    o = o || {};
    var m = Math.max(0, Math.min(1, o.melt || 0)), t = TONES[o.rating == null ? 4 : o.rating], ex = o.expr || 'happy', f = r2;
    var tY = 8 + 15 * m, bY = 50 + 2 * m, tL = 11 + 7 * m, tR = 49 - 7 * m, bL = 11 - 6 * m, bR = 49 + 6 * m, rT = 9 + 3 * m, rB = 9 + 13 * m, sag = 2.5 * m;
    var fc = (tY + bY) / 2 + 1, eY = fc - 2, eR = 2.7 - 0.5 * m, eD = 6 - 1.2 * m, mY = fc + 5, gl = 0.5 * (1 - 0.55 * m);
    var size = o.file ? ' width="' + (o.px || 56) + '" height="' + (o.px || 56) + '"' : ' width="100%" height="100%" style="display:block"';
    var s = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="2 2 56 56"' + size + '>' +
      '<path id="body" d="' + cubeBody(tL, tY, tR, bL, bR, bY, rT, rB, sag) + '" fill="' + t[1] + '" stroke="' + t[0] + '" stroke-width="' + f(3.4 - 1.2 * m) + '" stroke-linejoin="round"/>' +
      '<path id="inner" d="' + cubeBody(tL + 5, tY + 5, tR - 5, bL + 5, bR - 5, bY - 5, rT * 0.55, rB * 0.6, sag * 0.6) + '" fill="#ffffff" fill-opacity="' + f(0.32 * (1 - 0.5 * m)) + '"/>' +
      '<path id="gloss" d="M' + f(tL + rT + 1) + ' ' + f(tY + 2.5) + 'Q' + f(tL + 3) + ' ' + f(tY + 3) + ' ' + f(tL + 3.2) + ' ' + f(tY + rT + 5) + '" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-opacity="' + f(gl) + '"/>' +
      '<g id="bubbles" fill="#ffffff">' + [[21, tY + 9, 2.7], [26.5, tY + 6, 1.5], [19.5, tY + 15.5, 1.9]].map(function (b, i) { return '<circle cx="' + b[0] + '" cy="' + f(b[1]) + '" r="' + b[2] + '" fill-opacity="' + f((0.85 - i * 0.15) * (1 - 0.5 * m)) + '"/>'; }).join('') + '</g>';
    if (ex === 'happy') s += '<path id="eyes" d="M' + f(30 - eD - 3) + ' ' + f(eY + 1.2) + 'Q' + f(30 - eD) + ' ' + f(eY - 3) + ' ' + f(30 - eD + 3) + ' ' + f(eY + 1.2) + 'M' + f(30 + eD - 3) + ' ' + f(eY + 1.2) + 'Q' + f(30 + eD) + ' ' + f(eY - 3) + ' ' + f(30 + eD + 3) + ' ' + f(eY + 1.2) + '" fill="none" stroke="' + t[2] + '" stroke-width="2.1" stroke-linecap="round"/>';
    else if (ex === 'sad') s += '<path id="eyes" d="M' + f(30 - eD - 2.5) + ' ' + f(eY - 1.5) + 'L' + f(30 - eD + 2.5) + ' ' + f(eY + 1.5) + 'M' + f(30 + eD + 2.5) + ' ' + f(eY - 1.5) + 'L' + f(30 + eD - 2.5) + ' ' + f(eY + 1.5) + '" fill="none" stroke="' + t[2] + '" stroke-width="2" stroke-linecap="round"/>';
    else s += '<g id="eyes" fill="' + t[2] + '"><circle cx="' + f(30 - eD) + '" cy="' + f(eY) + '" r="' + f(eR) + '"/><circle cx="' + f(30 + eD) + '" cy="' + f(eY) + '" r="' + f(eR) + '"/></g>';
    if (ex === 'happy') s += '<path id="mouth" d="M' + f(23.5) + ' ' + f(mY - 1) + 'Q30 ' + f(mY + 8.5) + ' ' + f(36.5) + ' ' + f(mY - 1) + 'Q30 ' + f(mY + 1.5) + ' ' + f(23.5) + ' ' + f(mY - 1) + 'Z" fill="' + t[2] + '"/>' +
      '<path id="tongue" d="M' + f(26.7) + ' ' + f(mY + 3.4) + 'Q30 ' + f(mY + 6.4) + ' ' + f(33.3) + ' ' + f(mY + 3.4) + 'Q30 ' + f(mY + 5) + ' ' + f(26.7) + ' ' + f(mY + 3.4) + 'Z" fill="#e8607f"/>';
    else s += '<path id="mouth" d="' + MOUTHS[ex](30, f(mY)) + '" fill="none" stroke="' + t[2] + '" stroke-width="' + f(2.4 - 0.4 * m) + '" stroke-linecap="round"/>';
    return s + '</svg>';
  }
  var POSES = [
    ['mood_rough', 'Ada, rough', { rating: 0, melt: 0.8, expr: 'sad' }], ['mood_tired', 'Ada, tired', { rating: 1, melt: 0.6, expr: 'meh' }],
    ['mood_ok', 'Ada, OK', { rating: 2, melt: 0.4, expr: 'neutral' }], ['mood_good', 'Ada, good', { rating: 3, melt: 0.2, expr: 'smile' }],
    ['mood_great', 'Ada, great', { rating: 4, melt: 0, expr: 'happy' }],
    ['session_0', 'Session starting', { rating: 4, melt: 0, expr: 'focused' }], ['session_33', 'Session, a third in', { rating: 4, melt: 0.33, expr: 'focused' }],
    ['session_66', 'Session, two thirds in', { rating: 4, melt: 0.66, expr: 'focused' }], ['session_done', 'Session done', { rating: 4, melt: 1, expr: 'happy' }]
  ];

  window.AQ = { ICONS: ICONS, GROUPS: GROUPS, svg: svg, rect: rect, adaColor: adaColor, adaPose: adaPose, POSES: POSES };
})();
