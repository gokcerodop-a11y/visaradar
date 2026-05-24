# TestFlight QA — VisaRadar

Pre-flight checklist for **every TestFlight build** of VisaRadar before it goes
out to internal testers (and certainly before external review). Pair this doc
with `REAL_DEVICE_TEST.md` (raw iPhone install) and `QA_CHECKLIST.md`
(functional feature pass). This document focuses on **what's specific to
TestFlight**: the build/upload path, the in-app diagnostics screen, and the
sanity gates that decide whether a build is shipped or pulled.

---

## When to run this checklist

| Trigger | Run full pass? |
|---|---|
| First-ever TestFlight upload of a marketing version (e.g. v1.0.0+1) | **Yes** |
| Bump build number only (v1.0.0+1 → v1.0.0+2) for a small fix | Run §3 + §5 |
| Marketing version bump (v1.0.0 → v1.1.0) | **Yes** |
| Same build, retried after Apple processing failure | §3 only |

---

## 1. Pre-upload sanity

Stop before opening Xcode if any of these fail.

- [ ] `git status` is clean — committed tree only
- [ ] Latest commit is on `main` (or whichever branch is shipping)
- [ ] Build number in `pubspec.yaml` is **higher than the last upload**
- [ ] `flutter clean && flutter pub get && flutter analyze` is `No issues found!`
- [ ] `flutter build ios --release --no-codesign` succeeds locally
- [ ] No new dependency added without a reviewed pubspec change
- [ ] No new permission keys added without a written justification

## 2. Archive + upload

Follow `TESTFLIGHT_READY.md` §6–§7 verbatim. The recurring failure modes:

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to create provisioning profile` | Team not selected or expired account | Xcode → Signing → reselect team |
| `Code signing is required for product type 'Application'` | Archive built without signing | Run `Product → Archive` again (not `Build`) |
| `App Store Connect upload failed: Invalid bundle` | Bundle ID typo or Apple ID lacks rights | Check `com.visaradar.visaradar` in App Store Connect → My Apps |
| `Build number already exists` | You didn't bump `+N` | Bump `pubspec.yaml`, archive again |
| Processing stuck >24h in App Store Connect | Apple-side queue | Wait — do not re-upload |
| `Missing Push Notification Entitlement` warning | Spurious if no push capability | Ignore — VisaRadar uses local notifications only |

## 3. Post-processing in App Store Connect

Once the build moves from `Processing` to `Ready to Test`:

- [ ] Build number in App Store Connect matches `pubspec.yaml` exactly
- [ ] iOS build (no macOS, watch, or other variant slipped in)
- [ ] Architecture is **arm64** (Apple Silicon only — no `armv7`)
- [ ] Size after thinning is < 50 MB (we ship ~20 MB unthinned)
- [ ] Encryption export compliance shows **Compliant** with no questionnaire
      shown (we set `ITSAppUsesNonExemptEncryption = false` in Info.plist)
- [ ] Privacy declarations from `APP_STORE_SUBMISSION.md` §2 are still
      attached and match the running code

## 4. Internal tester roll-out

- [ ] Internal testers group exists in App Store Connect → TestFlight
- [ ] The new build is enabled for that group
- [ ] An invite email or TestFlight push has actually landed for **at least
      two testers** — confirm one tester replies
- [ ] First tester install succeeds without "Couldn't install" errors

## 5. On-device QA pass (per tester, per build)

Each tester runs through this on a real iPhone:

### Boot

- [ ] Install via TestFlight → opens to **Welcome / Onboarding** on first
      launch (or last screen on reinstall)
- [ ] App icon and name are correct on the home screen (`VisaRadar`)
- [ ] No "Untrusted Developer" warning on launch

### Diagnostics — the canonical truth source

Open **Settings → Diagnostics** and screenshot it. The screenshot **must show**:

| Row | Required value |
|---|---|
| Version | matches the build under test (e.g. `1.0.0`) |
| Build mode | **`Release`** (never `Debug` or `Profile` in TestFlight) |
| Bundle ID | `com.visaradar.visaradar` |
| Platform | `iOS` |
| Location | one of: `When in use`, `Denied`, `Denied permanently`, `Not asked yet` |
| Notifications | `Allowed` or `Not allowed` — never `Unknown` after a refresh |
| Connectivity | `Wi-Fi`, `Mobile`, or `Offline` — never `Checking…` |
| Detected country | an ISO code + name, or `—` if not granted |
| Release readiness — all 5 rows | green check marks |

Any red row → reject the build, file an issue with the screenshot, do not
ship to external testing.

### Functional smoke (TestFlight-specific)

- [ ] Complete onboarding end-to-end (use `QA_CHECKLIST.md` §1 for the
      detailed steps)
- [ ] Add a trip with a Schengen country, confirm it appears on Radar
- [ ] Background the app, foreground it after 5 minutes — state preserved
- [ ] Toggle a notification setting and force-quit — preference persists
- [ ] Settings → Privacy Policy / Terms of Service / About all open without
      crash (legal screens are static; if these crash, something deeper
      broke)

### App Store review-risk mirror

These items mirror the risks listed in `APP_STORE_SUBMISSION.md` §5.
Confirm each on the actual TestFlight build:

- [ ] Location prompt text does **not** mention background usage
- [ ] No "Start Free Trial" / paywall / pricing visible anywhere in the app
- [ ] No "DEBUG" or "TEST" labels visible in any tab
- [ ] No `kDebugMode` Developer tools section in Notification Settings
- [ ] No purple debug panel on Radar

If anything in this section fails, the build cannot proceed to external
TestFlight or App Store — file the issue, bump the build number, re-upload.

## 6. Crash / feedback monitoring

For the 24 hours after the build is enabled to internal testers:

- [ ] App Store Connect → TestFlight → **Crashes** tab — must remain at zero
      crashes from internal testers
- [ ] App Store Connect → TestFlight → **Feedback** tab — read every
      submitted note and screenshot
- [ ] If any tester says the app didn't launch or got stuck, ask them for
      a **Diagnostics screen screenshot** — that is the single fastest
      reproducer signal

If 1 internal tester out of <5 reports a crash, treat it as build-blocking.

## 7. Promote to external testing

Only after every internal tester has passed §5 and crash count is zero:

1. App Store Connect → TestFlight → External Groups → add this build
2. Submit for Apple Beta App Review (separate review queue from App Store —
   usually faster, ~24 h)
3. While waiting, finalize the **Beta Test Information**:
   - Email + contact info
   - What to test (one paragraph naming the new flow)
   - Privacy policy URL (mandatory for external testing)

When approved, the same build is auto-distributed to external groups. No
new upload required.

## 8. Pulling a bad build

If a critical bug surfaces:

- App Store Connect → TestFlight → tap the affected build → **Stop Testing**
- Upload the fixed build with a bumped `+N`
- Notify testers via TestFlight push or email — TestFlight does not
  automatically reinstall older builds

---

## Quick handoff to the next QA pass

When this build is signed off, write one paragraph in the build's TestFlight
**What to Test** field summarizing:

- Marketing version + build number
- What changed since the last build
- Anything testers should focus on
- Known issues you accept for this iteration

That paragraph is the only context external testers will read — treat it as
release notes.
