import Foundation
import AppKit
import SwiftUI
import CoreGraphics
import EdgeEngine
import CaliperUI
import ScreenshotKit

let picaAccent = Color(red: 0.231, green: 0.357, blue: 1.0)

/// PicaMac product visual — the real overlay reproduced for store shots: a design
/// canvas with a sample app being measured (dimension guide + badge), dashed
/// auto-snap edge lines, a pixel loupe and a hex/HSL color readout. Fills width
/// `w`; all metrics scale off it. ImageRenderer-safe (shapes/Text only).
struct PicaCanvas: View {
    var w: CGFloat
    var highlight: Highlight = .all
    enum Highlight { case all, snap, color }
    private func s(_ v: CGFloat) -> CGFloat { v * w / 1120 }

    var body: some View {
        ZStack {
            Color(white: 0.13)
            // the design being measured
            sampleApp
                .frame(width: s(560), height: s(360))
                .position(x: s(380), y: s(330))

            // auto-snap dashed edge lines on the sample's left/right edges
            if highlight != .color {
                ForEach([s(100), s(660)], id: \.self) { x in
                    Path { p in p.move(to: CGPoint(x: x, y: s(120))); p.addLine(to: CGPoint(x: x, y: s(540))) }
                        .stroke(picaAccent, style: StrokeStyle(lineWidth: s(2), dash: [s(7), s(5)]))
                }
            }
            // horizontal dimension guide + badge
            dimensionGuide.position(x: s(380), y: s(132))
            // pixel loupe + color chip cluster (right)
            VStack(spacing: s(16)) {
                loupe
                colorChip
            }
            .position(x: s(940), y: s(300))
        }
        .frame(width: w, height: w * 600 / 1120)
        .clipped()
    }

    private var sampleApp: some View {
        VStack(alignment: .leading, spacing: s(14)) {
            RoundedRectangle(cornerRadius: s(6)).fill(picaAccent).frame(width: s(180), height: s(22))
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: s(5)).fill(Color(white: 0.82))
                    .frame(width: [s(420), s(330), s(390), s(300)][i], height: s(13))
            }
            Spacer().frame(height: s(6))
            RoundedRectangle(cornerRadius: s(12)).fill(picaAccent).frame(width: s(220), height: s(60))
        }
        .padding(s(22))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: s(14)).fill(.white))
    }

    private var dimensionGuide: some View {
        VStack(spacing: s(8)) {
            Text("560 × 360 px")
                .font(.system(size: s(17), weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, s(12)).padding(.vertical, s(6))
                .background(Capsule().fill(picaAccent))
            ZStack {
                Rectangle().fill(picaAccent).frame(width: s(560), height: s(2))
                HStack { Rectangle().fill(picaAccent).frame(width: s(2), height: s(16)); Spacer(); Rectangle().fill(picaAccent).frame(width: s(2), height: s(16)) }
                    .frame(width: s(560))
            }
        }
    }

    private var loupe: some View {
        ZStack {
            Circle().fill(.white).frame(width: s(120), height: s(120))
                .overlay(Circle().strokeBorder(picaAccent, lineWidth: s(4)))
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { c in
                            Rectangle().fill((r + c) == 5 ? picaAccent : picaAccent.opacity(0.45 + Double((r * 6 + c) % 4) * 0.13))
                                .frame(width: s(17), height: s(17))
                        }
                    }
                }
            }.clipShape(Circle())
            Rectangle().fill(.white).frame(width: s(18), height: s(2))
            Rectangle().fill(.white).frame(width: s(2), height: s(18))
        }
        .overlay(alignment: .bottom) {
            if highlight == .color {
                Circle().strokeBorder(picaAccent, lineWidth: s(3)).frame(width: s(132), height: s(132))
            }
        }
    }

    private var colorChip: some View {
        HStack(spacing: s(10)) {
            RoundedRectangle(cornerRadius: s(5)).fill(picaAccent).frame(width: s(26), height: s(26))
            Text("#3B5BFF").font(.system(size: s(17), weight: .medium, design: .monospaced)).foregroundStyle(.white)
        }
        .padding(.horizontal, s(14)).padding(.vertical, s(9))
        .background(Capsule().fill(Color(white: 0.08)))
    }
}

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

// MARK: Render App Store screenshots off-screen (no screen-recording permission)
section("Screenshots")
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./screenshots")
let theme = StoreTheme.dark(picaAccent)
let shotSize = ViewSnapshotter.StoreSize.s2560x1600.pixels
let cw = shotSize.width / 1440 * 1120   // content width inside the window frame

MainActor.assumeIsolated {
    @MainActor func shot<V: View>(_ name: String, _ view: V) {
        do {
            let url = outDir.appendingPathComponent(name)
            try ViewSnapshotter.renderPNG(view, size: shotSize, scale: 1.0, to: url)
            check(FileManager.default.fileExists(atPath: url.path), "rendered \(name)")
        } catch { check(false, "\(name): \(error)") }
    }
    shot("01-hero.png", FeatureShot(
        theme: theme, tag: "Plainware",
        headline: "Measure any pixel.\nSnap to real edges.",
        subhead: "A precise on-screen ruler that locks onto real UI edges — with a pixel loupe and a hex / HSL color picker.",
        windowTitle: "PicaMac", size: shotSize) { PicaCanvas(w: cw, highlight: .all) })
    shot("02-snap.png", FeatureShot(
        theme: theme,
        headline: "Locks onto true edges",
        subhead: "Drag near any element and the guide snaps to its exact pixel boundary — no more eyeballing.",
        windowTitle: "PicaMac", size: shotSize) { PicaCanvas(w: cw, highlight: .snap) })
    shot("03-color.png", FeatureShot(
        theme: theme,
        headline: "Loupe + color picker",
        subhead: "Zoom into pixels and read the exact hex / HSL value anywhere on screen.",
        windowTitle: "PicaMac", size: shotSize) { PicaCanvas(w: cw, highlight: .color) })
}

print("\n" + (failures == 0 ? "✅ ALL CHECKS PASSED" : "❌ \(failures) FAILED"))
exit(failures == 0 ? 0 : 1)
