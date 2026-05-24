# LiseAI — Manual QA Test Plan

**Version**: 1.0.0
**Last updated**: 2026-05-24
**Scope**: TestFlight / production release candidate validation.

This plan covers the user-visible flows that cannot be automatically verified
from CLI. Each section lists prerequisites, the exact gesture sequence, the
expected result, and known edge cases.

A pass requires **all** "Expected" rows to match. A single fail blocks release.

---

## How to use this document

1. Build a fresh release (`flutter build macos --release` or
   `flutter build ios --release --no-codesign`) and install on a clean device.
2. Walk each section top-to-bottom. Tick `[x]` for pass, `[ ]` for fail.
3. For any fail, capture: device model, OS version, screenshot, log excerpt
   (Settings → Diagnostics → Kopyala).
4. File issues with the section number and pass/fail summary at the top.

---

## 1. Onboarding flow

### 1.1 First launch
- [ ] App opens to the onboarding welcome screen (not directly to AI OS).
- [ ] Welcome screen is in Turkish and shows the LiseAI logo/orb.
- [ ] Continue button responds to first tap (no double-tap required).

### 1.2 Level selection
- [ ] Grid shows grade levels 9 / 10 / 11 / 12 plus LGS as a separate path.
- [ ] Tapping a grade highlights it, others deselect.
- [ ] Continue is disabled until a grade is selected.

### 1.3 Teacher style selection
- [ ] All teacher styles render with name + short description.
- [ ] Selection state visually distinct from unselected.
- [ ] Continue advances to permissions.

### 1.4 Permissions
- [ ] Microphone permission prompt fires on first request only.
- [ ] Speech recognition permission prompt (iOS / macOS) fires once.
- [ ] Denying mic does NOT crash the app — onboarding still completes.
- [ ] Re-opening permissions screen after grant shows the granted state.

### 1.5 Finish onboarding
- [ ] "Bitir" / finish button persists `onboarding_done=true` to Hive.
- [ ] App routes directly to AI OS screen.
- [ ] No second onboarding pass triggered.

### 1.6 Onboarding resume (kill mid-flow)
- [ ] Start onboarding, advance to step 2, force-kill the app.
- [ ] Reopen — onboarding restarts from welcome (acceptable) and does not
      crash on partial settings.
- [ ] Completing onboarding now persists final state correctly.

### 1.7 Reopen confirms no replay
- [ ] After finishing onboarding once, fully quit and relaunch.
- [ ] App opens directly into AI OS screen — onboarding does not repeat.
- [ ] `onboarding_done` reads `'true'` in Hive (verify via diagnostics).

### 1.8 Guest mode
- [ ] If guest mode is exposed in onboarding (skip account), completing it
      still persists `onboarding_done=true`.
- [ ] Guest profile lacks an email/user-id but can use AI chat normally.
- [ ] No upgrade nag blocks AI chat.

---

## 2. AI chat

### 2.1 Basic text question
- [ ] Type a normal math question (e.g. "x² − 5x + 6 = 0 çöz").
- [ ] Response begins streaming within ~2 s on warm network.
- [ ] Tokens appear progressively (not all at once at the end).
- [ ] No spinner replaces the streamed text after first token.

### 2.2 Long conversation (20+ turns)
- [ ] Send 20 sequential messages.
- [ ] Older messages remain visible by scrolling up.
- [ ] No memory pressure crash, no UI lag during scroll.
- [ ] System prompt does not grow unbounded (verify via diagnostics token
      count if exposed).

### 2.3 Streaming interruption
- [ ] During an active stream, tap the "stop" / cancel control.
- [ ] Stream ends immediately, partial response is preserved in history.
- [ ] Next message can be sent without restart.

### 2.4 History persistence
- [ ] Send 5 messages, fully quit the app, relaunch.
- [ ] Conversation list shows the prior conversation at the top.
- [ ] Tapping it restores the full message history in order.

---

