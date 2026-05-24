# Real Device Test — VisaRadar

Run a Release build of VisaRadar on a physical iPhone before any TestFlight
upload. Simulator passes are necessary but not sufficient — location, push
permission, dark-mode rendering, and IAP behavior all differ on hardware.

---

## 1. Pre-flight on the laptop

```bash
flutter doctor
flutter clean
flutter pub get
flutter analyze
```

All four must finish without errors. Resolve `flutter doctor` red lines before
plugging anything in.

## 2. Hardware checklist

| Requirement | Why |
|---|---|
| iPhone running iOS 13.0+ | Matches `IPHONEOS_DEPLOYMENT_TARGET = 13.0` |
| Device unlocked and trusted to this Mac | Xcode can't sign otherwise |
| At least 200 MB free | App is ~20 MB but Xcode caches more |
| Wi-Fi or USB connection to the Mac | Wireless deploy is fine after first cable pair |
| Location services on in iOS Settings → Privacy | App can't request location otherwise |
| Notifications enabled at OS level | Same reason |

If the iPhone has VisaRadar installed from a previous build, **delete it
first** so caches and onboarding state are clean.

## 3. Signing setup (one-time per device)

1. `open ios/Runner.xcworkspace`
2. Top of the project navigator: select **Runner** → target **Runner**.
3. **Signing & Capabilities** tab.
4. Confirm:
   - ✅ Automatically manage signing
   - Team: the dev account that owns `V8CC8CQG3W`
   - Bundle Identifier: `com.visaradar.visaradar`
5. If Xcode shows a red "Failed to register bundle identifier" error:
   - Open developer.apple.com → Certificates, Identifiers & Profiles → Identifiers
   - Confirm `com.visaradar.visaradar` is registered to your team
   - Back in Xcode click **Try Again**

First time on a personal-team device, Xcode may produce a free 7-day
provisioning profile — fine for testing, expires weekly.

## 4. Trust the developer profile on the iPhone

After the first install attempt the device may show
"Untrusted Developer". To clear it:

`iPhone Settings → General → VPN & Device Management → <Your Team>` →
**Trust**. Re-run the install from Xcode.

## 5. Install a Release build

Two options:

### A. Via Xcode (recommended for QA pass)

1. In Xcode toolbar, choose your iPhone as the run destination.
2. Edit scheme (`⌘<`) → Run → set **Build Configuration** to **Release**.
3. **Run** (`⌘R`).

This installs a signed Release build but skips App Store distribution. The
app icon appears on the home screen; you can launch it without Xcode running.

### B. Via CLI

```bash
flutter run --release -d <device-id>
```

`flutter devices` lists connected devices and their IDs.

## 6. First-launch hardware verification

In order, on the home screen tap the VisaRadar icon. Verify each item.

### App lifecycle

- [ ] Launch screen displays for <2 s, no white flash longer than that
- [ ] First-launch routes to **Welcome / Onboarding** (not Radar)
- [ ] App name on home screen reads **VisaRadar** (capital R)
- [ ] App icon renders at full resolution, not blurry
- [ ] Force-quit (swipe up, swipe off) and relaunch — onboarding state persists
      if completed, restarts if not

### Permission prompts (text and timing matter to Apple review)

- [ ] On the **Permissions** onboarding step, tapping the location request
      shows the iOS system prompt **with the exact string from Info.plist**
      ("VisaRadar uses your current location to detect which country you are
      in so it can show the right Schengen and visa information for that
      country.")
- [ ] No "Always Allow" option is offered — only **Allow Once**, **Allow While
      Using App**, **Don't Allow**
- [ ] Notification permission prompt appears when expected (Settings →
      Notifications → Enable), with the standard iOS phrasing
- [ ] Denying either permission does **not** crash or block the app

### Core flow on hardware

- [ ] Onboarding 7 steps complete; navigation is smooth on a 60 Hz device
- [ ] Add a trip with a real country picker entry — keyboard appears,
      dismisses, no layout glitch
- [ ] Trip persists across a force-quit
- [ ] Radar screen Schengen counter updates after adding a Schengen trip
- [ ] Country tab: with location granted, detected country flag matches
      the iPhone's actual location (test in your home country)
- [ ] Settings → **Diagnostics** screen opens, fills in all rows, none stay
      stuck on "Checking…"

### Diagnostics screen — the truth source on device

Open **Settings → Diagnostics**. On a Release TestFlight-equivalent build:

| Row | Expected on hardware |
|---|---|
| Version | `1.0.0` (matches `pubspec.yaml`) |
| Build mode | `Release` |
| Bundle ID | `com.visaradar.visaradar` |
| Platform | `iOS` |
| Location | `When in use` if granted, `Denied` if you rejected, never empty |
| Notifications | `Allowed` after granting, `Not allowed` otherwise |
| Connectivity | `Wi-Fi`, `Mobile`, or `Offline` — never stuck on `Checking…` |
| Detected country | A 2-letter ISO + name once GPS resolves, else `—` |
| Release readiness | All five rows must show green check marks |

If any release-readiness check is red, **stop and fix before TestFlight**.

### Rendering

- [ ] Dark mode looks correct in all four bottom tabs
- [ ] No clipped text in headings on a small phone (iPhone SE)
- [ ] No white flash between routes
- [ ] Safe areas respected on a notch / Dynamic Island device

### Network behavior

- [ ] Toggle airplane mode → reopen app → still launches, no crash
- [ ] Diagnostics → Connectivity row reflects `Offline`
- [ ] Re-enable Wi-Fi → tap refresh on Diagnostics → row updates to `Wi-Fi`

### Stability

- [ ] Use the app for 5 continuous minutes — no crash, no infinite loading
- [ ] Background the app for >30 minutes, foreground it — state is intact
- [ ] Charge level doesn't drop noticeably from background (no rogue timer)

## 7. Console log review

While the device is attached and the app is running:

- Xcode `Window → Devices and Simulators` → select your iPhone → **Open
  Console**.
- Filter by `Runner` (the iOS executable name).
- Watch for `fatal`, `crash`, `Exception`, or repeated red errors.
- Stack traces with `flutter`, `Riverpod`, or `geolocator` in the symbol path
  are app-level — note them and fix before TestFlight.

## 8. Known-good baseline

A clean v1.0.0 build on iPhone 14, iOS 17.5:

- Cold start to Radar after onboarding: < 1.5 s
- Memory at idle on Radar: ~80–110 MB
- No background CPU spikes
- Battery use after 1 h foreground active: < 4 %

Significant drift from these numbers is a red flag.

## 9. Reporting a problem found on hardware

Capture before tearing down:

1. The full text of the **Diagnostics** screen — screenshot or read each row
   into the bug report.
2. The exact build version + build number (`Diagnostics → Version` and
   `pubspec.yaml`).
3. A short video of the broken interaction (iPhone screen recording is
   enough).
4. The relevant Console excerpt.

Without those four, the bug is not actionable.
