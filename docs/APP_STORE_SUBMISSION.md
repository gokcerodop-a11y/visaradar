# App Store Submission — VisaRadar

Single source of truth for taking a TestFlight-tested build of VisaRadar to a
public App Store listing. Read `TESTFLIGHT_READY.md` first — it covers the
build-and-upload mechanics. This doc covers everything **after** the binary is
in App Store Connect.

---

## 1. Build identity (must match App Store Connect)

| Field | Value | Where it lives |
|---|---|---|
| Bundle ID | `com.visaradar.visaradar` | `ios/Runner.xcodeproj/project.pbxproj` |
| Display name | `VisaRadar` | `ios/Runner/Info.plist` → `CFBundleDisplayName` |
| Marketing version | `1.0.0` | `pubspec.yaml` → `version:` |
| Build number | `1+` (must increment per upload) | `pubspec.yaml` → `version:` |
| iOS minimum | 13.0 | `ios/Runner.xcodeproj` → `IPHONEOS_DEPLOYMENT_TARGET` |
| Orientation | Portrait only | `ios/Runner/Info.plist` |
| Privacy strings | `NSLocationWhenInUseUsageDescription` only | `ios/Runner/Info.plist` |
| In-app purchase | **None** in v1 (subscription UI hidden) | n/a |

## 2. App Store Connect — required fields

In App Store Connect → My Apps → VisaRadar → `App Store` tab → `1.0.0` version:

### App Information

- **Name**: `VisaRadar`
- **Subtitle**: optional, ≤30 chars (e.g. "Schengen day & trip tracker")
- **Category — Primary**: Travel
- **Category — Secondary**: optional (Productivity)
- **Content rights**: confirm you own the content
- **Age rating**: complete the questionnaire (expect 4+)
- **Localizations**: at minimum English (US) and Turkish (Türkçe)

### Pricing & Availability

- **Price**: Free (v1 ships without IAP — subscription UI hidden)
- **Availability**: All countries, or restrict to a launch market list

### App Privacy

Even though VisaRadar stores everything locally, you must declare data
categories. Expected declaration:

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Location → Precise location | **Yes** (foreground only, on-device) | No | No | App Functionality |
| Identifiers | No | — | — | — |
| Usage data | No | — | — | — |
| Diagnostics | No | — | — | — |

Use App Store Connect → App Privacy → Edit to enter these. The wording matters:
location is collected on-device only, never transmitted.

### Version Information (per build)

- **What's new in this version**: First release. Track your Schengen 90/180
  days, log entries and exits, see country-specific information at a glance.
- **Promotional Text**: optional, can be updated without a new build
- **Description**: 4000 chars; lead with the Schengen tracker promise, list
  the core features, end with a clear data-stays-on-device line
- **Keywords**: 100 chars total, comma-separated; e.g.
  `schengen,visa,travel,90/180,border,passport,trip,europe,stay,calendar`
- **Support URL**: required — must be reachable. Use a temporary
  GitHub Pages page or a Notion public page if no domain.
- **Marketing URL**: optional
- **Copyright**: `2026 VisaRadar`

### Screenshots (required)

Submit at least:
- **6.7"** (iPhone 15 Pro Max / 16 Pro Max) — required
- **6.5"** (iPhone 11 Pro Max / XS Max) — required if you don't submit 6.7"
- **5.5"** (iPhone 8 Plus) — required for older devices unless excluded

Generate either by:
- Running on the iOS Simulator (`Device → iPhone 15 Pro Max`) and using
  `Cmd+S` to save screenshots, then trimming to App Store dimensions
- Or using a screenshot generation tool (Fastlane snapshot, Previewed,
  Screenshot Designer) — out of scope for this checklist

Recommended scenes:
1. Radar — main dashboard with Schengen counter
2. Trips list with a logged entry
3. Add Trip flow mid-state
4. Country Info card for an active country
5. Settings / privacy clarity shot

### App Review Information

- **Sign-in required**: **No** (no auth in v1)
- **Demo account**: not needed
- **Notes**: a paragraph explaining what the app does, why it asks for
  location, that all data stays on-device, and that subscription UI is
  intentionally hidden in v1. Apple reviewers read this — being explicit
  shortens review time.
- **Attachment**: optional PDF with a few annotated screenshots if any flow
  is non-obvious

### Build

- Select the processed TestFlight build you want to ship.

## 3. Xcode → App Store distribution flow

Same as TestFlight but the final step differs:

1. Bump `pubspec.yaml` build number: e.g. `1.0.0+1` → `1.0.0+2`. Commit.
2. `flutter clean && flutter pub get && flutter analyze`
3. `flutter build ios --release` (with codesign this time, if you want to
   produce the archive from CLI; otherwise skip and go straight to Xcode).
4. `open ios/Runner.xcworkspace`
5. Destination → `Any iOS Device (arm64)`.
6. `Product → Archive`.
7. Organizer → `Distribute App` → `App Store Connect` → `Upload` →
   `Automatically manage signing` → `Upload`.

