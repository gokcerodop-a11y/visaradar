# LiseAI — Manual QA Execution Checklist

**Version**: 1.0.0
**Created**: 2026-05-24
**Companion to**: `manual_test_plan.md` (the *what to test*). This document
is the *what was actually tested* — fill it in during a real session.

---

## How to use

1. Build a fresh release: `flutter build macos --release` *or*
   `flutter build ios --release --no-codesign`.
2. Install on a clean device (or wipe app data first via:
   delete `~/Library/Containers/com.example.liseAi` on macOS,
   uninstall the app on iOS).
3. Walk each section top-to-bottom. For each row, mark `PASS` or `FAIL` and
   write a one-line note (observations, latency, error text, screenshot
   filename).
4. Use the **Final Sign-off** table at the bottom to record the overall
   verdict.
5. If anything FAILs, copy the diagnostics report (Diagnostics → Kopyala)
   into the `Notes` column for that row.

Mark `N/A` if a row is not applicable to the current build / platform.

---

## 1. First launch

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 1.1 | Launch the app from cold start | Window appears within 3 s |  |  |
| 1.2 | Count visible app windows | Exactly one |  |  |
| 1.3 | Wait 15 s on first screen | No infinite loading spinner |  |  |
| 1.4 | If fresh install / wiped: onboarding appears | Welcome screen visible |  |  |
| 1.5 | If existing user: AI OS appears | No onboarding repeat |  |  |

---

## 2. Onboarding flow

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 2.1 | Welcome → Next | Advances to next step on first tap |  |  |
| 2.2 | Grade selection | Tapping a grade highlights it; others deselect |  |  |
| 2.3 | Continue without grade | Next button is disabled until selection |  |  |
| 2.4 | Teacher style selection | All styles render; selecting one persists |  |  |
| 2.5 | Permissions screen | Mic / speech permission rationale visible |  |  |
| 2.6 | Grant mic permission | OS prompt appears, accepting routes forward |  |  |
| 2.7 | Deny mic permission | App still completes onboarding, no crash |  |  |
| 2.8 | Tap "Bitir" | Persists state, routes to AI OS |  |  |
| 2.9 | Force-quit and relaunch | App opens directly to AI OS, no onboarding |  |  |
| 2.10 | Wipe app data, relaunch | Onboarding restarts cleanly |  |  |

---

## 3. Basic AI chat

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 3.1 | Type `Parabol nedir basitçe anlat` and send | Send button responds |  |  |
| 3.2 | First token arrival | Within ~2 s on warm network |  |  |
| 3.3 | Response progress | Tokens stream visibly (not one-shot dump) |  |  |
| 3.4 | Response completion | Full answer rendered, no truncation |  |  |
| 3.5 | Crash check during stream | No exception in logs |  |  |
| 3.6 | Send a second message | New response works |  |  |
| 3.7 | Quit and relaunch | Conversation appears in history with same content |  |  |

---

## 4. Voice conversation

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 4.1 | Tap mic button | Recording state visible (orb / waveform animates) |  |  |
| 4.2 | Speak a Turkish question (e.g. `Türev nedir anlat`) | Live transcript appears |  |  |
| 4.3 | Pause for 2-3 s | Recording stops automatically |  |  |
| 4.4 | AI response | Streams as text |  |  |
| 4.5 | TTS plays (if enabled) | Voice audible, no stutter |  |  |
| 4.6 | Tap mic during TTS | TTS stops, STT begins, no overlap |  |  |
| 4.7 | Tap stop during STT | Recording ends, no phantom transcript |  |  |
| 4.8 | Mute toggle | Next TTS utterance is silent |  |  |
| 4.9 | Unmute | TTS audible again |  |  |

---

## 5. Image upload

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 5.1 | Tap attach → choose image | File picker opens |  |  |
| 5.2 | Pick a clear math problem photo | Preview renders before send |  |  |
| 5.3 | Send | Claude Vision returns structured solution |  |  |
| 5.4 | Send a blurry / unreadable image | Friendly Turkish error, no crash |  |  |
| 5.5 | Send while offline | Graceful "şu an çevrimdışı" message |  |  |
| 5.6 | Recover online and retry | Works without restart |  |  |

---

## 6. PDF upload

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 6.1 | Tap attach → choose PDF | File picker opens |  |  |
| 6.2 | Pick a 3-5 page PDF | Page thumbnails render |  |  |
| 6.3 | Select a page | Selection highlights |  |  |
| 6.4 | Send | AI returns analysis referencing that page |  |  |
| 6.5 | Switch pages mid-session | No crash on rapid switching |  |  |
| 6.6 | Try a corrupt PDF | Friendly error, no crash |  |  |

---

