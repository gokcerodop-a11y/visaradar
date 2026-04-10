# VisaRadar — Manual QA Checklist

Pre-release test plan for the MVP. Run this end-to-end on a **real device** before
each TestFlight / internal build submission. Works for both iOS and Android.

**Version:** 0.1.0
**Platforms:** iOS 16+, Android 10+

---

## How to use this checklist

- Work through each section in order on a freshly installed build.
- Mark each item ✅ Pass, ❌ Fail, or ⏭ Skip (with a reason).
- If an item fails, note the exact screen and what you expected vs what happened.
- A clean pass means every item is ✅.

---

## 0. Test Preparation

- [ ] Install a fresh build (not an update) — delete the app first if it was installed before.
- [ ] Set device to English language.
- [ ] Ensure location permission is NOT pre-granted (revoke in Settings if needed).
- [ ] Ensure notification permission is NOT pre-granted (revoke in Settings if needed).
- [ ] Have at least 2 country examples ready to test trips (e.g. Germany, France).

---

## 1. First Launch & Onboarding

- [ ] App opens to the **Welcome** screen (not the Radar screen).
- [ ] App name "VisaRadar" appears correctly — no "Visaradar" or typo.
- [ ] Tap through all 7 onboarding steps without skipping — no crashes.
- [ ] **Step: Nationality** — search for and select a country. Selection persists to next step.
- [ ] **Step: Passport Type** — select one option. Teal highlight and checkmark appear.
- [ ] **Step: Residence Status** — select one option.
- [ ] **Step: Travel Mode** — select one option.
- [ ] **Step: Language** — switch to Turkish, then back to English. Setting persists.
- [ ] **Step: Permissions** — location permission dialog appears and can be granted or denied.
- [ ] After completing onboarding, app navigates to the **Radar** screen (bottom nav visible).
- [ ] Close and reopen the app — onboarding does NOT show again (goes directly to Radar).

---

## 2. Profile Persistence

- [ ] Go to **Settings → Travel Profile**.
- [ ] Verify the nationality, passport type, residence status, and travel mode saved from onboarding are visible.
- [ ] Edit one field (e.g. change travel mode). Tap Save.
- [ ] Go back to Settings — the updated value is shown in the subtitle.
- [ ] Force-quit and reopen app — profile changes persist.

---

## 3. Adding Trips

- [ ] Go to **Trips** tab — shows the empty state with "No trips yet" and an add button.
- [ ] Tap **Add your first trip** (or the + button).
- [ ] Tap **Select country** — country picker opens with a search bar.
- [ ] Search for "Ger" — Germany appears. Tap Germany — picker closes, Germany is selected.
- [ ] Notice the Schengen status card shows "Schengen country" in teal.
- [ ] Tap **Entry date** — date picker opens. Select a date 30 days ago. Confirm.
- [ ] Tap **Exit date** — date picker opens. Select a date 20 days ago. Confirm.
- [ ] Tap **Add** (top right) — trip is saved, screen closes.
- [ ] Trips list shows the Germany trip with: flag, date range, day count, Schengen badge.
- [ ] **Schengen count on Radar tab** now shows days used > 0.

---

## 4. Ongoing Trip

- [ ] Tap the + button to add another trip.
- [ ] Select France. Set entry date to 5 days ago. Leave **exit date empty**.
- [ ] **Warn dialog** — "Open trip already exists" dialog should appear (if first ongoing trip for any country). Tap "Add anyway".
- [ ] France trip appears in Trips list with an **Ongoing** badge (teal pill) instead of Schengen badge.
- [ ] Date shows "From [entry date]" not "→ Ongoing".
- [ ] Days counter shows "X days so far".
- [ ] **Radar → Travel Summary** card shows: Current stay with a day count in teal.

---

## 5. Editing & Deleting Trips

- [ ] Tap a trip card — edit screen opens with the correct values pre-filled.
- [ ] Change the exit date. Tap **Save**. Trip card updates immediately.
- [ ] Swipe a trip card left — delete background appears in red.
- [ ] Confirm delete in the dialog — trip is removed from the list.
- [ ] Delete all trips — empty state shows again.

---

## 6. Schengen Calculator

- [ ] Add at least 2 Schengen trips (e.g. Germany 90 days ago for 30 days, France ongoing).
- [ ] Go to **Radar** tab — **Schengen Status** card shows: days used, days left, progress bar.
- [ ] Verify "days used" matches the total days across your Schengen trips in the rolling 180-day window.
- [ ] The risk badge changes color: green (Safe) → yellow (Warning) → red (Critical).
- [ ] **Alerts card** (below Schengen card): shows "All clear" when days remaining > 15.
- [ ] Add enough Schengen days to exceed 75 — alerts card should shift to Warning state.

---

## 7. Location Permission — Allow

- [ ] If not already granted, go to **Radar** tab.
- [ ] **Location card** shows "Not detecting" with an **Enable** button.
- [ ] Tap **Enable** — system permission dialog appears.
- [ ] Grant permission — Location card updates to "Detecting…" and then shows the detected country.
- [ ] The **Country** tab AppBar title updates to the detected country's name.

---

## 8. Location Permission — Deny

