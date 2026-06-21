import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DesignSystem
import EdgeEngine

public struct ContentView: View {
    @EnvironmentObject var vm: CaliperViewModel
    @StateObject private var splash = SplashModel()
    @State private var isDropTargeted = false
    @State private var moveOrigin: (x: Int, y: Int, w: Int, h: Int)? = nil
    @State private var activeDrag: DragKind? = nil
    private enum DragKind { case left, right, top, bottom, move }

    public init() {}

    public var body: some View {
        ZStack {
            mainContent
            if splash.showSplash {
                SplashView(model: splash)
                    .zIndex(1)
            }
        }
    }

    private var mainContent: some View {
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
                Button { vm.snapEndpoints(maxDistance: 100_000) } label: { Image(systemName: "wand.and.stars") }
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
        pb.setString(vm.copyString(), forType: .string)
    }

    // MARK: Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                Text("PicaMac").font(DS.Font.display)
                Text(SplashModel.tagline)
                    .font(DS.Font.caption).foregroundStyle(DS.Color.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                group("Measurement") {
                    Picker("Unit", selection: $vm.unit) {
                        ForEach(CaliperViewModel.MeasureUnit.allCases) { u in Text(u.label).tag(u) }
                    }
                    .labelsHidden()
                    row("Width", "\(vm.widthString()) \(vm.unit.rawValue)")
                    row("Height", "\(vm.heightString()) \(vm.unit.rawValue)")
                }
                group("Endpoints (px)") {
                    stepper("Start X", value: $vm.startX)
                    stepper("End X", value: $vm.endX)
                    stepper("Start Y", value: $vm.startY)
                    stepper("End Y", value: $vm.endY)
                }
                group("Auto edge-snap") {
                    Toggle(isOn: $vm.snapEnabled) { Text("Snap endpoints to element edges") }
                    Button("Snap now") { vm.snapEndpoints(maxDistance: 100_000) }
                        .buttonStyle(.dsPrimary).disabled(!vm.snapEnabled)
                    Text("\(vm.snapLines.verticalX.count) vertical · \(vm.snapLines.horizontalY.count) horizontal edges")
                        .font(DS.Font.caption).foregroundStyle(DS.Color.tertiaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
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
                                .textSelection(.enabled)
                                .lineLimit(1).truncationMode(.middle)
                            Text(vm.sampledHSL).font(DS.Font.caption).foregroundStyle(DS.Color.secondaryLabel)
                                .textSelection(.enabled)
                                .lineLimit(1).truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack {
            Text(label).font(DS.Font.body)
            Spacer(minLength: DS.Space.sm)
            Text(value).font(DS.Font.mono)
                .lineLimit(1).truncationMode(.middle)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)
        }
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
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
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
                        .fixedSize(horizontal: false, vertical: true)
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
        let handles = [CGPoint(x: x0, y: yMid), CGPoint(x: x1, y: yMid),
                       CGPoint(x: xMid, y: yA), CGPoint(x: xMid, y: yB)]

        func imgX(_ vx: CGFloat) -> Int { Int(((vx - ox) / scale).rounded()).clamped(to: 0...Int(imgW)) }
        func imgY(_ vy: CGFloat) -> Int { Int(((vy - oy) / scale).rounded()).clamped(to: 0...Int(imgH)) }

        // Decide what a press near `p` grabs: an edge handle, the box interior, or nothing.
        func hit(_ p: CGPoint) -> DragKind? {
            let t: CGFloat = 26
            if hypot(p.x - x0, p.y - yMid) < t { return .left }
            if hypot(p.x - x1, p.y - yMid) < t { return .right }
            if hypot(p.x - xMid, p.y - yA) < t { return .top }
            if hypot(p.x - xMid, p.y - yB) < t { return .bottom }
            if p.x >= x0 - t && p.x <= x1 + t && p.y >= yA - t && p.y <= yB + t { return .move }
            return nil
        }

        return ZStack(alignment: .topLeading) {
            // Snap guides
            ForEach(vm.snapLines.verticalX.prefix(40), id: \.self) { gx in
                Rectangle().fill(DS.Color.accent.opacity(0.25)).frame(width: 1)
                    .frame(maxHeight: .infinity).offset(x: ox + CGFloat(gx) * scale)
            }
            // Interior move affordance + outline
            Rectangle().fill(DS.Color.accent.opacity(0.08))
                .frame(width: max(x1 - x0, 1), height: max(yB - yA, 1)).offset(x: x0, y: yA)
            Rectangle().strokeBorder(DS.Color.accent.opacity(0.7), lineWidth: 1.5)
                .frame(width: max(x1 - x0, 1), height: max(yB - yA, 1)).offset(x: x0, y: yA)
            // Measurement bar + size label
            Rectangle().fill(DS.Color.accent).frame(width: x1 - x0, height: 2).offset(x: x0, y: yMid)
            Text(vm.measuredLabel).font(DS.Font.caption).padding(4)
                .background(DS.Color.accent, in: Capsule()).foregroundStyle(.white)
                .offset(x: x0, y: max(yA - 24, 0))
            // Visual handle dots (interaction handled by the single gesture below)
            ForEach(handles.indices, id: \.self) { i in
                Circle().fill(DS.Color.accent)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .frame(width: 14, height: 14)
                    .offset(x: handles[i].x - 7, y: handles[i].y - 7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .coordinateSpace(name: Self.overlaySpace)
        // ONE gesture for the whole canvas: a per-handle gesture gets cancelled when
        // the view re-renders mid-drag, so instead we hit-test the start location and
        // track the active target in @State for the duration of the drag.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.overlaySpace))
                .onChanged { g in
                    if activeDrag == nil {
                        activeDrag = hit(g.startLocation)
                        if activeDrag == .move {
                            moveOrigin = (min(vm.startX, vm.endX), min(vm.startY, vm.endY),
                                          abs(vm.endX - vm.startX), abs(vm.endY - vm.startY))
                        }
                    }
                    switch activeDrag {
                    case .left:   setX(imgX(g.location.x), isLeft: true)
                    case .right:  setX(imgX(g.location.x), isLeft: false)
                    case .top:    setY(imgY(g.location.y), isTop: true)
                    case .bottom: setY(imgY(g.location.y), isTop: false)
                    case .move:
                        if let o = moveOrigin {
                            let dx = Int((g.translation.width / scale).rounded())
                            let dy = Int((g.translation.height / scale).rounded())
                            let nx = (o.x + dx).clamped(to: 0...max(0, Int(imgW) - o.w))
                            let ny = (o.y + dy).clamped(to: 0...max(0, Int(imgH) - o.h))
                            vm.startX = nx; vm.endX = nx + o.w
                            vm.startY = ny; vm.endY = ny + o.h
                        }
                    case .none: break
                    }
                }
                .onEnded { _ in
                    activeDrag = nil; moveOrigin = nil
                    if vm.snapEnabled { vm.snapEndpoints() }
                }
        )
    }

    private static let overlaySpace = "caliperOverlay"

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
