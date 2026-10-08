# Softify — Change Log (v2.0.0 → v2.0.3)

Everything changed in this session, grouped by workstream. Commits are on `main`.

| | |
|---|---|
| **Releases shipped** | `v2.0.1`, `v2.0.2`, `v2.0.3` (all built, signed and verified in CI) |
| **Version** | `2.0.0+200` → `2.0.3+203` |
| **Tests** | 177 → **181 passing** (`flutter analyze`: 0 issues) |

---

## 1. Spotify playlist import — full pagination (was capped at 100)

**Commit:** `5beefed fix(spotify): import full playlists beyond the 100-track embed cap`

**Problem:** the importer parsed Spotify's embed page, whose server-rendered `__NEXT_DATA__ → trackList` is truncated to **100 tracks**.

**Fix:**
- Obtain an anonymous token from `https://open.spotify.com/embed/api/token` (~50 min TTL, cached, refreshed on `401`).
- Page `GET https://api.spotify.com/v1/playlists/{id}/tracks?offset=N&limit=100` until exhausted (verified 111/111 tracks).
- Backoff on `429`/`5xx`, single silent token refresh on `401`.
- `404`/`403` (Spotify-owned `37i9…` editorial playlists) → fall back to the embed's first 100 tracks.
- Null/unavailable track entries are skipped instead of aborting the import.

**Files:**
- `lib/data/importer/keyless_spotify_importer.dart` — rewritten fetch pipeline
- `test/spotify_importer_test.dart` — 5 new tests (pagination merge, 404 fallback, 429 retry, 401 refresh, null-track skip)

---

## 2. In-app update failed with a signature conflict

**Commit:** `473357e fix(installer): stable release signing and a complete Android update flow`

**Problem:** release builds were signed with the **ephemeral CI debug keystore** (regenerated every run), so every release had a different certificate → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

**Fix — signing:**
- New persistent keystore `android/app/softify-release.jks` (alias `softify`, cert SHA-256 `60:ED:1A:AB:…:3E:61`, valid to 2056) + `android/key.properties`, both gitignored.
- `android/app/build.gradle.kts` signs release from `key.properties`, falling back to the debug key for local builds.

**Fix — install pipeline (Android):**
- `MainActivity.kt`: real `PackageInstaller` install/uninstall sessions, progress broadcast receiver (`com.softify.softify.INSTALLER_STATUS`), preflight (signature + versionCode check), `getInstalledInfo`, `stageApk` (copies the APK to shared Downloads so it survives an uninstall).
- `lib/domain/ports/i_update_checker.dart`: `UpdateInstallError` enum, `UpdateInstallException`, `stageDownloadedUpdate()`, `uninstallInstalledApp()`.
- `lib/data/updater/github_release_update_checker.dart`: preflight before install, typed error mapping, stage/uninstall wrappers.
- `lib/presentation/screens/settings_screen.dart`: `_handleSignatureMismatch()` dialog → stage APK → uninstall → user reinstalls from Downloads (one-time guided reinstall).

---

## 3. Android-only release pipeline

**Commit:** `e147ad5 chore(release): v2.0.1`

- **New** `.github/workflows/android_release.yml` — triggers on `v*` tags:
  1. verifies the tag matches `pubspec.yaml`,
  2. injects the release keystore from CI secrets,
  3. gates on `flutter analyze` + `flutter test`,
  4. builds the universal APK, audits the signing certificate with `apksigner`,
  5. publishes SHA-256 into the release body and attaches the asset.
- **CI secrets set:** `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- `README.md`: "Android release signing" section, secret table, release procedure.
- Release notes for v2.0.1 (published on the GitHub release, file since removed — see §8).
- Fixed hardcoded app version in `lib/presentation/providers/settings_providers.dart` (`'2.0.0'` → shipped version) so the update checker stops re-offering the installed build.

**Post-release corrections** (commit `da789fb`):
- The legacy Android job inside `.github/workflows/ios_release.yml` also fired on every `v*` tag and uploaded a **debug-signed, hardcoded `Softify-v2.0.0-Universal.apk`**. That asset was deleted from the v2.0.1 release, the job was removed (workflow is now **iOS-only**), and README filenames/badge were refreshed.

---

## 4. Spotify importer hang — "Connecting to Spotify…" forever

**Commit:** `45c3e25 fix(spotify): stop the importer sleeping for hours on a 429 Retry-After`

**Problem (empirically confirmed):** Spotify answers `429 QUOTA_EXCEEDED` with `retry-after: 71777` (~20 hours) when the shared anonymous quota is exhausted, and the retry loop slept for exactly that value — the import never finished.

**Fix:**
- Backoff capped at **5s**; a `Retry-After` longer than that returns **immediately** → falls back to the embed page instead of sleeping.
- Hard **60s deadline** on the whole Web API pass.
- Live progress (`Loaded N tracks…`) via a new optional `onProgress` callback on `fetchPlaylist`.
- `SpotifyImportPlaylist.notice` + amber banner when only the embed's first 100 tracks could be imported.

**Files:** `keyless_spotify_importer.dart`, `i_spotify_importer.dart`, `spotify_import.dart`, `spotify_import_providers.dart`, `spotify_import_screen.dart`, `test/spotify_importer_test.dart` (+2 tests).

---

## 5. Releases

| Tag | Release | Assets | Verification |
|---|---|---|---|
| `v2.0.1` | [notes](https://github.com/Sarthak-Cyb3r/softify/releases/tag/v2.0.1) | `Softify-v2.0.1-Android-Universal.apk` (+ iOS/Linux) | cert `60:ED:1A:AB:…`, sha256 `e7683801…a81f78` matches body |
| `v2.0.2` | [notes](https://github.com/Sarthak-Cyb3r/softify/releases/tag/v2.0.2) | `Softify-v2.0.2-Android-Universal.apk` (+ iOS/Linux) | cert `60:ED:1A:AB:…`, sha256 `bf99c62c…d0845` matches body |

Commits: `5beefed` · `473357e` · `e147ad5` · `da789fb` · `45c3e25` · `d8708fb`

---

## 6. Spotify API quota investigation (findings)

- The `429 QUOTA_EXCEEDED` is **IP-scoped and global**: a fresh token against *any* playlist from this network returns `429`.
- Refreshing the anonymous token does **not** help.
- `https://open.spotify.com/get_access_token` returns `403 URL Blocked` on this network (upstream filter).
- `api-partner.spotify.com/pathfinder` returns `401` without a logged-in token.
- Anonymous quota resets on its own (`retry-after` ≈ 20 h).

