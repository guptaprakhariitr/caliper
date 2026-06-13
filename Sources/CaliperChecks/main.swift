import Foundation
import AppKit
import SwiftUI
import CoreGraphics
import EdgeEngine
import CaliperUI
import ScreenshotKit

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ✓ \(msg)") } else { print("  ✗ \(msg)"); failures += 1 }
}
func section(_ s: String) { print("\n▸ \(s)") }
func near(_ values: [Int], _ target: Int, _ tol: Int = 3) -> Bool {
    values.contains { abs($0 - target) <= tol }
}

let engine = EdgeEngine()

section("EdgeEngine.detectSnapLines (synthetic 200x120, rect 40..160 × 30..90)")
guard let cg = EdgeEngine.makeSyntheticImage() else {
    print("  ✗ could not build synthetic image"); exit(1)
}
let lines = engine.detectSnapLines(in: cg)
check(near(lines.verticalX, 40), "verticalX contains ~40 (got \(lines.verticalX))")
check(near(lines.verticalX, 160), "verticalX contains ~160")
check(near(lines.horizontalY, 30), "horizontalY contains ~30 (got \(lines.horizontalY))")
check(near(lines.horizontalY, 90), "horizontalY contains ~90")

section("EdgeEngine.nearestSnap")
check(engine.nearestSnap(to: 43, in: [40, 160]) == 40, "nearestSnap(43,[40,160]) == 40")
check(engine.nearestSnap(to: 100, in: [40, 160]) == nil, "nearestSnap(100,[40,160]) == nil")
check(engine.nearestSnap(to: 156, in: [40, 160]) == 160, "nearestSnap(156,[40,160]) == 160")

section("EdgeEngine color helpers")
check(engine.hexString(r: 255, g: 136, b: 0) == "#FF8800", "hexString(255,136,0) == #FF8800")
check(engine.hexString(r: 59, g: 91, b: 255) == "#3B5BFF", "hexString(59,91,255) == #3B5BFF")
let hsl = engine.rgbToHSL(r: 1, g: 0, b: 0)
check(Int(hsl.h.rounded()) == 0 && Int((hsl.s * 100).rounded()) == 100 && Int((hsl.l * 100).rounded()) == 50,
      "rgbToHSL(1,0,0) == (0°,100%,50%)")
let gray = engine.rgbToHSL(r: 0.5, g: 0.5, b: 0.5)
check(gray.s == 0, "rgbToHSL gray has 0 saturation")

section("View model snapping integration")
MainActor.assumeIsolated {
    let vm = CaliperViewModel()
    vm.analyze(cg)
    vm.startX = 43; vm.endX = 156; vm.startY = 33; vm.endY = 87
    vm.snapEndpoints()
    check(near([vm.startX], 40) && near([vm.endX], 160), "endpoints snapped near 40 & 160 (got \(vm.startX),\(vm.endX))")
    check(near([vm.startY], 30) && near([vm.endY], 90), "y endpoints snapped near 30 & 90")
}

// MARK: Render real screenshots off-screen (no screen-recording permission)
section("Screenshots")
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./screenshots")

MainActor.assumeIsolated {
    // 1) The product hero / measuring scene (ImageRenderer-safe).
    let scene = ScreenshotScene(sizeLabel: "240 × 64 px", hex: "#3B5BFF")
    do {
        let url = outDir.appendingPathComponent("01-measuring.png")
        try ViewSnapshotter.renderStoreShot(scene, size: .s1440x900, to: url)
        check(FileManager.default.fileExists(atPath: url.path), "rendered measuring scene → \(url.lastPathComponent)")
    } catch { check(false, "measuring scene render: \(error)") }

    // 2) A marketing shot.
    let marketing = ZStack {
        LinearGradient(colors: [Color(white: 0.10), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
        VStack(spacing: 24) {
            Text("Caliper").font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white)
            Text("Ruler · Loupe · Color picker — with auto edge-snap.")
                .font(.system(size: 26)).foregroundStyle(.white.opacity(0.8))
            ScreenshotScene().scaleEffect(0.9)
        }.padding(60)
    }
    do {
        let url = outDir.appendingPathComponent("02-marketing.png")
        try ViewSnapshotter.renderStoreShot(marketing, size: .s2560x1600, to: url)
        check(FileManager.default.fileExists(atPath: url.path), "rendered marketing shot → \(url.lastPathComponent)")
    } catch { check(false, "marketing render: \(error)") }
}

print("\n" + (failures == 0 ? "✅ ALL CHECKS PASSED" : "❌ \(failures) FAILED"))
exit(failures == 0 ? 0 : 1)
