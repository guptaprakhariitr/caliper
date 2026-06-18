import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DesignSystem
import EdgeEngine

public struct ContentView: View {
    @EnvironmentObject var vm: CaliperViewModel
    @State private var isDropTargeted = false

    public init() {}

    public var body: some View {
        HSplitView {
            controls
                .frame(width: 280)
                .frame(maxHeight: .infinity)
                .background(DS.Color.bgElevated)
            preview
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar {
            ToolbarItemGroup {
                // BUG 3: icon-only Snap + compact toggle, a fixed-width readout pill,
                // and a Copy button. Tight spacing/fixed widths keep everything from
                // clipping at the default window size.
                Button { openPanel() } label: { Image(systemName: "folder") }
                    .help("Open a screenshot to measure (⌘O)")
                Button { vm.snapEndpoints() } label: { Image(systemName: "wand.and.stars") }
                    .help("Snap the measurement endpoints to the nearest detected element edges")
                    .disabled(!vm.snapEnabled)
                Toggle(isOn: $vm.snapEnabled) { Image(systemName: "ruler") }
                    .toggleStyle(.button)
                    .help("Toggle automatic snapping of endpoints to element edges")

                Text(vm.measuredLabel)
                    .font(DS.Font.mono)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, DS.Space.sm)
                    .padding(.vertical, DS.Space.xs)
                    .background(DS.Color.bgElevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(DS.Color.separator, lineWidth: 0.5))
                    .help("Current measurement (width × height)")

                Button { copyResult() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .help("Copy the measurement to the clipboard")
            }
        }
    }

    /// Copy the current measurement readout to the system pasteboard.
    private func copyResult() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(vm.measuredLabel, forType: .string)
    }

    // MARK: Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                Text("PicaMac").font(DS.Font.display)
                Text("Measure, zoom and pick colors on screen.")
                    .font(DS.Font.caption).foregroundStyle(DS.Color.secondaryLabel)