## 7. Whiteboard / lesson board

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 7.1 | Open board from AI OS | Canvas renders with chalk background |  |  |
| 7.2 | Drag to draw a stroke | Line follows cursor smoothly |  |  |
| 7.3 | Draw 5+ strokes | No jitter, no doubled lines |  |  |
| 7.4 | Switch to eraser | Erase tool icon highlighted |  |  |
| 7.5 | Drag across a stroke | Only intersected portion removed |  |  |
| 7.6 | Tap clear | Board empties (with confirm if implemented) |  |  |
| 7.7 | Close board | Returns to AI OS, no orphan window |  |  |
| 7.8 | Reopen board | Renders within 1 s, not frozen |  |  |
| 7.9 | Sustained drawing (~1 min) | No frame drops, no memory spike |  |  |

---

## 8. Memory / session restore

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 8.1 | Ask: `Bugün limit konusunu çalışıyoruz` | AI responds |  |  |
| 8.2 | Continue chat for 5 turns with limit-related questions | All responses cohere |  |  |
| 8.3 | Force-quit app | Clean exit |  |  |
| 8.4 | Relaunch | History list shows the prior conversation |  |  |
| 8.5 | Open prior conversation | All messages restored in order |  |  |
| 8.6 | Ask: `Geçen ne konuşmuştuk?` | AI references limit topic, not generic |  |  |
| 8.7 | Diagnostics → memory section | Shows non-empty long-term memory |  |  |

---

## 9. Offline / network switching

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 9.1 | Enable airplane mode | OS network indicator switches |  |  |
| 9.2 | Open app | Loads to AI OS (or last screen) without hang |  |  |
| 9.3 | Open prior conversation | Full cached history visible |  |  |
| 9.4 | Send a new message | Friendly Turkish offline message, not crash |  |  |
| 9.5 | Diagnostics → connectivity row | Reports `offline` |  |  |
| 9.6 | Disable airplane mode | Diagnostics flips to `online` within ~15 s |  |  |
| 9.7 | Retry the queued message | Sends successfully |  |  |
| 9.8 | Toggle wifi off→on→off rapidly | No crash, no duplicate timer |  |  |

---

## 10. Diagnostics screen

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 10.1 | Long-press "Lise AI" title | Diagnostics screen opens |  |  |
| 10.2 | Scenario checks complete | Within ~5 s |  |  |
| 10.3 | Summary row | Pass / Warn / Fail counts visible |  |  |
| 10.4 | Memory section | Long-term + mistake records visible (or empty) |  |  |
| 10.5 | Supabase status row | Shows configured / not configured cleanly |  |  |
| 10.6 | Sync queue row | Pending count + flush button visible |  |  |
| 10.7 | AI cost row | Token + cost displayed; not negative |  |  |
| 10.8 | Runtime sağlık section | Uptime + RSS + active streams visible |  |  |
| 10.9 | Tap "Doğrulama Süitini Çalıştır" | Suite runs, results render |  |  |
| 10.10 | Release validator | Verdict line shows ✅ or ❌ |  |  |
| 10.11 | Kopyala button | Clipboard contains the report |  |  |

---

## 11. Long session (20 minutes)

| # | Step | Expected | Pass/Fail | Notes |
|---|------|----------|-----------|-------|
| 11.1 | Start a 20-minute timer | — |  |  |
| 11.2 | Use the app organically (chat + board + voice + image) | No crash |  |  |
| 11.3 | Every 5 min: count windows | Exactly one process |  |  |
| 11.4 | Every 5 min: open and close diagnostics | No Hive lock error |  |  |
| 11.5 | Watch for orphan spinners | None lingers >10 s |  |  |
| 11.6 | Watch memory in diagnostics | Stays under 400 MB RSS on macOS / 250 MB on iOS |  |  |
| 11.7 | End of 20 min: check freeze count | Zero (or explain spikes) |  |  |
| 11.8 | End of 20 min: check last-crash timestamp | "Hiç" (never) |  |  |

---

## 12. Final manual sign-off

| Tester | Date | Device | OS | Build | Pass / Fail | Notes |
|--------|------|--------|----|-------|-------------|-------|
|        |      |        |    |       |             |       |
|        |      |        |    |       |             |       |
|        |      |        |    |       |             |       |

---

## Failure log

For each FAIL in the tables above, expand here:

### Failure 1
- **Section / row**:
- **Device + OS + build**:
- **Steps to reproduce**:
- **Expected**:
- **Actual**:
- **Diagnostics report** (paste from Kopyala):
- **Severity**: blocker / major / minor

### Failure 2
- (template — copy as needed)

---

## Release verdict

Tick exactly one:

- [ ] ✅ **GO** — all rows pass or have acceptable N/A. Ship to TestFlight.
- [ ] ⚠️ **GO with caveats** — minor fails listed above, no blockers, fix
      planned post-release.
- [ ] ❌ **NO-GO** — one or more blockers in the failure log. Hold release.
