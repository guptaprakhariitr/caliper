import SwiftUI
import AppKit
import DesignSystem
import EdgeEngine

public struct ContentView: View {
    @EnvironmentObject var vm: CaliperViewModel

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
                Button { vm.snapEndpoints() } label: { Label("Snap", systemImage: "wand.and.stars") }
                    .labelStyle(.titleAndIcon)
                    .help("Snap the measurement endpoints to the nearest detected element edges")
                    .disabled(!vm.snapEnabled)
                Toggle(isOn: $vm.snapEnabled) { Label("Edge-snap", systemImage: "ruler") }
                    .labelStyle(.titleAndIcon)
                    .help("Toggle automatic snapping of endpoints to element edges")
                Spacer()
                Text(vm.measuredLabel).font(DS.Font.mono)
            }
        }
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
                        overlay(scale: scale, ox: ox, oy: oy)
                    }
                }
                .padding(DS.Space.lg)
            } else {
                Text("Capture or drop a UI to measure").font(DS.Font.title)
                    .foregroundStyle(DS.Color.secondaryLabel)
            }
        }
    }

    private func overlay(scale: CGFloat, ox: CGFloat, oy: CGFloat) -> some View {
        let x0 = ox + CGFloat(min(vm.startX, vm.endX)) * scale
        let x1 = ox + CGFloat(max(vm.startX, vm.endX)) * scale
        let y0 = oy + CGFloat(min(vm.startY, vm.endY)) * scale
        let yMid = (y0 + oy + CGFloat(max(vm.startY, vm.endY)) * scale) / 2
        return ZStack(alignment: .topLeading) {
            // Snap guides
            ForEach(vm.snapLines.verticalX.prefix(40), id: \.self) { gx in
                Rectangle().fill(DS.Color.accent.opacity(0.25)).frame(width: 1)
                    .frame(maxHeight: .infinity).offset(x: ox + CGFloat(gx) * scale)
            }
            // Measurement bar
            Rectangle().fill(DS.Color.accent).frame(width: x1 - x0, height: 2)
                .offset(x: x0, y: yMid)
            Text(vm.measuredLabel).font(DS.Font.caption).padding(4)
                .background(DS.Color.accent, in: Capsule()).foregroundStyle(.white)
                .offset(x: x0, y: yMid - 24)
        }
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
