## Softify v2.0.2 — Spotify Import Hotfix

A targeted fix for the importer getting stuck on **"Connecting to Spotify & extracting tracks…"** indefinitely.

---

### 🐛 Fixed: import no longer hangs

Spotify's Web API rate-limiter responds with `Retry-After: 71777` (~20 hours) when the shared anonymous quota is exhausted, and the importer dutifully slept for that entire duration — leaving the spinner on screen indefinitely.

- **No unbounded sleeps**: retry backoff is capped at 5 seconds; a rate-limit response asking for a longer wait returns immediately and falls back to the embed page's tracks.
- **Hard deadline**: the whole Web API pass is bounded to 60 seconds, so the UI always resolves to either results or an error.
- **Live progress**: the status line now reports `Loaded N tracks…` as each page arrives instead of a static message.
- **Clear notice**: when the API is unavailable you get an amber banner explaining that only the first 100 tracks were imported and that the full playlist can be retried later.

---

**Android**: [`Softify-v2.0.2-Android-Universal.apk`](https://github.com/Sarthak-Cyb3r/softify/releases/latest) — all ABIs, Android 8.0+.

> **Note:** full playlists (100+ tracks) import again once Spotify's anonymous quota for your network resets; until then the importer falls back to the embed page's first 100 tracks.
