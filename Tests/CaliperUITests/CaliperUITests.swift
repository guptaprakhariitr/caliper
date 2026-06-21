import XCTest
import AppKit
import CoreGraphics
@testable import CaliperUI
@testable import EdgeEngine

/// Full button-/control-flow tests for PicaMac. Every interactive control in the
/// UI maps to a `CaliperViewModel` method or published property; each test sets
/// the expected input, invokes the exact handler the control calls, and asserts
/// the exact output/effect.
@MainActor
final class CaliperUITests: XCTestCase {

    // Synthetic target with edges at x=40/160, y=30/90 (matches CaliperChecks).
    private func loadedVM() -> CaliperViewModel {
        let vm = CaliperViewModel()
        let cg = EdgeEngine.makeSyntheticImage()!
        vm.analyze(cg)
        return vm
    }

    // MARK: Measurement math (Width/Height rows + readout pill)

    func testMeasuredWidthHeight() {
        let vm = CaliperViewModel()
        vm.startX = 40; vm.endX = 160; vm.startY = 30; vm.endY = 90
        XCTAssertEqual(vm.measuredWidth, 120)
        XCTAssertEqual(vm.measuredHeight, 60)
    }

    func testMeasuredWidthIsAbsolute() {
        // Endpoints reversed: width/height must stay positive.
        let vm = CaliperViewModel()
        vm.startX = 160; vm.endX = 40; vm.startY = 90; vm.endY = 30
        XCTAssertEqual(vm.measuredWidth, 120)
        XCTAssertEqual(vm.measuredHeight, 60)
    }

    // MARK: Unit picker (px / pt / cm / in)

    func testUnitPickerFormatsEachUnit() {
        let vm = CaliperViewModel()
        vm.startX = 0; vm.endX = 192; vm.startY = 0; vm.endY = 96 // w=192, h=96

        vm.unit = .px
        XCTAssertEqual(vm.widthString(), "192")
        XCTAssertEqual(vm.heightString(), "96")

        vm.unit = .pt // px / 2
        XCTAssertEqual(vm.widthString(), "96")
        XCTAssertEqual(vm.heightString(), "48")

        vm.unit = .in // px / 96
        XCTAssertEqual(vm.widthString(), "2.00")
        XCTAssertEqual(vm.heightString(), "1.00")

        vm.unit = .cm // px / 96 * 2.54
        XCTAssertEqual(vm.widthString(), "5.08")
        XCTAssertEqual(vm.heightString(), "2.54")
    }

    func testMeasuredLabelReflectsUnit() {
        let vm = CaliperViewModel()
        vm.startX = 0; vm.endX = 120; vm.startY = 0; vm.endY = 60
        vm.unit = .px
        XCTAssertEqual(vm.measuredLabel, "120 × 60 px")
        vm.unit = .pt
        XCTAssertEqual(vm.measuredLabel, "60 × 30 pt")
    }

    func testUnitLabels() {
        XCTAssertEqual(CaliperViewModel.MeasureUnit.px.label, "Pixels (px)")
        XCTAssertEqual(CaliperViewModel.MeasureUnit.pt.label, "Points (pt)")
        XCTAssertEqual(CaliperViewModel.MeasureUnit.cm.label, "Centimeters (cm)")
        XCTAssertEqual(CaliperViewModel.MeasureUnit.in.label, "Inches (in)")
        XCTAssertEqual(CaliperViewModel.MeasureUnit.allCases.count, 4)
    }

    // MARK: Copy button (toolbar) — exact pasteboard string

    func testCopyStringMatchesLabel() {
        let vm = CaliperViewModel()
        vm.startX = 0; vm.endX = 200; vm.startY = 0; vm.endY = 100
        vm.unit = .px
        XCTAssertEqual(vm.copyString(), "200 × 100 px")
        XCTAssertEqual(vm.copyString(), vm.measuredLabel)
    }

    // MARK: Snap toggle + "Snap now" / ⌘K / wand button

