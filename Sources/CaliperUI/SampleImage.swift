import AppKit

/// Generates a realistic mock "app UI" image so the ruler has a believable
/// target on first launch and off-screen screenshots look real. Crisp,
/// high-contrast element edges give EdgeEngine clear boundaries to snap to.
public enum SampleImage {
    public static func make(width: Int = 1200, height: Int = 760) -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let W = CGFloat(width), H = CGFloat(height)

        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

        // Title bar
        NSColor(white: 0.96, alpha: 1).setFill()
        NSRect(x: 0, y: H - 56, width: W, height: 56).fill()
        let dots: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
        for (i, c) in dots.enumerated() {
            c.setFill()
            NSBezierPath(ovalIn: NSRect(x: 22 + CGFloat(i) * 26, y: H - 36, width: 14, height: 14)).fill()
        }
        // Sidebar
        NSColor(white: 0.98, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 240, height: H - 56).fill()
        for i in 0..<7 {
            NSColor(white: 0.90, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 20, y: H - 110 - CGFloat(i) * 52, width: 200, height: 32),
                         xRadius: 8, yRadius: 8).fill()
        }
        // Content heading + lines
        NSColor(white: 0.20, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 280, y: H - 130, width: 380, height: 28), xRadius: 6, yRadius: 6).fill()
        for i in 0..<9 {
            NSColor(white: 0.88, alpha: 1).setFill()
            let w = CGFloat([520, 600, 470, 560, 610, 500, 580, 440, 540][i % 9])
            NSBezierPath(roundedRect: NSRect(x: 280, y: H - 190 - CGFloat(i) * 46, width: w, height: 18),
                         xRadius: 5, yRadius: 5).fill()
        }
        // Accent card — the kind of element you'd measure.
        NSColor(srgbRed: 0.231, green: 0.357, blue: 1.0, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 840, y: H - 360, width: 320, height: 230), xRadius: 16, yRadius: 16).fill()

        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: NSSize(width: width, height: height))
        img.addRepresentation(rep)
        return img
    }
}
