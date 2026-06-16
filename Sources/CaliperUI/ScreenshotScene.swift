import SwiftUI
import AppKit
import DesignSystem

/// An `ImageRenderer`-safe reproduction of the Pica overlay for App Store
/// screenshots: a sample app card being measured, a horizontal guide with
/// end-caps and a "240 × 64 px" badge, dashed edge-snap highlight lines, a
/// loupe (zoomed swatch) and a "#3B5BFF" color readout chip. Built only from
/// VStack/HStack/ZStack/Text/Shape/Path/RoundedRectangle/Capsule/Circle so it
/// renders off-screen with no permission.
public struct ScreenshotScene: View {
    let sizeLabel: String
    let hex: String
    public init(sizeLabel: String = "240 × 64 px", hex: String = "#3B5BFF") {
        self.sizeLabel = sizeLabel; self.hex = hex
    }

    private let accent = Color(red: 0.231, green: 0.357, blue: 1.0)

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.13), Color(white: 0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 28) {
                Text("Pixel-perfect measuring, with auto edge-snap.")
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                measuringScene
                    .frame(width: 720, height: 420)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.18)))
            }
            .padding(48)
        }
    }

    // MARK: The measured card scene

    private var measuringScene: some View {
        ZStack(alignment: .topLeading) {
            // Sample app window/card
            sampleCard
                .frame(width: 560, height: 300)
                .offset(x: 80, y: 60)

            // Edge-snap dashed highlight lines aligned to the card edges
            ForEach([80.0, 640.0], id: \.self) { x in
                Path { p in
                    p.move(to: CGPoint(x: x, y: 36))
                    p.addLine(to: CGPoint(x: x, y: 396))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }

            // Horizontal measurement guide with end-caps
            measurementGuide.offset(x: 80, y: 40)

            // The "240 × 64 px" badge
            Text(sizeLabel)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(accent))
                .offset(x: 300, y: 14)

            // Loupe — a circle with a zoomed swatch + crosshair
            loupe.offset(x: 470, y: 220)

            // Color readout chip
            colorChip.offset(x: 470, y: 360)
        }
        .padding(20)
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 11, height: 11)
                Circle().fill(Color.yellow).frame(width: 11, height: 11)
                Circle().fill(Color.green).frame(width: 11, height: 11)
            }
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.3)).frame(width: 220, height: 20)
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.22))
                    .frame(width: [360.0, 300, 340, 280][i], height: 12)
            }
            RoundedRectangle(cornerRadius: 12).fill(accent).frame(width: 240, height: 64)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    private var measurementGuide: some View {
        ZStack(alignment: .leading) {
            // end caps
            Rectangle().fill(accent).frame(width: 2, height: 16)
            Rectangle().fill(accent).frame(width: 2, height: 16).offset(x: 558)
            // the bar
            Rectangle().fill(accent).frame(width: 560, height: 2)
        }
        .frame(width: 560, height: 16)
    }

    private var loupe: some View {
        ZStack {
            Circle().fill(Color.white)
                .frame(width: 88, height: 88)
                .overlay(Circle().strokeBorder(accent, lineWidth: 3))
            // zoomed pixel grid swatch
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { c in
                            Rectangle().fill((r + c) == 4 ? accent : accent.opacity(0.55 + Double((r * 5 + c) % 3) * 0.12))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            .clipShape(Circle())
            // crosshair
            Rectangle().fill(Color.white).frame(width: 12, height: 1.5)
            Rectangle().fill(Color.white).frame(width: 1.5, height: 12)
        }
    }

    private var colorChip: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(accent).frame(width: 22, height: 22)
            Text(hex).font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(Color(white: 0.1)))
    }
}
