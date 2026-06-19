# Contributing to PicaMac

Thanks for your interest! PicaMac is an open-source (AGPL-3.0) macOS pixel ruler, loupe and color picker. The whole app — UI, view model, app plumbing and the edge-detection/snapping engine — lives here and builds entirely from source. Contributions are welcome.

## Project layout

```
Sources/Caliper       @main app target
Sources/CaliperUI     SwiftUI overlay/measuring UI (contributions welcome here)
Sources/CaliperChecks CLT-runnable test/screenshot harness
Engines/EdgeEngine    edge detection, snapping, color conversion
Packages/Core         shared modules (vendored)
```

## Dev setup

- macOS 14+, Swift 6 toolchain (Command Line Tools is enough for the dev loop; full Xcode is needed only for App Store archiving).
- Build & run:
  ```bash
  Scripts/bundle.sh --package-dir . --product Caliper --name Caliper \
    --bundle-id com.plainware.caliper --info-plist Resources/Info.plist \
    --entitlements Resources/Caliper.entitlements --icon Resources/AppIcon.icns --open
  ```
- Tests (no XCTest needed): `swift run CaliperChecks ./screenshots` — must print `✅ ALL CHECKS PASSED`.

## Guidelines

- Keep UI changes in `Sources/CaliperUI`. The `ScreenshotScene` must use only `ImageRenderer`-safe primitives (no `HSplitView`/`.toolbar`/`Slider`).
- Add a check to `Sources/CaliperChecks/main.swift` for any new logic (especially edge-detection / snapping behaviour).
- Match the existing style; run a build before opening a PR.
- Never commit secrets — `GoogleService-Info.plist`, `.p8`/`.p12` keys, etc. are gitignored.

## Reporting issues

Open a GitHub issue with macOS version, steps, and (if relevant) the tail of
`~/Library/Containers/com.plainware.caliper/Data/Library/Logs/Plainware/PicaMac.log`.
