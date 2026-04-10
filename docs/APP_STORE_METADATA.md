# VisaRadar — App Store Metadata

Preparation document for App Store (iOS) and Google Play (Android) submissions.
All URLs marked `[PLACEHOLDER]` must be replaced with real URLs before submission.

---

## App Identity

| Field | Value |
|---|---|
| **App Name** | VisaRadar |
| **Bundle ID (iOS)** | com.visaradar.visaradar *(set in Xcode → Signing & Capabilities)* |
| **Package Name (Android)** | com.visaradar.visaradar |
| **Version** | 0.1.0 |
| **Build Number** | 1 |
| **Category** | Travel |
| **Age Rating** | 4+ |
| **Platforms** | iOS 16.0+, Android 10 (API 29)+ |

---

## App Store (iOS) — Listing Copy

### App Name
`VisaRadar`

### Subtitle *(30 chars max)*
`Track Stays. Stay Legal.`

### Promotional Text *(170 chars max — updated without review)*
`Know exactly how many Schengen days you've used. Log every border crossing and get ahead of your limits — before they catch up to you.`

### Description *(4000 chars max)*

```
VisaRadar is your personal travel stay tracker for the Schengen zone and beyond.

If you travel frequently in Europe, you know the 90/180-day Schengen rule is easy to mistrack and impossible to ignore. VisaRadar gives you a live, accurate count of your days used — and warns you before you overstay.

WHAT VISARADAR DOES

• Schengen Day Tracker — See exactly how many days you've used in the rolling 90/180-day window. Get a risk indicator (Safe / Warning / Critical) updated in real time.

• Trip Logging — Log every border crossing with country, entry date, and exit date. Mark a trip as ongoing when you're still in the country.

• Auto Border Detection — VisaRadar uses your GPS location to detect when you may have crossed a border and suggests updating your trip log automatically.

• Country Insights — Entry rules, transport tips, currency, connectivity, safety, and local notes for key destinations. More countries added with every update.

• Smart Notifications — Get alerted at 30, 15, 7, 3, and 1 days remaining in your Schengen window. Stay ahead — not scrambling at the last minute.

WHO IT'S FOR

VisaRadar is for travellers who live between countries — digital nomads, frequent flyers, long-stay visitors, and anyone navigating the European Schengen zone. If you've ever had to count days on a spreadsheet, this replaces that.

IMPORTANT NOTES

VisaRadar is a stay-tracking tool. It does not provide legal or immigration advice. Always verify current visa rules with official government sources before travelling. Country data is curated for general guidance and may not reflect real-time rule changes.

PRICING

VisaRadar is a premium app with a 7-day free trial. After the trial, a monthly subscription applies. Cancel any time in your device settings.
```

### Keywords *(100 chars max, comma-separated)*
`schengen,visa tracker,travel days,border crossing,eu travel,stay tracker,90 day rule,passport`

### Support URL
`https://visaradar.app/support` ← [PLACEHOLDER — set up before submission]

### Privacy Policy URL
`https://visaradar.app/privacy` ← [PLACEHOLDER — required for App Store submission]

### Marketing URL *(optional)*
`https://visaradar.app` ← [PLACEHOLDER]

---

## Google Play — Listing Copy

### App Name
`VisaRadar`

### Short Description *(80 chars max)*
`Track your Schengen days and border crossings. Stay legal, stay informed.`

### Full Description *(4000 chars max)*
*(Use same text as App Store description above)*

### Category
`Travel & Local`

### Tags
`travel, visa, schengen, border, days tracker`

---

## Screenshots & Preview

Minimum required screenshots per platform:

| Platform | Minimum | Recommended sizes |
|---|---|---|
| iPhone 6.7" | 3 | 1290 × 2796 |
| iPhone 6.5" | 3 | 1284 × 2778 |
| iPad Pro 12.9" | 3 | 2048 × 2732 |
| Android phone | 4 | 1080 × 1920 or 1440 × 2960 |

