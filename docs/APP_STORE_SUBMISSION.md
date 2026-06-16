# Pica → Mac App Store: Submission Runbook

This repo is **fully prepared** for the Mac App Store. On a Mac with full Xcode + your Apple Developer signing set up, run the prompt below (or follow the manual steps). The agent does everything up to Apple's human-only gates.

---

## ▶ PROMPT — paste this into Claude Code on your signing machine

> You are releasing the macOS app **Pica** (this repo) to the **Mac App Store**. Everything is pre-built: `project.yml` (XcodeGen), `ExportOptions-appstore.plist`, `fastlane/` (Fastfile + metadata + screenshots), `Resources/` (Info.plist, entitlements, Assets.xcassets app icon, PrivacyInfo.xcprivacy), and `Scripts/release-appstore.sh`. Do the following, pausing to ask me whenever a step needs my Apple account in the browser:
>
> 1. **Check prereqs:** confirm `xcodebuild -version`, `xcodegen --version`, `fastlane --version`, and that I'm signed into Xcode with my Apple Developer team. If `xcodegen`/`fastlane` are missing, `brew install xcodegen fastlane`.
> 2. **Confirm identifiers with me:** my **Team ID** (`DEVELOPMENT_TEAM`), the **bundle id** (default `com.plainware.caliper` — keep it so the Firebase config still matches), and my **App Store Connect API key** (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` to the `.p8`). Export them as env vars.
> 3. **Firebase config (REQUIRED before building):** the build bundles `Resources/GoogleService-Info.plist`, which is **gitignored and not in this repo**. Download it from the **girlfeed-44107** Firebase console → Project settings → Your apps → **Caliper (`com.plainware.caliper`)** → `GoogleService-Info.plist`, and place it at `Resources/GoogleService-Info.plist` **before** running xcodegen (it's listed in `project.yml`, so project generation fails without it). It powers the on-launch version / force-update check (Firestore `apps/caliper`); the app fails open if it's ever missing at runtime. **Never commit it.**
> 4. **App record:** check App Store Connect for an app with my bundle id. If missing, create it (`fastlane produce -u $APPLE_ID -a com.plainware.caliper --skip_itc false --app_name Pica` or via the web UI). Tell me if I still need to accept the **Paid/Free Apps agreement** or **tax & banking** — those are mine to do in the browser.
> 5. **Build:** run `Scripts/release-appstore.sh` (sets up the Xcode project and produces `build/Caliper.pkg`). Fix any signing errors and report them to me.
> 6. **Upload:** `fastlane mac upload` (uploads binary + the metadata in `fastlane/metadata` + screenshots in `fastlane/screenshots`). It will NOT submit for review.
> 7. **Verify in App Store Connect:** tell me the build is processing, and which fields still need my input (pricing/availability, age rating questionnaire, export-compliance answer — Info.plist already declares `ITSAppUsesNonExemptEncryption=false`, App Privacy = "Data Not Collected"). Pica uses **Screen Recording** at runtime; that's fine for the App Store — the `NSScreenCaptureUsageDescription` usage string is already in Info.plist and the permission is requested on first capture.
> 8. **Stop before "Submit for Review"** and hand back to me to click submit, unless I tell you to run `fastlane deliver --submit_for_review`.
>
> Read `~/Library/Containers/com.plainware.caliper/Data/Library/Logs/Plainware/Pica.log` if you need to debug the running app. Don't commit secrets.

---

## Prerequisites (signing machine)
- **Full Xcode** (not just Command Line Tools) + an **Apple Developer Program** membership.
- Tools: `brew install xcodegen fastlane`.
- Signing: Apple Distribution + Mac Installer Distribution certificates (Xcode "Automatically manage signing" with your team handles this), and an **App Store Connect API key** (`.p8` + Key ID + Issuer ID) created in App Store Connect → Users and Access → Integrations.
- **`Resources/GoogleService-Info.plist`** — **REQUIRED** for the build (it's in `project.yml` and powers version-gating). Download from the **girlfeed-44107** Firebase console (the **Caliper** / `com.plainware.caliper` app) and place in `Resources/`. Gitignored — don't commit.

## One-time App Store Connect setup (human-only)
1. Accept the **Apple Developer Program License Agreement** and the **Paid/Free Apps agreement**; complete **tax & banking** (free apps still need the free-apps agreement signed).
2. Create the app record (bundle id `com.plainware.caliper`, name **Pica**, primary language English, category **Developer Tools**). `fastlane produce` can do this, or the web UI.

## Build, upload, submit
```bash
export DEVELOPMENT_TEAM=ABCDE12345         # your 10-char Team ID
export APPLE_ID=you@example.com
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8

Scripts/release-appstore.sh     # → build/Caliper.pkg
fastlane mac upload             # binary + metadata + screenshots (no review submit)
```
Then in App Store Connect: set **pricing & availability** (Free), answer the **age-rating** questionnaire, confirm **App Privacy = Data Not Collected**, attach the build, and click **Submit for Review** (or run `fastlane deliver --submit_for_review`).

## What's already in the repo for you
| File | Purpose |
|---|---|
| `project.yml` | XcodeGen spec → `Caliper.xcodeproj` (App Sandbox, app icon, version 1.0.0) |
| `Resources/Caliper.entitlements` | App Sandbox + user-selected files + outgoing network (version check) |
| `Resources/Info.plist` | category, encryption=false, icon name, Screen Recording usage string |
| `Resources/Assets.xcassets/AppIcon.appiconset` | full macOS icon set (16→1024) |
| `Resources/PrivacyInfo.xcprivacy` | privacy manifest (UserDefaults reason; no data collected) |
| `ExportOptions-appstore.plist` | `app-store` export config |
| `fastlane/Fastfile` | `mac build` / `mac upload` / `mac release` lanes |
| `fastlane/metadata/en-US` | name, subtitle, description, keywords, URLs, notes |
| `fastlane/screenshots/en-US` | 1440×900 + 2560×1600 screenshots (replace with your own anytime) |
| `Scripts/release-appstore.sh` | archive + export → `build/Caliper.pkg` |

## Notes / gotchas
- **Screen Recording**: Pica captures the screen region under the ruler at runtime via ScreenCaptureKit. The App Store allows this; the user grants the permission on first capture and the `NSScreenCaptureUsageDescription` string is already present. No special entitlement is required.
- **Bundle id**: keep `com.plainware.caliper` so the bundled `GoogleService-Info.plist` (project **girlfeed-44107**, the shared suite project) and the Firestore version doc `apps/caliper` match. If you change it, re-register the app in girlfeed-44107 and swap the plist.
- **Version gating**: on launch the app reads Firestore `apps/caliper` (girlfeed-44107) over HTTPS and shows a blocking "update required" screen if the build is below `minBuild` (fails open if offline). Needs the `network.client` entitlement (already set).
- **Version**: bump `MARKETING_VERSION` in `project.yml` (currently 1.0.0) and `CFBundleShortVersionString` for each release.
- **Privacy policy URL**: `fastlane/metadata/en-US/privacy_url.txt` points to a GitHub Pages URL — publish `docs/PRIVACY.md` there (enable Pages) or change it to wherever you host it; App Store requires a reachable privacy URL.
- **Screenshots**: the committed ones are generated by Pica (`swift run CaliperChecks`). Replace them in `fastlane/screenshots/en-US/` with your own (valid macOS sizes: 1280×800, 1440×900, 2560×1600, 2880×1800).
