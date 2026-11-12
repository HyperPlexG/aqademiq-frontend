// Builds the Aqademiq web app into dist/.
//
// The app is the v11 design kit (prototypes/v11/app.jsx: tokens, icons, Ada's
// cube, the melting timer) with the web app in src/ on top, compiled from JSX
// once here so the browser loads plain JavaScript.
//
//   npm install && npm run build        (uses @babel/standalone from npm)
//   BABEL_STANDALONE=/path/babel.js node build.js   (any local copy instead)
//
// dist/prism/*.mp4 are committed and not touched by the build.
const fs = require('fs'), path = require('path');
const SRC = path.join(__dirname, 'src');
const KIT = path.join(__dirname, '..', 'prototypes', 'v11');
const OUT = path.join(__dirname, 'dist');
fs.mkdirSync(OUT, { recursive: true });

// The kit, minus the line that renders its own prototype.
let kit = fs.readFileSync(path.join(KIT, 'app.jsx'), 'utf8').replace(/\r\n/g, '\n');
const render = "ReactDOM.createRoot(document.getElementById('root')).render(<App />);";
if (!kit.includes(render)) throw new Error('render line not found in prototypes/v11/app.jsx');
kit = kit.replace(render, '');
// The prototype's mock screens carry real-looking email addresses. The web app
// never renders those screens, but the bundle is public: keep addresses out of it.
kit = kit.replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[a-z]{2,}/g, 'you@university.edu');

const FILES = ['core.jsx', 'prism.jsx', 'auth.jsx', 'acct.jsx', 'plan.jsx', 'pages.jsx', 'shell.jsx'];
const app = FILES.map((f) => `/* ${f} */\n` + fs.readFileSync(path.join(SRC, f), 'utf8').replace(/\r\n/g, '\n')).join('\n');
const Babel = require(process.env.BABEL_STANDALONE || '@babel/standalone');
const js = Babel.transform(kit + '\n' + app, { presets: ['react'], sourceType: 'script' }).code;

const png = (f) => 'data:image/png;base64,' + fs.readFileSync(path.join(KIT, f)).toString('base64');
fs.writeFileSync(path.join(OUT, 'app.js'),
  '/* Aqademiq web app. Compiled from JSX: the v11 design kit + the web app. */\n' +
  'window.__resources = ' + JSON.stringify({ logo: png('logo.png') }) + ';\n' +
  'try {\n' + js + '\n} catch (e) { document.getElementById("root").innerHTML = "<div class=\\"boot\\">Something went wrong loading Aqademiq.</div>"; throw e; }\n');
fs.copyFileSync(path.join(KIT, 'aq-icons.js'), path.join(OUT, 'aq-icons.js'));
fs.copyFileSync(path.join(KIT, 'aq-task-icons.js'), path.join(OUT, 'aq-task-icons.js'));

fs.writeFileSync(path.join(OUT, 'index.html'), `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Aqademiq</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,400;0,500;0,600;0,700;0,800;1,400&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons+Outlined">
<style>
${fs.readFileSync(path.join(SRC, 'web.css'), 'utf8').replace(/\r\n/g, '\n')}
</style>
</head>
<body>
<div id="root"><div class="boot">Loading Aqademiq…</div></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react/18.3.1/umd/react.production.min.js" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.3.1/umd/react-dom.production.min.js" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/dist/umd/supabase.js" crossorigin="anonymous"></script>
<script src="aq-icons.js"></script>
<script src="aq-task-icons.js"></script>
<script src="app.js"></script>
</body>
</html>
`);
const kb = (f) => (fs.statSync(path.join(OUT, f)).size / 1024).toFixed(0) + ' KB';
console.log('built', OUT, ['index.html', 'app.js'].map((f) => f + ' ' + kb(f)).join(', '));
