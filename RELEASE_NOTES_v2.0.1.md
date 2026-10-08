## Softify v2.0.1 — Spotify Playlist Import Fix & Reliable In-App Updates

A focused maintenance release that fixes the two most reported issues: Spotify playlists silently truncating at 100 tracks, and in-app updates failing to install.

---

### 🎵 Fixed: Spotify playlists now import in full

Playlist imports were capped at **100 tracks** because the importer parsed Spotify's public embed page, which the server truncates after 100 items.

- **Full pagination**: the importer now obtains an anonymous access token from Spotify's embed token endpoint and pages through `GET /v1/playlists/{id}/tracks` in batches of 100 until every track is fetched — playlists of 500, 1,000 or more tracks now import completely.
- **Resilient fetches**: automatic retry with exponential backoff on rate limits (`429`) and server errors, plus one silent token refresh on expiry (`401`).
- **Graceful fallback**: if the official API is unavailable or rate-limited for a Spotify-owned editorial playlist (e.g. `37i9d…`), the importer falls back to the previous embed method instead of failing.
- **Robust parsing**: unavailable/null track entries are skipped rather than aborting the whole import.
- Covered by five new unit tests (pagination merge, fallback, rate-limit retry, token refresh, null-track skip).

---

### 📦 Fixed: in-app updates no longer fail with a signature conflict

Updates downloaded from GitHub Releases could fail with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (reported as a "same package conflict"), because release builds were signed with an ephemeral CI debug key that changed on every run.

- **Stable release signing**: releases are now signed with a dedicated, persistent release keystore injected through CI secrets, with a new *Release Build (Android)* workflow that verifies the tag matches `pubspec.yaml`, gates on analyze + tests, audits the APK certificate, and publishes the SHA-256 checksum with the release asset.
- **Complete install pipeline** (Android `PackageInstaller`): a proper install session with a progress broadcast receiver, plus a preflight check that reports *why* an install will fail before it starts (signature mismatch, version downgrade, missing permission, insufficient storage).
- **Guided reinstall**: when a signature mismatch is detected — i.e. the user's installed build came from the old debug key — the app now explains the situation, stages the downloaded APK into shared Downloads (so it survives uninstall), and walks the user through uninstall → reinstall instead of failing silently.
- **Typed errors**: install failures surface as structured error codes (`CONFLICT`, `USER_ABORTED`, `INVALID`, `VERSION_DOWNGRADE`, …) rather than opaque strings.

---

### 🔧 Other fixes

- The in-app update checker now reports the real app version, so the app no longer re-offers its own release after updating.

---

**Android**: [`Softify-v2.0.1-Android-Universal.apk`](https://github.com/Sarthak-Cyb3r/softify/releases/latest) — all ABIs, Android 8.0+.

> **Note for existing installs:** if you installed a build signed with the old development key, this release will guide you through a one-time uninstall/reinstall. Your library is stored on-device and the app will re-sync on first launch.