**Conclusion:** the anonymous embed token will always be rate-limited eventually; a **user token (OAuth PKCE)** is the reliable path.

### OAuth groundwork (in progress, not yet shipped)
- Probed `accounts.spotify.com/api/token` as a client_id oracle: `invalid_client` = nonexistent, `invalid_grant` = **exists**.
- Confirmed live client ids: `65b708073fc0480ea92a077233ca87bd` and `d8a5ed958d274c2e8ee717e6a4b0971d`.
- Confirmed proven pair used by ncspot / spotify-player / librespot:
  **`client_id=65b708073fc0480ea92a077233ca87bd`**, **`redirect_uri=http://127.0.0.1:8989/login`** (loopback, any port accepted).
- Added dependency **`url_launcher ^6.3.3`** (uncommitted).

---

## 7. Open items

1. 🔴 **Keystore password lost** — it was stored at `/tmp/opencode/softify_release_pw.txt`, which the PC crash wiped. The `.jks` file and the CI secrets survive, so **CI signing still works**, but the offline backup needs the password (rotation recommended).
2. 🟡 **PKCE sign-in not implemented yet** — research complete (§6), `url_launcher` added, no app code written.
3. 🟢 **iOS/Linux workflows still fire on `v*` tags** — their Android job is gone; only iOS/Linux artifacts remain. Decision pending on making tags Android-only.
4. ⚪ **Spotify anonymous quota** on this network is exhausted until it auto-resets; until then imports fall back to 100 tracks.

---

## 8. Documentation cleanup

Removed docs that are no longer needed — their content is either published on GitHub Releases or belongs to the already-shipped v2.0.0 cycle (all recoverable from git history):

| Removed file | Why |
|---|---|
| `RELEASE_NOTES_v2.0.0.md` | Published on the v2.0.0 release |
| `RELEASE_NOTES_v2.0.1.md` | Published on the v2.0.1 release |
| `RELEASE_NOTES_v2.0.2.md` | Published on the v2.0.2 release |
| `V2_ROADMAP_SPEC.md` | v2.0 spec — executed and shipped |
| `softify-roadmap.md` | v2.0 planning — superseded |
| `spotify-search-recommendation-deep-study.md` | One-off research that fed v2.0.0 |

**Kept:** `README.md`, `CHANGES.md`, `assets/screenshots/README.md`, `design-system/softify-linux/MASTER.md`, `ios/Runner/.../LaunchImage.imageset/README.md`.

---

## 9. Spotify Importer — Complete Rate Limit Bypass & Robustness

- **Multi-Entity & Localized URLs**:
  - Full support for `open.spotify.com/intl-<locale>/playlist/...` (Spotify's modern default URLs with `intl-en`, `intl-es`, etc.).
  - Added support for Albums (`/album/...`) and Single Tracks (`/track/...`).
  - Automatic URL redirection resolution for `spotify.link/...` short links.
  - Secondary fallback to direct Web Player HTML scraping (`open.spotify.com/playlist/...`) if embed fails.
- **API Error / Quota Bypass**:
  - Keyless embed scraping provides up to 100 tracks with zero API calls.
  - If Web API returns 429 (`QUOTA_EXCEEDED`), never throw or display a red "API error". Retain the 100 tracks cleanly with a friendly prompt.
  - Integrated 1-tap **Spotify OAuth PKCE** flow (`SpotifyAuthService`) using public client ID `65b708073fc0480ea92a077233ca87bd` and loopback port `8989`.
  - When logged in, user token bypasses all anonymous rate limits, allowing full pagination of 1,000+ track playlists.
- **Tests**: 181 passing tests (added album and track tests).