- [ ] Revoke location in Settings.
- [ ] Return to app — **Location card** shows "Not detecting" with an **Enable** button.
- [ ] Tap **Enable** (denied state) — system may go to Settings (iOS) or do nothing (Android first denial).
- [ ] If permanently denied: button label changes to **Open Settings** and tapping opens the Settings app.

---

## 9. Country Tab Behavior

- [ ] With location granted and a country detected: **Country** tab shows full country info for a supported country (Germany, Greece, Bulgaria, Italy, or Turkey).
- [ ] Title in the app bar shows the country name (e.g. "Germany").
- [ ] Cards visible: Entry & Stay, Transport & Border, Money & Payments, Connectivity, Safety & Emergency, Weather & Air Quality (Coming soon), Traveler Tips.
- [ ] **Unsupported country**: Detect or add a trip to a country not in the list (e.g. Spain). Country tab shows the country header + "More destinations coming soon" card + locked skeleton cards.
- [ ] **No country, no trips**: Country tab shows "No country selected" empty state with a Log a trip button.

---

## 10. Notification Settings

- [ ] Go to **Settings → Notifications**.
- [ ] Permission tile shows correct status (Allowed / Not allowed).
- [ ] If not allowed: tap **Enable** button — system prompt appears.
- [ ] Toggle Schengen alert thresholds on/off — they toggle and persist after force-quit.
- [ ] Toggle travel reminder switches on/off — they persist.

---

## 11. Settings Screen

- [ ] Settings screen shows: Membership card, Account, Preferences, Privacy & Legal sections.
- [ ] **Travel Profile** tile shows nationality and passport type as subtitle, with a chevron.
- [ ] **Language** tile shows selected language, with a chevron.
- [ ] **Privacy Policy, Terms of Service, About VisaRadar** — all navigate to the legal screen.
- [ ] **About VisaRadar** shows version number (0.1.0), not a placeholder message.
- [ ] **Start Free Trial** button on the Membership card opens the Subscription screen.

---

## 12. Subscription / Premium Screen

- [ ] Subscription screen shows: hero section, 7-day trial badge, feature list, pricing.
- [ ] Both pricing rows visible: Turkish (₺) and International (€).
- [ ] **Start 7-Day Free Trial** button shows a snackbar: "In-app purchase coming soon."
- [ ] **Restore Purchase** button shows a snackbar: "Purchase restore coming soon."
- [ ] Close button (×) returns to Settings.

---

## 13. Border Crossing Suggestion

> Requires GPS location and an ongoing trip in a different country from your current GPS position.

- [ ] Have an ongoing trip for Country A logged (e.g. Germany).
- [ ] Physically be in Country B (or simulate on iOS Simulator with a custom location).
- [ ] After a moment, the **Radar** screen shows the **Crossing Suggestion** card (teal border).
- [ ] Card shows: from Country A → to Country B, with timestamp.
- [ ] Tap **Confirm** — ongoing trip for A is closed with today's date; new trip for B is started.
- [ ] Suggestion card disappears; Trips list reflects the update.
- [ ] Tap **Not now** — suggestion card is dismissed from Radar.
- [ ] After dismissing, the **Alerts** card reappears on Radar (no longer suppressed).

---

## 14. App Restart & Persistence

- [ ] Add 3 trips. Force-quit the app. Reopen — all 3 trips are still there.
- [ ] Grant notifications. Force-quit. Reopen — permission status still shown as Allowed.
- [ ] Dismiss a crossing suggestion. Force-quit. Reopen — suggestion does not reappear.
- [ ] Change Language to Turkish. Force-quit. Reopen — Language setting shows Turkish.

---

## 15. Notification Bell (Radar)

- [ ] Tap the notification bell icon in the Radar screen header (top right).
- [ ] Navigates directly to the Notifications settings screen.
- [ ] Back button returns to Radar.

---

## 16. Empty States

| State | Expected UI |
|---|---|
| No trips, no location | Trips: empty state with Add button. Radar Travel Summary: placeholder row. |
| One closed trip | Trips: card with date range. No ongoing badge. |
| One ongoing trip | Trips: card with Ongoing badge, "From [date]", teal day count. |
| Supported country (GPS) | Country tab: full info cards. |
| Unsupported country (GPS) | Country tab: header + Coming Soon cards. |
| No country at all | Country tab: "No country selected" empty state with Log a Trip CTA. |
| Notifications denied | Notification settings: "Not allowed" badge, Enable button. |
| Location denied | Radar location card: "Not detecting" with Enable / Open Settings. |

---

## 17. Debug Tools Check (Release Build)

> Run these on the **release** build (not debug).

- [ ] **Radar screen**: NO purple debug panel visible.
- [ ] **Notification Settings**: NO "Developer tools" section visible.
- [ ] No "DEBUG — REMOVE BEFORE SHIP" text anywhere in the app.

---

## 18. Edge Cases

- [ ] Add a trip with entry date today and no exit — day count shows 1 day so far.
- [ ] Add a trip with entry and exit on the same day — day count shows 1 day.
- [ ] Try adding a second ongoing trip — confirmation dialog appears.
- [ ] Set exit date before entry date — validation error appears, cannot save.
- [ ] Open the app without any internet connection — app loads normally (all data is local).

---

## Sign-off

| Tester | Date | Platform | Result |
|--------|------|----------|--------|
| | | iOS | |
| | | Android | |

**Build tested:** `0.1.0 (1)`
**Notes:**

---

*Last updated: March 2026*