                group("Measurement") {
                    row("Width", "\(vm.measuredWidth) px")
                    row("Height", "\(vm.measuredHeight) px")
                }
                group("Endpoints (px)") {
                    stepper("Start X", value: $vm.startX)
                    stepper("End X", value: $vm.endX)
                    stepper("Start Y", value: $vm.startY)
                    stepper("End Y", value: $vm.endY)
                }
                group("Auto edge-snap") {
                    Toggle(isOn: $vm.snapEnabled) { Text("Snap endpoints to element edges") }
                    Button("Snap now") { vm.snapEndpoints() }
                        .buttonStyle(.dsPrimary).disabled(!vm.snapEnabled)
                    Text("\(vm.snapLines.verticalX.count) vertical · \(vm.snapLines.horizontalY.count) horizontal edges")
                        .font(DS.Font.caption).foregroundStyle(DS.Color.tertiaryLabel)
                }
                group("Color") {
                    HStack {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color(hex: vm.sampledHex))
                            .frame(width: 28, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(DS.Color.separator, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.sampledHex).font(DS.Font.mono)
                            Text(vm.sampledHSL).font(DS.Font.caption).foregroundStyle(DS.Color.secondaryLabel)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Space.md)
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text(title.uppercased()).font(DS.Font.caption).foregroundStyle(DS.Color.tertiaryLabel)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(DS.Font.body); Spacer(); Text(value).font(DS.Font.mono) }
    }

    private func stepper(_ label: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...4000) {
            HStack { Text(label).font(DS.Font.body); Spacer(); Text("\(value.wrappedValue)").font(DS.Font.mono) }
        }
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            DS.Color.bg
            if let target = vm.target {
                GeometryReader { geo in
                    let imgW = target.size.width, imgH = target.size.height
                    let scale = min(geo.size.width / imgW, geo.size.height / imgH)
                    let dispW = imgW * scale, dispH = imgH * scale
                    let ox = (geo.size.width - dispW) / 2, oy = (geo.size.height - dispH) / 2
                    ZStack(alignment: .topLeading) {
                        Image(nsImage: target).resizable().frame(width: dispW, height: dispH)
                            .offset(x: ox, y: oy)
                        overlay(scale: scale, ox: ox, oy: oy, imgW: imgW, imgH: imgH)
                    }
                }
                .padding(DS.Space.lg)
            } else {
                VStack(spacing: DS.Space.md) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(DS.Color.tertiaryLabel)
                    Text("Drag a screenshot here to measure it")
                        .font(DS.Font.title)
                        .foregroundStyle(DS.Color.secondaryLabel)
                        .multilineTextAlignment(.center)
                    Button { openPanel() } label: {
                        Label("Open Screenshot…", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Text("or press ⌘N for a sample to try it out")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.tertiaryLabel)
                }
            }
        }
        // Whole canvas is a drop target (empty or showing an image). NOTE: a single
        // onDrop only — combining .dropDestination and .onDrop makes neither fire.
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .image, .png, .tiff, .jpeg], isTargeted: $isDropTargeted) { providers in
            loadDroppedProviders(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Color.accent, style: StrokeStyle(lineWidth: 3, dash: [9, 7]))
                    .padding(DS.Space.md)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Open an image with NSOpenPanel — a guaranteed alternative to drag-and-drop.
    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a screenshot or UI image to measure"
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            vm.setTarget(img)
        }
    }

    // MARK: Drop handling (BUG 1)

    /// Load the first decodable image from dropped file URLs.
    @discardableResult
    private func loadDroppedURLs(_ urls: [URL]) -> Bool {
        for url in urls {
            if let img = NSImage(contentsOf: url) {
                vm.setTarget(img)
                return true
            }
        }
        return false
    }

    /// Fallback for raw image data / file-URL item providers (e.g. dragging from
    /// apps that vend NSImage or image data rather than a Finder file URL).
    private func loadDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        // Prefer a file URL when one is offered.
        if let urlProvider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
            _ = urlProvider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { _ = self.loadDroppedURLs([url]) }
            }
            return true
        }
        // Otherwise try to materialize an NSImage from the data.
        for type in [UTType.png, .tiff, .image] {
            if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.identifier) }) {
                provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data, let img = NSImage(data: data) else { return }
                    DispatchQueue.main.async { self.vm.setTarget(img) }
                }
                return true
            }
        }
        return false
    }

    // MARK: Overlay + draggable handles (BUG 2)

    private func overlay(scale: CGFloat, ox: CGFloat, oy: CGFloat, imgW: CGFloat, imgH: CGFloat) -> some View {
        let x0 = ox + CGFloat(min(vm.startX, vm.endX)) * scale
        let x1 = ox + CGFloat(max(vm.startX, vm.endX)) * scale
        let yA = oy + CGFloat(min(vm.startY, vm.endY)) * scale
        let yB = oy + CGFloat(max(vm.startY, vm.endY)) * scale
        let yMid = (yA + yB) / 2
        let xMid = (x0 + x1) / 2

        // Convert a view-space coordinate to image px, clamped to the image bounds.
        func imgX(_ vx: CGFloat) -> Int { Int(((vx - ox) / scale).rounded()).clamped(to: 0...Int(imgW)) }
        func imgY(_ vy: CGFloat) -> Int { Int(((vy - oy) / scale).rounded()).clamped(to: 0...Int(imgH)) }

        return ZStack(alignment: .topLeading) {
            // Snap guides
            ForEach(vm.snapLines.verticalX.prefix(40), id: \.self) { gx in
                Rectangle().fill(DS.Color.accent.opacity(0.25)).frame(width: 1)
                    .frame(maxHeight: .infinity).offset(x: ox + CGFloat(gx) * scale)
            }

            // Measured rectangle outline
            Rectangle()
                .strokeBorder(DS.Color.accent.opacity(0.6), lineWidth: 1)
                .frame(width: x1 - x0, height: yB - yA)
                .offset(x: x0, y: yA)

            // Measurement bar (kept for visual continuity)
            Rectangle().fill(DS.Color.accent).frame(width: x1 - x0, height: 2)
                .offset(x: x0, y: yMid)
            Text(vm.measuredLabel).font(DS.Font.caption).padding(4)
                .background(DS.Color.accent, in: Capsule()).foregroundStyle(.white)
                .offset(x: x0, y: yA - 24)

            // Draggable edge handles. Each edge updates the endpoint nearest to it.
            // Vertical edges drive startX/endX, horizontal edges drive startY/endY.
            // Drag locations are reported in the overlay (.named) coordinate space.
            edgeHandle(at: CGPoint(x: x0, y: yMid)) { loc in setX(imgX(loc.x), isLeft: true) }   // left edge
            edgeHandle(at: CGPoint(x: x1, y: yMid)) { loc in setX(imgX(loc.x), isLeft: false) }  // right edge
            edgeHandle(at: CGPoint(x: xMid, y: yA)) { loc in setY(imgY(loc.y), isTop: true) }    // top edge
            edgeHandle(at: CGPoint(x: xMid, y: yB)) { loc in setY(imgY(loc.y), isTop: false) }   // bottom edge
        }
        .coordinateSpace(name: Self.overlaySpace)
    }

    private static let overlaySpace = "caliperOverlay"

    /// A small accent circle with a generous hit area. The visible dot is 12pt;
    /// a 28pt transparent disc gives a comfortable grab target. Drag locations
    /// are reported in the named overlay coordinate space.
    private func edgeHandle(at point: CGPoint, onDrag: @escaping (CGPoint) -> Void) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.001)).frame(width: 28, height: 28)
            Circle().fill(DS.Color.accent)
                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                .frame(width: 12, height: 12)
        }
        .contentShape(Circle())
        .offset(x: point.x - 14, y: point.y - 14)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.overlaySpace))
                .onChanged { onDrag($0.location) }
                .onEnded { _ in if vm.snapEnabled { vm.snapEndpoints() } }
        )
    }

    /// Update whichever X endpoint (startX/endX) is on the dragged side.
    private func setX(_ value: Int, isLeft: Bool) {
        if (vm.startX <= vm.endX) == isLeft { vm.startX = value } else { vm.endX = value }
    }

    /// Update whichever Y endpoint (startY/endY) is on the dragged side.
    private func setY(_ value: Int, isTop: Bool) {
        if (vm.startY <= vm.endY) == isTop { vm.startY = value } else { vm.endY = value }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
