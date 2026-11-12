# Aqademiq on the web

The v11 design as a web app. It uses the **same accounts and data as the phone
app**: signing in here with the account from your phone shows the same tasks,
subjects, moods, focus sessions and Ada chats, through the same API
(`/functions/v1/api/v1`) and the same Supabase Auth project.

Without an account it works as a guest, kept in the browser. Signing in later
offers once to bring that guest plan into the account.

## What's in here

| Path | What it is |
|---|---|
| `src/*.jsx`, `src/web.css` | The web app's source |
| `build.js` | Compiles `src/` on top of the v11 design kit (`../prototypes/v11/app.jsx`, its icons and logo) into `dist/` |
| `dist/` | The built site, committed, ready to host as static files |
| `dist/prism/*.mp4` | Prism's stems as AAC (`.mp4`), converted from `assets/audio/stems/focus_mode/**/*.ogg` because Safari can't play `.ogg`. Not touched by the build |
| `test/e2e.js` | A guest-mode regression run inside the page (see Testing) |

`src/` in load order: `core.jsx` (dates, guest storage, shared UI, paste/ICS parsing),
`prism.jsx` (Prism on Web Audio: pads, textures, pulses, sparks), `auth.jsx`
(Supabase sign-in and the API client), `acct.jsx` (the account store: reads the
API, sends each change as a diff), `plan.jsx`, `pages.jsx`, `shell.jsx` (top bar,
pages, settings).

## Build

```sh
cd webapp
npm install      # @babel/standalone, only for the build
npm run build    # → dist/
```

`BABEL_STANDALONE=/path/to/babel.js node build.js` uses a local copy of Babel
standalone instead of npm. React 18.3.1, supabase-js 2.49.4 and qrcodejs load
from CDNs at runtime; there is no bundler.

## Hosting

Serve `dist/` as static files from any host (Vercel, Netlify, Cloudflare Pages,
Firebase Hosting, S3). No server code and no secrets: the Supabase key in
`auth.jsx` is the public anon key the phone app also ships. Routes are hash
routes (`#plan`, `#ada`, …), so no rewrite rules are needed.

## Before sign-in works on a new address

Each item is set once, outside this repo.

1. **Supabase → Authentication → URL Configuration**: add the site's address
   (for example `https://aqademiq.app/` and any preview address) to
   **Redirect URLs**. Google and Apple sign-in send the browser back there.
2. **Google**: in Google Cloud, a **Web application** OAuth client with
   `https://qwvuoooentacjslzpbqy.supabase.co/auth/v1/callback` as an
   authorised redirect URI. Put its client id and secret in Supabase →
   Authentication → Providers → Google, keeping the iOS and Android client ids
   already listed there for the phone.
3. **Apple**: in the Apple developer account (team `R6YW5K2YSP`), a **Services
   ID** for Sign in with Apple on the web, with the site's domain and the same
   Supabase callback URL as its return URL. Add the Services ID to Supabase →
   Providers → Apple next to the app's bundle id, with a Sign in with Apple key.
4. **Email**: sign-up and password reset ask for the **6-digit code** from the
   email, so the Supabase "Confirm signup" and "Reset password" templates must
   include `{{ .Token }}`.

Until 2 and 3 are done, email sign-in works and the Google and Apple buttons
return an error from Supabase.

Inside a claude.ai artifact the page can't reach Supabase. It says so on the
sign-in screen, and guest mode keeps working.

## What the web app leaves to the phone

Features that need the device (App freeze, home-screen widgets, the lock
screen, the watch, haptics, phone calendar and reminder access) open a "Get the
app" card with Play Store and App Store QR codes. Importing from a calendar
**file** or a pasted list works on the web too.

## Testing

Serve the `webapp/` folder with any static server, open `/dist/index.html` as a
guest (past the welcome screen), then in the browser console:

```js
const s = document.createElement('script'); s.src = '/test/e2e.js'; document.head.append(s);
await new Promise((r) => (s.onload = r));
await window.__e2e(); // → a PASS/FAIL list
```

It drives the planner, the add form, Prism with freeze and resume, Ada's
proposals and the paste importer, and checks there were no page errors. It
changes the guest plan, so use a throwaway browser profile. Signed-in flows
(sign-in, bring-over, edit and move, breakdown, Ada, sign-out) were tested by
hand against the live backend with a test account.
