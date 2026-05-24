# TestFlight Ready — VisaRadar

Goal: get a signed `.ipa` of VisaRadar onto TestFlight for internal/external testing
before the public App Store push.

## Build identity (verified, last run 2026-05-24)

| Field | Value |
|---|---|
| Bundle ID | `com.visaradar.visaradar` |
| Display name | `VisaRadar` |
| Marketing version | `1.0.0` (from `pubspec.yaml` `version:`) |
| Build number | `1` |
| iOS deployment target | 13.0 |
| Development team | `V8CC8CQG3W` |
| Code sign style | Automatic |
| Orientation | Portrait only |
| Privacy strings | `NSLocationWhenInUseUsageDescription` only |
| App icons | Full set in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Launch screen | Default Flutter `LaunchImage` (acceptable for v1, polish opportunity) |

Bump rules:
- Every TestFlight upload needs a unique build number.
- After the first upload, bump `version: 1.0.0+2` → `1.0.0+3` → … in `pubspec.yaml`.
- Marketing version (`1.0.0`) stays the same until you ship a real public update.

## Prerequisites

1. Apple Developer Program account active for team `V8CC8CQG3W`.
2. App record exists in App Store Connect with bundle id `com.visaradar.visaradar`.
   - If not: App Store Connect → My Apps → `+` → New App → fill name, bundle, SKU, primary language.
3. Xcode logged in with the dev account (`Xcode → Settings → Accounts`).
4. macOS, Xcode, and CocoaPods up to date enough for Flutter 3.41.5.
5. Repo on a clean tree (`git status` shows no unintended diffs).

## Local build sanity check

Always run these three before opening Xcode:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build ios --release --no-codesign
```

All four must finish with no errors. The build output should end with
`✓ Built build/ios/iphoneos/Runner.app`.

## Open the workspace in Xcode

```bash
open ios/Runner.xcworkspace
```

> ⚠️ Always open `Runner.xcworkspace`, never `Runner.xcodeproj`. CocoaPods
> integration only works through the workspace.

## Configure signing (once per machine)

1. Select the `Runner` project in the left navigator.
2. Select the `Runner` target.
3. `Signing & Capabilities` tab.
4. For `Debug`, `Release`, and `Profile` configurations:
   - ✅ `Automatically manage signing`
   - Team: select the team that owns `V8CC8CQG3W`.
   - Bundle Identifier: `com.visaradar.visaradar` (read-only confirm).
5. If Xcode prompts to create / download a provisioning profile, accept.

Verify there are **no red error rows** in `Signing & Capabilities` before continuing.

## Archive build (App Store distribution)

1. In Xcode top bar, set the destination to **`Any iOS Device (arm64)`**
   (not a simulator — archives only build for real devices).
2. Menu: `Product → Archive`.
3. Wait for the build. On success the **Organizer** window opens with the new archive.
4. If Organizer doesn't open: `Window → Organizer → Archives` tab.

If archive fails:
- `Product → Clean Build Folder` (`⇧⌘K`), then retry.
- If a CocoaPods symbol error appears: in a terminal,
  `cd ios && pod deintegrate && pod install`, reopen workspace, retry.

## Upload to App Store Connect (TestFlight)

From the Organizer with the archive selected:

1. Click **`Distribute App`**.
2. Method: **`App Store Connect`** → Next.
3. Destination: **`Upload`** → Next.
4. Distribution options: leave defaults checked (`Upload your app's symbols`,
   `Manage Version and Build Number` off — let pubspec drive it) → Next.
5. Signing: **`Automatically manage signing`** → Next.
6. Review summary → **`Upload`**.
7. Wait for "App Store Connect upload successful" (~3–10 min).

After upload:
- App Store Connect → TestFlight → wait for processing (5–30 min usually,
  occasionally longer).
- Once processed, fill **Test Information** (required for external testing):
  - Beta App Description.
  - Email & contact info.
  - Privacy policy URL (or a generic placeholder if not live yet — internal
    testing doesn't strictly require it, external testing does).
- Add testers: Internal (your team via App Store Connect users) or
  External (email list, requires Apple beta review pass).

## Smoke test on TestFlight build

Install via TestFlight app on a real device and verify:

- App launches without "infinite loading" or crash.
- Onboarding 7 steps complete and you land on the Radar screen.
- Add a trip → it appears in Trips tab.
- Open Country Info → see at least the empty-state CTA when no active trip.
- Settings → Privacy Policy / Terms / About all open without crashing.
- Notifications: trigger the `kDebugMode` test from notification settings
  (only visible in debug builds — skip on release).
- Force-quit and reopen — profile and trips persist.

## TestFlight-specific rejection / processing risks

- **Missing export compliance**: ITSAppUsesNonExemptEncryption not set →
  Apple asks every upload. Already covered in `ios/Runner/Info.plist` if added;
  if Apple asks on first upload, answer "No" (we use only standard HTTPS).
- **Processing stuck > 24h**: usually a backend issue at Apple, not us. Wait
  before re-uploading.
- **Invalid binary**: usually wrong deployment target or missing capability.
  Read the email Apple sends — it almost always names the exact key.
- **Build number reuse**: if you upload `+1` twice, the second is rejected
  silently — bump the build number every time.

## After a successful TestFlight build

When you decide the build is App Store-worthy:

1. In App Store Connect → `App Store` tab → create a new version `1.0.0`
   (or whichever marketing version is live).
2. Attach the TestFlight build to that version.
3. Continue with `APP_STORE_SUBMISSION.md`.