(Same submission archive can serve both TestFlight and the App Store — Apple
distinguishes by which build you attach to which version in Connect.)

## 4. Submit for review

In App Store Connect, on the `1.0.0` version page, after every required field
is filled and the build is attached:

1. Click **`Add for Review`** at the top right.
2. Confirm release option:
   - **Automatically release** — goes live as soon as Apple approves
   - **Manually release** — you press a button after approval (recommended
     for first version so you control the launch moment)
   - **Phased release for automatic updates** — only matters for v1.0.1+
3. Click **`Submit for Review`**.

Status flow: `Waiting for Review` → `In Review` → `Pending Developer Release`
(if manual) or `Ready for Sale` (if auto). Typical review time is 24–48 hours
for a first submission of a small app, but can spike to a week.

## 5. Common rejection risks (and how we've addressed them)

| Risk | Apple guideline | Status |
|---|---|---|
| Misleading location usage description | 5.1.5 | ✅ Fixed: only `WhenInUse`, no background claim |
| Non-functional subscription / paywall | 2.1, 3.1.1 | ✅ Fixed: subscription UI hidden from Settings |
| Displayed prices without working IAP | 3.1.1 | ✅ Fixed: no price strings shown in v1 |
| Bad bundle display name | 2.3.1 | ✅ Fixed: `VisaRadar` |
| Crash on launch | 2.1 | ⚠️ Verify on a clean device install before submit |
| Placeholder content visible to user | 2.3.1 | ⚠️ "Coming soon" cards in Country Info are clearly labeled, acceptable |
| Privacy declaration mismatch with code | 5.1.1 | ⚠️ Confirm App Privacy form matches: location collected on-device, no other data |
| Missing privacy policy URL | 5.1.1 | ⚠️ Must supply a real URL in App Information |
| Broken or fake support URL | 1.5 | ⚠️ Must supply a real, reachable URL |
| Apple Sign In missing when third-party login present | 4.8 | ✅ N/A — no auth |
| Background mode declared but unused | 2.5.4 | ✅ N/A — no background modes |
| App tracks user without ATT prompt | 5.1.2 | ✅ N/A — no tracking |
| In-app browser without privacy notice | 5.1.1 | ✅ N/A — `url_launcher` opens external Safari |
| Crashes / freezes | 2.1 | ⚠️ TestFlight smoke test before submit |
| Buggy onboarding loop | 2.1 | ⚠️ TestFlight: complete onboarding once, reinstall, complete again |

## 6. Pre-submit final checklist

Tick everything off before pressing `Submit for Review`.

### Code

- [ ] `flutter analyze` shows `No issues found!`
- [ ] `flutter build ios --release` (with codesign) succeeds
- [ ] Latest commit is the build you uploaded; tag the commit (e.g.
      `git tag v1.0.0-build1 && git push --tags`) for future bisecting
- [ ] No `print()` of sensitive values or stack traces in release builds
- [ ] No active feature flags pointing to demo / mock providers
      (`MockCountryDetectionService` only used in tests)

### App Store Connect

- [ ] App name, subtitle, category set
- [ ] Privacy form completed; declared data matches actual code behavior
- [ ] Privacy policy URL set and reachable
- [ ] Support URL set and reachable
- [ ] All required screenshot sizes uploaded
- [ ] Localizations filled for every language you list (en + tr)
- [ ] App Review notes explain the Schengen calculator and why location is
      requested
- [ ] Build attached to the version
- [ ] Pricing set (Free for v1)
- [ ] Release option chosen (manual recommended for v1.0.0)

### Device smoke test

- [ ] Install fresh from TestFlight on a real device, **not the dev install**
- [ ] Onboarding completes
- [ ] Add at least 2 trips, force-quit, reopen — both persist
- [ ] Location permission prompt shows the correct description
- [ ] Notifications permission prompt works; toggle a Schengen alert on/off
- [ ] All four bottom tabs open without crash
- [ ] Settings → Privacy / Terms / About all open
- [ ] No "lorem ipsum", `TODO`, or placeholder text visible anywhere
- [ ] App icon and launch screen look correct on home screen

## 7. After submission

- Watch the email tied to the App Store Connect account. Apple sends a
  message on status change.
- If **rejected**: read the Resolution Center note carefully. Most rejections
  are simple metadata fixes — answer in Resolution Center first, only resubmit
  if Apple explicitly asks for a new binary.
- If **approved + manual release**: press `Release This Version` when ready.
- If **approved + auto release**: app goes live within a few hours.

## 8. Versioning convention going forward

| Change | Marketing | Build |
|---|---|---|
| Bug fix release | `1.0.0` → `1.0.1` | reset chain, start at `1` |
| Minor feature | `1.0.x` → `1.1.0` | reset to `1` |
| Major release | `1.x.x` → `2.0.0` | reset to `1` |
| Resubmission of same version after rejection | unchanged | bump (`+2`, `+3`, …) |

Always commit `pubspec.yaml` with the bumped version before archiving so the
git tag matches what's in the store.
