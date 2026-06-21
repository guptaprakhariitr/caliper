import SwiftUI
import AppKit
import CoreGraphics
import CaliperUI
import RemoteConfigKit
import LicenseKit
import VersionGateKit
import CommonUI
import LogKit
import UniformTypeIdentifiers

@main
struct CaliperApp: App {
    @StateObject private var vm = CaliperViewModel()
    @StateObject private var remote = RemoteConfig() // flags OFF by default
    @StateObject private var license = LicenseStore(verifier: nil, productID: "caliper")
    @StateObject private var versionGate = VersionGate.fromBundle(appKey: "caliper")
        ?? VersionGate(projectId: "", apiKey: "", appKey: "caliper", currentBuild: 0, currentVersion: "0")

    init() {
        AppLog.bootstrap(appName: "PicaMac",
                         version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
        if CGPreflightScreenCaptureAccess() {
            AppLog.info("screen recording authorization: granted", category: "lifecycle")
        } else {
            AppLog.warn("screen recording authorization: not granted", category: "lifecycle")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .versionGate(versionGate)
                .onAppear {
                    AppLog.info("main window shown", category: "ui")
                    if vm.target == nil { vm.setTarget(SampleImage.make()) }
                    Task {
                        await remote.refresh()
                        AppLog.info("remote config refreshed — paid=\(remote.paidEnabled) updates=\(remote.updatesEnabled)", category: "config")
                    }
                    Task { await versionGate.check() }
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Screenshot…") { openImage() }.keyboardShortcut("o")
                Button("Load Sample UI") { vm.setTarget(SampleImage.make()) }.keyboardShortcut("n")
            }
            CommandGroup(after: .toolbar) {
                Button("Auto Edge-Snap") { vm.snapEndpoints() }.keyboardShortcut("k")
            }
        }

        Settings {
            VStack(spacing: 16) {
                AboutView(appName: "PicaMac",
                          version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                          tagline: "Measure anything on screen, to the pixel.",
                          replaces: "paid pixel rulers and color pickers")
                LicenseSettingsView(license: license, remote: remote)
            }
            .padding(24)
            .frame(width: 460)
        }
    }

    /// Open an image via NSOpenPanel and load it as the measurement target (⌘O).
    private func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a screenshot or UI image to measure"
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            vm.setTarget(img)
        }
    }
}

/// Wraps the root content and shows the first-run welcome sheet.
private struct RootView: View {
    @EnvironmentObject var vm: CaliperViewModel
    @AppStorage("com.plainware.caliper.onboarding.v2") private var onboarded = false
    @State private var showOnboarding = false

    var body: some View {
        ContentView()
            .onAppear { if !onboarded { showOnboarding = true } }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    appName: "PicaMac",
                    tagline: "Measure anything on screen, to the pixel.",
                    glyph: "ruler.fill",
                    accent: Color(red: 0.55, green: 0.35, blue: 0.85),
                    steps: [
                        .init(systemImage: "photo.badge.plus", title: "Load a screenshot",
                              detail: "Drag a screenshot onto the canvas, or click Open (⌘O). Press ⌘N to try a sample."),
                        .init(systemImage: "ruler", title: "Drag to measure",
                              detail: "Drag the corner handles on the canvas — endpoints snap to real element edges automatically. Width and height update live."),
                        .init(systemImage: "eyedropper.halffull", title: "Read the color",
                              detail: "The color under your measurement shows as hex and HSL — ready to copy into your code."),
                    ],
                    primaryTitle: "Start Measuring",
                    footnote: "Nothing is uploaded — measuring happens locally.",
                    primaryAction: {
                        onboarded = true; showOnboarding = false
                        if vm.target == nil { vm.setTarget(SampleImage.make()) }
                    },
                    secondaryAction: { onboarded = true; showOnboarding = false }
                )
            }
    }
}
