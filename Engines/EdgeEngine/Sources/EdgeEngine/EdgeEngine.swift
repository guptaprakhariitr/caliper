import CoreGraphics
import Foundation

// MARK: - Public model

/// The detected element boundaries in an image: the column indices (x) and row
/// indices (y) whose gradient energy marks an edge. Measurement endpoints snap
/// to these for pixel-perfect alignment.
public struct SnapLines: Sendable {
    public let verticalX: [Int]
    public let horizontalY: [Int]
    public init(verticalX: [Int], horizontalY: [Int]) {
        self.verticalX = verticalX
        self.horizontalY = horizontalY
    }
}

// MARK: - Engine

/// Real on-device edge detection + measurement snapping. Operates on a
/// `CGImage`; everything here is pure CoreGraphics + math (no screen capture),
/// so it runs off-screen and in the check harness with no permissions.
public struct EdgeEngine: Sendable {
    public init() {}

    // MARK: Grayscale conversion

    /// Convert an arbitrary `CGImage` into a row-major Float luminance buffer in
    /// 0…1, drawn into a known 8-bit RGBA context so we control the layout.
    static func grayscaleBuffer(from cg: CGImage) -> (pixels: [Float], width: Int, height: Int)? {
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        let bytesPerRow = w * 4
        var raw = [UInt8](repeating: 0, count: bytesPerRow * h)
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &raw, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: cs, bitmapInfo: bitmap) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var pixels = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * bytesPerRow + x * 4
                let r = Float(raw[i]), g = Float(raw[i + 1]), b = Float(raw[i + 2])
                // Rec. 601 luma, normalised to 0…1.
                pixels[y * w + x] = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            }
        }
        return (pixels, w, h)
    }

    // MARK: Edge detection

    /// Compute a Sobel gradient-magnitude field, accumulate gradient energy per
    /// column and per row, normalise, then return the column / row indices whose
    /// energy exceeds `threshold` AND is a local maximum — i.e. element edges.
    public func detectSnapLines(in cg: CGImage, threshold: Double = 0.25) -> SnapLines {
        guard let (px, w, h) = Self.grayscaleBuffer(from: cg), w >= 3, h >= 3 else {
            return SnapLines(verticalX: [], horizontalY: [])
        }

        @inline(__always) func at(_ x: Int, _ y: Int) -> Float { px[y * w + x] }

        var colEnergy = [Double](repeating: 0, count: w)
        var rowEnergy = [Double](repeating: 0, count: h)

        // Sobel over the interior; sum |∂x| into columns and |∂y| into rows so a
        // crisp vertical edge lights up one column and a horizontal edge one row.
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let tl = at(x - 1, y - 1), tc = at(x, y - 1), tr = at(x + 1, y - 1)
                let ml = at(x - 1, y),                        mr = at(x + 1, y)
                let bl = at(x - 1, y + 1), bc = at(x, y + 1), br = at(x + 1, y + 1)
                let gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl)
                let gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr)
                colEnergy[x] += Double(abs(gx))
                rowEnergy[y] += Double(abs(gy))
            }
        }

        return SnapLines(
            verticalX: Self.peaks(in: colEnergy, threshold: threshold),
            horizontalY: Self.peaks(in: rowEnergy, threshold: threshold))
    }

    /// Normalise an energy profile to its max, then return indices that clear
    /// `threshold` and are >= their immediate neighbours (local maxima).
    static func peaks(in energy: [Double], threshold: Double) -> [Int] {
        guard let maxE = energy.max(), maxE > 0 else { return [] }
        let norm = energy.map { $0 / maxE }
        var out: [Int] = []
        for i in norm.indices {
            guard norm[i] >= threshold else { continue }
            let left = i > 0 ? norm[i - 1] : -1
            let right = i < norm.count - 1 ? norm[i + 1] : -1
            if norm[i] >= left && norm[i] >= right { out.append(i) }
        }
        return out
    }

    // MARK: Snapping

    /// Snap a measurement endpoint `value` to the closest detected boundary in
    /// `candidates`, but only if within `maxDistance` pixels — otherwise `nil`.
    public func nearestSnap(to value: Int, in candidates: [Int], maxDistance: Int = 12) -> Int? {
        var best: Int?
        var bestDist = Int.max
        for c in candidates {
            let d = abs(c - value)
            if d < bestDist { bestDist = d; best = c }
        }
        guard let best, bestDist <= maxDistance else { return nil }
        return best
    }

    // MARK: Color helpers

    /// Uppercased `#RRGGBB` hex from 0…255 channels (clamped).
    public func hexString(r: Int, g: Int, b: Int) -> String {
        func clamp(_ v: Int) -> Int { Swift.max(0, Swift.min(255, v)) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }

    /// Convert sRGB (each 0…1) to HSL — hue in degrees 0…360, s & l in 0…1.
    public func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxV = max(r, max(g, b))
        let minV = min(r, min(g, b))
        let l = (maxV + minV) / 2
        let delta = maxV - minV
        if delta == 0 { return (0, 0, l) }
        let s = l > 0.5 ? delta / (2 - maxV - minV) : delta / (maxV + minV)
        var h: Double
        if maxV == r {
            h = (g - b) / delta + (g < b ? 6 : 0)
        } else if maxV == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h *= 60
        return (h, s, l)
    }
}

// MARK: - Synthetic image helper (used by checks & previews)

public extension EdgeEngine {
    /// Build a synthetic test image: a white canvas with a single filled
    /// rectangle. Edges of the rectangle become the boundaries `detectSnapLines`
    /// must find. Pure CoreGraphics bitmap context — no AppKit, no screen.
    static func makeSyntheticImage(
        width: Int = 200, height: Int = 120,
        rectMinX: Int = 40, rectMaxX: Int = 160,
        rectMinY: Int = 30, rectMaxY: Int = 90
    ) -> CGImage? {
        let bytesPerRow = width * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: cs, bitmapInfo: bitmap) else { return nil }
        // White background.
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Filled black rectangle. CGContext origin is bottom-left; callers pass
        // top-left coordinates, so flip y for the draw.
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        let flippedY = height - rectMaxY
        ctx.fill(CGRect(x: rectMinX, y: flippedY,
                        width: rectMaxX - rectMinX, height: rectMaxY - rectMinY))
        return ctx.makeImage()
    }
}