**Suggested screenshot content (in order):**
1. Radar screen — Schengen Status card with real-looking data
2. Trips screen — 3-4 trips including one ongoing
3. Border crossing suggestion card on Radar
4. Country info screen (Germany or Greece)
5. Notifications settings screen

**App preview video:** Optional but recommended. 15–30 seconds max.

---

## App Icon

- [ ] iOS icon: 1024×1024 PNG, no alpha, no rounded corners (system rounds it).
  - Path: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  - Current state: Default Flutter icon — **must be replaced before submission**.
- [ ] Android icon: Adaptive icon with foreground + background layers.
  - Path: `android/app/src/main/res/`
  - Current state: Default Flutter icon — **must be replaced before submission**.

**Icon requirements:**
- Must reflect the VisaRadar brand (dark navy + teal radar/compass concept).
- No text in icon for App Store (App Store guidelines).
- Test on both light and dark home screens.

---

## Launch Screen

- [ ] iOS: `ios/Runner/Base.lproj/LaunchScreen.storyboard` — update background color to match brand navy (`#0B1120`) and add app logo.
- [ ] Android: `android/app/src/main/res/drawable/launch_background.xml` — update to brand colors.
- [ ] Test launch screen appears for <1 second on cold start (not a white flash).

---

## Signing & Release Build

### iOS
- [ ] Apple Developer Program membership active.
- [ ] Signing certificate: Distribution (App Store Connect).
- [ ] Provisioning profile: App Store distribution, correct bundle ID.
- [ ] Set in Xcode: Product → Scheme → Archive.
- [ ] App Store Connect: create app record with bundle ID `com.visaradar.visaradar`.

### Android
- [ ] Generate a release keystore:
  ```
  keytool -genkey -v -keystore ~/visaradar-release.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias visaradar
  ```
- [ ] Add keystore config to `android/key.properties` (do NOT commit this file).
- [ ] Update `android/app/build.gradle.kts` to reference `key.properties` for release signing.
- [ ] Add `android/key.properties` to `.gitignore`.
- [ ] Google Play Console: create app, set up internal testing track.

---

## Pre-Submission Checklist

### App Store (iOS)
- [ ] App icon set — all sizes, no transparency
- [ ] Launch screen updated
- [ ] Bundle ID confirmed in Xcode
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) — required for apps using location APIs
- [ ] Data collection questionnaire in App Store Connect filled out
- [ ] Screenshots uploaded for all required sizes
- [ ] Privacy Policy URL live and accessible
- [ ] Support URL live and accessible
- [ ] TestFlight internal testing passed (min. 1 device, 1 tester)

### Google Play
- [ ] Signed release AAB (`flutter build appbundle --release`)
- [ ] App icon (adaptive) updated
- [ ] Launch screen updated
- [ ] Play Console: app description, screenshots, category filled
- [ ] Privacy Policy URL live and accessible
- [ ] Data safety form completed (location, notifications declared)
- [ ] Internal test track approved before production release

---

## Legal & Compliance

| Item | Status |
|---|---|
| Privacy Policy | [PLACEHOLDER — must be published at a public URL] |
| Terms of Service | [PLACEHOLDER — must be published at a public URL] |
| GDPR compliance | All data local-only. No remote storage. Low risk. |
| Location data disclosure | Used for country detection only. Not stored remotely. |
| In-app purchase | Placeholder (StoreKit / Play Billing not yet integrated). Do not submit to stores until billing is real or feature is clearly marked as coming soon. |
| Age rating | 4+ — no violent/adult content. Correct. |

---

## Version History (for release notes)

### 0.1.0 (Build 1) — First release
- Schengen 90/180-day tracker with live risk indicator
- Trip logging with country, entry/exit dates, Schengen status
- GPS-based country detection and border crossing suggestions
- Country info for Germany, Greece, Bulgaria, Italy, Turkey
- Smart Schengen alerts (30/15/7/3/1 days remaining)
- Travel reminders (open trip, crossing review, location inactive)
- 7-day free trial with monthly subscription (payment integration pending)

---

*Last updated: March 2026*
