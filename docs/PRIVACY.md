# Softify Privacy Policy

**Effective Date: November 2026**

Softify is built on the principle of **radical data privacy**. We believe music listening is private, personal, and should never be tracked, profiled, or monetized.

---

## 1. What We Collect

When using Softify with backend services enabled:
- **Anonymous Device Identifier**: A randomly generated UUID created upon first app launch. It is never linked to your name, email, Google account, phone number, IMEI, MAC address, or Android Advertising ID.
- **Synced Library Data (Optional)**: If you enable cloud sync, Softify synchronizes your playlist names, liked song IDs, and custom tags so your library stays consistent across your devices.
- **Anonymous Crash & Error Reports (Opt-In)**: If opted in via Settings, Softify transmits anonymized technical crash reports (stack traces and error codes) to help diagnose bugs. All URLs are scrubbed and query parameters are redacted before transmission.

---

## 2. What We NEVER Collect

- **We NEVER collect personal identifiers** (no email, no password, no name, no phone number).
- **We NEVER track or store your search queries**. Search history is stored 100% locally in your phone's SQLite database.
- **We NEVER track your location or GPS coordinates**.
- **We NEVER monitor or log your listening history** on the server.
- **We NEVER proxy, intercept, or record your audio streams**. Audio streams directly from the source content provider to your device.

---

## 3. "Local Only" Mode

You have complete control over network connectivity:
- In **Settings > Data & Sync**, toggle **"Local Only Mode"**.
- In Local Only mode, Softify disables all outgoing requests to Softify servers. The app operates as a 100% offline-capable, standalone music player.

---

## 4. Your Rights: Export & Deletion

Under privacy principles and regulations, you retain full ownership of your data:
1. **Data Export**:
   - Navigate to **Settings > Account > Export Data** or call `GET /v1/user/export`.
   - Softify immediately downloads a complete JSON dump of all library items, playlists, and metadata associated with your anonymous device account.
2. **Complete Account & Data Deletion**:
   - Navigate to **Settings > Account > Delete Account** or call `POST /v1/user/delete`.
   - Softify permanently purges your device record, session tokens, and all synced library rows from Cloudflare D1 immediately. Once purged, recovery is mathematically impossible.

---

## 5. Contact & Questions

If you have questions about our privacy architecture or wish to audit the server code, Softify is open-source under GPL-3.0 and AGPL-3.0 on GitHub at:
`https://github.com/Sarthak-Cyb3r/softify`