## 3. Multimodal (image / PDF)

### 3.1 Image upload
- [ ] Upload a clear math problem photo (well-lit, single problem).
- [ ] Image preview renders before send.
- [ ] Claude Vision returns a structured solution with steps.
- [ ] No "image too large" silent failure.

### 3.2 PDF upload
- [ ] Upload a multi-page PDF (3+ pages) of practice problems.
- [ ] Page picker renders thumbnails.
- [ ] Selecting a page extracts its rendered image and sends to Claude.
- [ ] Response references the selected page's content.

### 3.3 Claude Vision response & fallback
- [ ] Test with a blurry image — system reports it cannot read clearly
      rather than hallucinating.
- [ ] Test with airplane mode — graceful "offline" message, no crash.
- [ ] After re-enabling network, retry works.

---

## 4. Whiteboard / lesson board

### 4.1 Open board
- [ ] Open a lesson-board page from AI OS.
- [ ] Canvas renders with chalk-style background.
- [ ] Tool palette (pen, eraser, clear) is visible.

### 4.2 Draw
- [ ] Drag finger / stylus / mouse — line follows cursor smoothly.
- [ ] No stroke jitter or doubled paths.
- [ ] Pen color and width are stable across strokes.

### 4.3 Erase
- [ ] Switch to eraser, drag across a stroke — only intersected portion
      is removed; rest of the stroke is preserved.
- [ ] Eraser does not erase the entire path on a single hit.

### 4.4 Clear
- [ ] Tap clear / trash — board empties.
- [ ] Confirmation prompt appears if implemented (no destructive surprise).

### 4.5 Close / reopen
- [ ] Close the board, reopen — last lesson timeline (if any) restores.
- [ ] Student strokes are not unexpectedly persisted across sessions
      unless that's the intended behavior.

---

## 5. Memory restore

### 5.1 Restore after restart
- [ ] Have a substantive chat (5+ turns mentioning specific facts:
      name, grade, weak subject).
- [ ] Fully quit, relaunch.
- [ ] Open same conversation — full history visible.
- [ ] Continue the chat: AI references prior facts (continuity working).

