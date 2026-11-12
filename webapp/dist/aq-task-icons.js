/* Aqademiq Tier 2 task icons: two layers (l1 primary 100%, l2 secondary 45% of the task color). Needs aq-icons.js first. */
(function init() {
  if (!window.AQ) { setTimeout(init, 30); return; }
  var rect = window.AQ.rect;
  function circ(cx, cy, r) { return 'M' + cx + ' ' + (cy - r) + 'A' + r + ' ' + r + ' 0 1 1 ' + cx + ' ' + (cy + r) + 'A' + r + ' ' + r + ' 0 1 1 ' + cx + ' ' + (cy - r) + 'Z'; }

  /* Study-tag hues + proposed ink steps (glyph on light tile, at least 3:1). */
  var PALETTE = {
    lecture: { hue: '#5cbbff', ink: '#1f6fae', token: '--aq-tag-lecture' },
    class: { hue: '#6b5cf0', ink: '#4f3fd6', token: '--aq-tag-class' },
    exam: { hue: '#e85476', ink: '#c23358', token: '--aq-tag-exam' },
    assignment: { hue: '#2a9d6b', ink: '#1d7a52', token: '--aq-tag-assignment' },
    report: { hue: '#e8a430', ink: '#a8680a', token: '--aq-tag-report' },
    presentation: { hue: '#c0497b', ink: '#a3346a', token: '--aq-tag-presentation' },
    reading: { hue: '#7a8699', ink: '#556073', token: '--aq-tag-reading' }
  };

  var TASKS = [
    { name: 'lecture', label: 'Lecture', color: 'lecture', l1: 'M12 4.5L21 9L12 13.5L3 9Z', l2: 'M7 11.25V15.5C7 17.1 9.25 18.75 12 18.75S17 17.1 17 15.5V11.25M19.5 10V14.5' },
    { name: 'class', label: 'Class', color: 'class', l1: rect(3, 4, 18, 12.5, 3) + 'M8 16.5L6.75 20.5M16 16.5L17.25 20.5', l2: 'M7 8.5H13M7 12H16' },
    { name: 'exam', label: 'Exam', color: 'exam', l1: rect(5, 3, 14, 18, 3) + 'M9 15.5L11.25 17.75L15.25 13.75', l2: 'M8.5 7H15.5M8.5 10.25H13' },
    { name: 'assignment', label: 'Assignment', color: 'assignment', l1: 'M8.5 5H7.5A3 3 0 0 0 4.5 8V18A3 3 0 0 0 7.5 21H16.5A3 3 0 0 0 19.5 18V8A3 3 0 0 0 16.5 5H15.5' + rect(8.5, 3, 7, 4, 1.5), l2: 'M8.5 11H15.5M8.5 14.5H13' },
    { name: 'report', label: 'Report', color: 'report', l1: rect(5, 3, 14, 18, 3), l2: 'M8.75 17V14M12 17V9.5M15.25 17V12' },
    { name: 'presentation', label: 'Presentation', color: 'presentation', l1: 'M3.5 4.5H20.5' + rect(5, 4.5, 14, 11, 2.5) + 'M12 15.5V20.5M9 20.5H15', l2: 'M8.5 12L10.75 9.75L12.75 11.25L15.5 8.5' },
    { name: 'reading', label: 'Reading', color: 'reading', l1: 'M12 6.5C10 5 7.5 4.5 3.5 4.5V18C7.5 18 10 18.5 12 20C14 18.5 16.5 18 20.5 18V4.5C16.5 4.5 14 5 12 6.5ZM12 6.5V20', l2: 'M14.5 9.5C15.5 9 16.6 8.75 17.75 8.6M14.5 13C15.5 12.5 16.6 12.25 17.75 12.1' },
    { name: 'math', label: 'Maths', color: 'class', l1: 'M7.5 4.5V10.5M4.5 7.5H10.5M13.5 7.5H19.5', l2: 'M5 14.25L10 19.25M10 14.25L5 19.25M13.5 15H19.5M13.5 18.5H19.5' },
    { name: 'science', label: 'Science', color: 'assignment', l1: 'M9.5 3.5H14.5M10.5 3.5V9L5.25 18.25A1.75 1.75 0 0 0 6.75 20.75H17.25A1.75 1.75 0 0 0 18.75 18.25L13.5 9V3.5', l2: 'M7.75 15.5H16.25' + circ(12.25, 11.5, 0.6) },
    { name: 'code', label: 'Code', color: 'lecture', l1: 'M7.5 7.5L3.5 12L7.5 16.5M16.5 7.5L20.5 12L16.5 16.5', l2: 'M13 6.5L11 17.5' },
    { name: 'writing', label: 'Writing', color: 'report', l1: 'M8.5 3.5H15.5L18 10.5L12 20.5L6 10.5ZM12 16V19.25', l2: 'M8.25 6.75H15.75' + circ(12, 11.25, 1.25) },
    { name: 'languages', label: 'Languages', color: 'presentation', l1: rect(3, 3.5, 12.5, 10, 3, 'H8.5L6 16V13.5'), l2: 'M18.75 8A2.25 2.25 0 0 1 21 10.25V16A3 3 0 0 1 18 19H17.5V21L15 19H12.5A3 3 0 0 1 9.5 16.75' },
    { name: 'history', label: 'History', color: 'reading', l1: 'M4 7.5L12 3.5L20 7.5ZM4 20.75H20M5.5 17.25H18.5', l2: 'M7.5 7.5V17.25M12 7.5V17.25M16.5 7.5V17.25' },
    { name: 'art', label: 'Art', color: 'exam', l1: 'M12 3.5A8.5 8.5 0 1 0 12 20.5C13.25 20.5 13.75 19.5 13.25 18.5C12.6 17.2 13.4 15.75 15 15.75H17A3.5 3.5 0 0 0 20.5 12.25C20.5 7.4 16.7 3.5 12 3.5Z', l2: circ(7.72, 11.24, 0.9) + circ(11.39, 7.69, 0.9) + circ(15.91, 10.09, 0.9) },
    { name: 'music', label: 'Music', color: 'class', l1: 'M9.5 17V5.5L19 3.5V15' + circ(7.25, 17, 2.25) + circ(16.75, 15, 2.25), l2: 'M9.5 9L19 7' },
    { name: 'business', label: 'Business', color: 'reading', l1: rect(3, 7, 18, 13, 3) + 'M9 7V5.5A1.5 1.5 0 0 1 10.5 4H13.5A1.5 1.5 0 0 1 15 5.5V7', l2: 'M3.5 12.5H10M14 12.5H20.5' + rect(10, 10.75, 4, 3.5, 1.2) }
  ];
  var BY = {}; TASKS.forEach(function (t) { BY[t.name] = t; });

  /* layer: 'l1' | 'l2' | 'both'. Files ship l1 and l2 separately with currentColor; the runtime sets l2 to 45%. */
  function svg(name, layer, o) {
    o = o || {};
    var t = BY[name], sw = o.stroke || 1.75;
    var head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"' + (o.file ? ' width="24" height="24"' : ' width="100%" height="100%" style="display:block;overflow:visible"') +
      ' fill="none" stroke="currentColor" stroke-width="' + sw + '" stroke-linecap="round" stroke-linejoin="round">';
    var id = function (l) { return o.file ? ' id="aq_task_' + name + '_' + l + '"' : ''; };
    var grid = o.grid && window.AQ.svg('_grid').replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '') || '';
    var body = layer === 'l1' ? '<path' + id('l1') + ' d="' + t.l1 + '"/>' :
      layer === 'l2' ? '<path' + id('l2') + ' d="' + t.l2 + '"/>' :
      '<path d="' + t.l2 + '" stroke-opacity="0.45"/><path d="' + t.l1 + '"/>';
    return head + grid + body + '</svg>';
  }

  window.AQT = { TASKS: TASKS, PALETTE: PALETTE, svg: svg };
})();