    func testSnapNowPullsEndpointsToEdges() {
        let vm = loadedVM()
        vm.snapEnabled = true
        // Synthetic rect 40..160 × 30..90. The gradient detector reports a small
        // cluster of columns/rows around each true boundary, so the contract is:
        // after "Snap now" each endpoint sits exactly ON a detected edge and within
        // a couple px of the true boundary near where it started.
        vm.startX = 43; vm.endX = 156; vm.startY = 33; vm.endY = 87
        // "Snap now" and the wand button call snapEndpoints(maxDistance: 100_000).
        vm.snapEndpoints(maxDistance: 100_000)
        XCTAssertTrue(vm.snapLines.verticalX.contains(vm.startX), "startX snapped to a real edge")
        XCTAssertTrue(vm.snapLines.verticalX.contains(vm.endX), "endX snapped to a real edge")
        XCTAssertTrue(vm.snapLines.horizontalY.contains(vm.startY), "startY snapped to a real edge")
        XCTAssertTrue(vm.snapLines.horizontalY.contains(vm.endY), "endY snapped to a real edge")
        XCTAssertLessThanOrEqual(abs(vm.startX - 40), 2, "left near 40 (got \(vm.startX))")
        XCTAssertLessThanOrEqual(abs(vm.endX - 160), 2, "right near 160 (got \(vm.endX))")
        XCTAssertLessThanOrEqual(abs(vm.startY - 30), 2, "top near 30 (got \(vm.startY))")
        XCTAssertLessThanOrEqual(abs(vm.endY - 90), 2, "bottom near 90 (got \(vm.endY))")
    }

    func testSnapDisabledIsNoOp() {
        let vm = loadedVM()
        vm.snapEnabled = false
        vm.startX = 43; vm.endX = 156; vm.startY = 33; vm.endY = 87
        vm.snapEndpoints(maxDistance: 100_000)
        // Toggle OFF → endpoints must not move.
        XCTAssertEqual(vm.startX, 43)
        XCTAssertEqual(vm.endX, 156)
        XCTAssertEqual(vm.startY, 33)
        XCTAssertEqual(vm.endY, 87)
    }

    func testGentleSnapRespectsMaxDistance() {
        let vm = loadedVM()
        vm.snapEnabled = true
        // 100 is >12px from any edge (40/~160) — gentle drag-snap must not move it.
        vm.startX = 100; vm.endX = 156; vm.startY = 33; vm.endY = 87
        vm.snapEndpoints() // default maxDistance: 12 (the on-drag auto-snap)
        XCTAssertEqual(vm.startX, 100, "endpoint beyond tolerance must stay put")
        XCTAssertTrue(vm.snapLines.verticalX.contains(vm.endX), "nearby endpoint snapped to a real edge")
        XCTAssertLessThanOrEqual(abs(vm.endX - 160), 2, "endX snapped near 160 (got \(vm.endX))")
    }

    // MARK: Color readout chip (hex + HSL)

    func testColorSampleProducesExactHexAndHSL() {
        let vm = CaliperViewModel()
        // 2x2 solid red image; sampling any pixel must read pure red.
        vm.setTarget(NSImageFactory.solid(r: 255, g: 0, b: 0))
        vm.sampleColor(atX: 0, y: 0)
        XCTAssertEqual(vm.sampledHex, "#FF0000")
        XCTAssertEqual(vm.sampledHSL, "H 0° S 100% L 50%")
    }

    func testColorSampleAccentBlue() {
        let vm = CaliperViewModel()
        vm.setTarget(NSImageFactory.solid(r: 59, g: 91, b: 255))
        vm.sampleColor(atX: 1, y: 1)
        XCTAssertEqual(vm.sampledHex, "#3B5BFF")
    }

    func testColorSampleOutOfBoundsKeepsPrevious() {
        let vm = CaliperViewModel()
        vm.setTarget(NSImageFactory.solid(r: 255, g: 0, b: 0))
        vm.sampleColor(atX: 0, y: 0)
        let before = vm.sampledHex
        vm.sampleColor(atX: 9999, y: 9999) // out of range → no change, no crash
        XCTAssertEqual(vm.sampledHex, before)
    }

    // MARK: Load Sample / Open (⌘N / ⌘O) → setTarget recomputes snap lines

    func testSetTargetPopulatesSnapLines() {
        let vm = CaliperViewModel()
        XCTAssertTrue(vm.snapLines.verticalX.isEmpty)
        vm.setTarget(SampleImage.make(width: 1200, height: 760))
        XCTAssertNotNil(vm.target)
        XCTAssertFalse(vm.snapLines.verticalX.isEmpty, "loading a target must detect edges")
        XCTAssertFalse(vm.snapLines.horizontalY.isEmpty)
    }
}

/// Tiny solid-color NSImage builder for color-sampling tests.
private enum NSImageFactory {
    static func solid(r: Int, g: Int, b: Int, size: Int = 2) -> NSImage {
        let bytesPerRow = size * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: bytesPerRow, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let cg = ctx.makeImage()!
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }
}