### 5.2 Long-term memory
- [ ] Across several sessions, identify a recurring weakness (e.g. "I keep
      making sign errors in integrals").
- [ ] After 3+ sessions, AI should bring this up proactively in a new chat.
- [ ] Diagnostics → memory section shows non-empty mastery / mistake records.

---

## 6. Voice

### 6.1 Microphone button
- [ ] Tap mic button — recording state visible (orb / waveform animates).
- [ ] Permission prompt only on first use.
- [ ] Speaking → tokens appear as live transcript.

### 6.2 Speech-to-text
- [ ] Turkish dictation produces accurate text (within reasonable margin).
- [ ] Pausing for >2 s stops recording automatically.
- [ ] Tapping mic again restarts cleanly.

### 6.3 Local TTS
- [ ] AI response is spoken aloud.
- [ ] Voice does not stutter or skip mid-word.
- [ ] Volume is reasonable on default device volume.

### 6.4 TTS interruption
- [ ] While TTS speaks, tap mic — speech stops immediately.
- [ ] STT begins listening, no audio overlap.

### 6.5 STT interruption
- [ ] While STT listens, tap stop — recording ends, no phantom transcript
      appended afterward.

### 6.6 Mute / unmute
- [ ] Mute control silences TTS on the next utterance.
- [ ] Unmute restores audible TTS.

---

## 7. Offline-first

### 7.1 Simulate offline
- [ ] Enable airplane mode (or disable wifi + cell).
- [ ] Diagnostics shows `[Connectivity] offline`.
- [ ] Existing conversations open from cache.

### 7.2 Cached history opens
- [ ] Previously saved conversations remain fully readable.
- [ ] No "loading…" spinner stays indefinitely.

### 7.3 AI unavailable message
- [ ] Sending a new message offline shows a graceful "şu an çevrimdışı"
      style message — not a stack trace.
- [ ] No retry storm in logs (rate-limited retries only).

### 7.4 Network switching
- [ ] Toggle wifi off → on → off; app keeps running.
- [ ] Connectivity status updates within ~15 s of state change.
- [ ] Sync queue flushes when back online (see Supabase section).

---

## 8. Background / foreground

### 8.1 Background → foreground
- [ ] Send the app to background (Cmd+Tab / home gesture) mid-conversation.
- [ ] Reopen after 30 s — chat UI restores, no orphan loading state.

### 8.2 Background while streaming
- [ ] Trigger a stream, immediately background.
- [ ] Foreground after 10 s — stream either completes in background or
      ends gracefully; partial text persists.

### 8.3 Low battery / power mode
- [ ] Enable low-power mode (or simulate via Battery Saver).
- [ ] Continuous voice / streaming continues without runaway battery use.
- [ ] No animation lag from forced 60→30 fps cap (graceful degradation).

### 8.4 App killed / reopened
- [ ] Force-kill app while a lesson is mid-session.
- [ ] Reopen — session recovery prompt (if exposed) restores state, or
      app routes cleanly to AI OS without crash.

---

## 9. Diagnostics screen

### 9.1 Open
- [ ] Long-press AI OS title → diagnostics screen opens.
- [ ] All scenario checks complete within ~5 s.
- [ ] Summary row shows pass / warn / fail counts.

### 9.2 Supabase status
- [ ] If keys not configured: status shows "Supabase yapılandırılmamış"
      (graceful, not failing).
- [ ] If configured: connection status, user-id, latency populate.

### 9.3 Sync queue
- [ ] Pending count visible.
- [ ] "Kuyruğu Temizle" button only appears when pending > 0.
- [ ] Tapping it actually flushes the queue (latency updates).

### 9.4 Memory status
- [ ] Memory section shows long-term mastery / mistake records.
- [ ] After clearing app data, memory section is empty (no stale state).

### 9.5 AI cost
- [ ] Per-session token + cost displayed.
- [ ] Increments after each AI call.
- [ ] Does not negatively count or overflow.

### 9.6 Release validator
- [ ] Release validator runs all checks.
- [ ] Failing checks are highlighted with red icon and detail.
- [ ] Verdict "✅ Yayın için hazır" or "❌ N kritik hata".

### 9.7 Runtime health (new, added in QA phase)
- [ ] Uptime increments each second.
- [ ] Active stream count returns to 0 when chat is idle.
- [ ] No orphan loading warning when idle.
- [ ] Storage estimate matches conversation count roughly.

---

## 10. Subscription gating

### 10.1 Free tier limits
- [ ] Free user hits configured daily limit (if any).
- [ ] Limit hit shows upgrade prompt, not a crash.
- [ ] Upgrade nag is dismissible.

### 10.2 Premium pass-through
- [ ] Premium user has no gating banners.
- [ ] All advanced features (voice, long sessions) accessible.

---

## 11. Robustness

### 11.1 Onboarding loop detection
- [ ] If `onboarding_done` is `'true'`, opening the app 10 times in a row
      never opens onboarding.

### 11.2 Duplicate process detection
- [ ] Launch app, then launch again from another mechanism — only one
      instance should be visible. (macOS: single window; iOS: N/A.)

### 11.3 Loading indicators
- [ ] No spinner stays on screen >10 s without either resolving or showing
      an error message.

### 11.4 Crash scenarios
- [ ] Trigger a Vision call with a malformed image — graceful error, no
      crash.
- [ ] Trigger a network failure mid-stream — partial text preserved, error
      surfaced.
- [ ] Force-kill during Hive write — relaunch must not show Hive lock
      error; storage opens cleanly.

---

## Sign-off

| Tester | Build | OS | Date | Pass/Fail | Notes |
|--------|-------|----|----|-----------|-------|
|        |       |    |    |           |       |
