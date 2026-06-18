import SwiftUI
import AppKit
import CoreGraphics
import EdgeEngine
import LogKit

/// Drives the PicaMac overlay: holds the target image being measured, the
/// detected snap lines, the current measurement guide, and the sampled color.
@MainActor
public final class CaliperViewModel: ObservableObject {
    /// The image currently under the ruler (a screen capture, or a sample).
    @Published public var target: NSImage?
    /// Detected element boundaries used for auto edge-snap.
    @Published public var snapLines = SnapLines(verticalX: [], horizontalY: [])
    /// Measurement endpoints, in image pixel space.
    @Published public var startX: Int = 40
    @Published public var endX: Int = 160
    @Published public var startY: Int = 30
    @Published public var endY: Int = 90
    /// Auto edge-snap toggle.
    @Published public var snapEnabled: Bool = true
    /// Display unit for the measurement readout.
    @Published public var unit: MeasureUnit = .px

    /// Units the measurement can be shown in. Conversions assume a 2× Retina
    /// capture (pt = px / 2) and the CSS reference of 96 px per inch.
    public enum MeasureUnit: String, CaseIterable, Identifiable, Sendable {
        case px, pt, cm, `in`
        public var id: String { rawValue }
        public var label: String { self == .in ? "Inches (in)" : self == .cm ? "Centimeters (cm)" : self == .pt ? "Points (pt)" : "Pixels (px)" }
        func string(_ pixels: Int) -> String {
            switch self {
            case .px: return "\(pixels)"
            case .pt: return String(format: "%.0f", Double(pixels) / 2)
            case .cm: return String(format: "%.2f", Double(pixels) / 96.0 * 2.54)
            case .in: return String(format: "%.2f", Double(pixels) / 96.0)
            }
        }
    }
    /// Sampled color readout.
    @Published public var sampledHex: String = "#3B5BFF"
    @Published public var sampledHSL: String = "H 227° S 100% L 61%"

    private let engine = EdgeEngine()

    public init() {}

    /// Width × height of the current measurement guide, in pixels.
    public var measuredWidth: Int { abs(endX - startX) }
    public var measuredHeight: Int { abs(endY - startY) }
    /// The current width/height formatted in the selected unit (number only).
    public func widthString() -> String { unit.string(measuredWidth) }
    public func heightString() -> String { unit.string(measuredHeight) }
    public var measuredLabel: String { "\(widthString()) × \(heightString()) \(unit.rawValue)" }

    /// Set the image to measure and recompute edges.
    public func setTarget(_ image: NSImage) {
        target = image
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            snapLines = engine.detectSnapLines(in: cg)
            AppLog.info("measurement started on \(cg.width)x\(cg.height) target — \(snapLines.verticalX.count) vertical, \(snapLines.horizontalY.count) horizontal snap lines", category: "measure")
        } else {
            AppLog.error("setTarget failed: could not derive CGImage from target", category: "measure")
        }
    }

    /// Recompute snap lines for an explicit CGImage (used in tests / capture).
    public func analyze(_ cg: CGImage, threshold: Double = 0.25) {
        snapLines = engine.detectSnapLines(in: cg, threshold: threshold)
    }

    /// Snap each measurement endpoint to the nearest detected boundary.
    /// `maxDistance` bounds how far an endpoint may jump — small for the gentle
    /// auto-snap while dragging, very large for an explicit "Snap now" so the
    /// button always pulls endpoints to the nearest real edge.
    public func snapEndpoints(maxDistance: Int = 12) {
        guard snapEnabled else { return }
        if let s = engine.nearestSnap(to: startX, in: snapLines.verticalX, maxDistance: maxDistance), s != startX {
            AppLog.info("snapped \(startX)→\(s)", category: "snap"); startX = s
        }
        if let e = engine.nearestSnap(to: endX, in: snapLines.verticalX, maxDistance: maxDistance), e != endX {
            AppLog.info("snapped \(endX)→\(e)", category: "snap"); endX = e
        }
        if let s = engine.nearestSnap(to: startY, in: snapLines.horizontalY, maxDistance: maxDistance), s != startY {
            AppLog.info("snapped \(startY)→\(s)", category: "snap"); startY = s
        }
        if let e = engine.nearestSnap(to: endY, in: snapLines.horizontalY, maxDistance: maxDistance), e != endY {
            AppLog.info("snapped \(endY)→\(e)", category: "snap"); endY = e
        }
    }

    /// Sample the color at an image pixel and update the readout chips.
    public func sampleColor(atX x: Int, y: Int) {
        guard let target,
              let cg = target.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let (px, w, h) = colorAt(cg: cg, x: x, y: y) else {
            AppLog.error("color sample failed at (\(x), \(y))", category: "color")
            return
        }
        let _ = (w, h)
        let r = Int((px.0 * 255).rounded()), g = Int((px.1 * 255).rounded()), b = Int((px.2 * 255).rounded())
        sampledHex = engine.hexString(r: r, g: g, b: b)
        let hsl = engine.rgbToHSL(r: px.0, g: px.1, b: px.2)
        sampledHSL = "H \(Int(hsl.h.rounded()))° S \(Int((hsl.s * 100).rounded()))% L \(Int((hsl.l * 100).rounded()))%"
        AppLog.info("picked color \(sampledHex) at (\(x), \(y))", category: "color")
    }

    private func colorAt(cg: CGImage, x: Int, y: Int) -> ((Double, Double, Double), Int, Int)? {
        let w = cg.width, h = cg.height
        guard x >= 0, x < w, y >= 0, y < h else { return nil }
        let bytesPerRow = w * 4
        var raw = [UInt8](repeating: 0, count: bytesPerRow * h)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &raw, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let i = y * bytesPerRow + x * 4
        return ((Double(raw[i]) / 255, Double(raw[i + 1]) / 255, Double(raw[i + 2]) / 255), w, h)
    }
}
