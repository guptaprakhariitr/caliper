# Caliper

**On-screen pixel ruler, loupe & color picker — with auto edge-snap.** Caliper draws a precise measurement guide over any UI, magnifies pixels with a loupe, and reads back colors as hex/HSL. Its differentiator is **automatic edge-snap**: a real on-device edge detector finds element boundaries so your measurement endpoints lock to the actual edges, not "close enough." A free, native, open-source replacement for paid pixel rulers and color pickers.

- 📏 Pixel-perfect width × height measurement guide with end-caps and a live badge
- 🧲 Auto edge-snap — Sobel gradient edge detection snaps endpoints to element boundaries
- 🔍 Loupe with zoomed pixel grid + crosshair
- 🎨 Color readout in hex and HSL
- 🔒 100% local — the engine works on provided images; nothing leaves your Mac
- 🆓 Free & open source

## Architecture

Open-source **shell** (`CaliperUI`) + proprietary **engine** (`EdgeEngine`). In the public release the engine ships as a precompiled XCFramework; here it builds from source.

```
Sources/Caliper       executable (@main)        — app entry, menus, settings
Sources/CaliperUI     library (open source)     — overlay UI, view model
Engines/EdgeEngine    library (proprietary)     — edge detection + snapping + color
Packages/Core         shared modules            — design system, remote config, license, updates
```

## EdgeEngine — public API

```swift
struct SnapLines: Sendable { let verticalX: [Int]; let horizontalY: [Int] }

struct EdgeEngine: Sendable {
    func detectSnapLines(in cg: CGImage, threshold: Double = 0.25) -> SnapLines
    func nearestSnap(to value: Int, in candidates: [Int], maxDistance: Int = 12) -> Int?
    func hexString(r: Int, g: Int, b: Int) -> String
    func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double)
    static func makeSyntheticImage(...) -> CGImage?
}
```

`detectSnapLines` converts the image to a grayscale Float buffer, computes a Sobel gradient-magnitude field, accumulates gradient energy per column and per row, normalises, and returns the column / row indices that exceed `threshold` **and** are local maxima — i.e. element edges. `nearestSnap` locks a measurement endpoint to the closest detected edge within `maxDistance`.

## Build & run (no Xcode required)

```bash
swift build
swift run CaliperChecks ./screenshots
```

Bundle a runnable, ad-hoc-signed `.app`:

```bash
Scripts/bundle.sh --package-dir . --product Caliper \
  --name Caliper --bundle-id com.plainware.caliper \
  --info-plist Resources/Info.plist --entitlements Resources/Caliper.entitlements --open
```

## Feature flags

Paid features, in-app updates and force-update are built but **gated OFF** via Remote Config (`RemoteConfigKit`), flipped on later with no app update. `GoogleService-Info.plist` is **not** committed.

## License

Shell: MIT (see `LICENSE`). Engine: proprietary.
