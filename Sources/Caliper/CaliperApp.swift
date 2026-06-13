import SwiftUI
import AppKit
import CoreGraphics
import CaliperUI
import RemoteConfigKit
import LicenseKit
import CommonUI
import LogKit

@main
struct CaliperApp: App {
    @StateObject private var vm = CaliperViewModel()
    @StateObject private var remote = RemoteConfig() // flags OFF by default
    @StateObject private var license = LicenseStore(verifier: nil, productID: "caliper")

    init() {
        AppLog.bootstrap(appName: "Caliper",
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
                .onAppear {
                    AppLog.info("main window shown", category: "ui")
                    if vm.target == nil { vm.setTarget(SampleImage.make()) }
                    Task {
                        await remote.refresh()
                        AppLog.info("remote config refreshed — paid=\(remote.paidEnabled) updates=\(remote.updatesEnabled)", category: "config")
                    }
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Load Sample UI") { vm.setTarget(SampleImage.make()) }.keyboardShortcut("n")
            }
            CommandGroup(after: .toolbar) {
                Button("Auto Edge-Snap") { vm.snapEndpoints() }.keyboardShortcut("k")
            }
        }

        Settings {
            VStack(spacing: 16) {
                AboutView(appName: "Caliper",
                          version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                          tagline: "On-screen ruler, loupe & color picker with auto edge-snap.",
                          replaces: "paid pixel rulers and color pickers")
                LicenseSettingsView(license: license, remote: remote)
            }
            .padding(24)
            .frame(width: 460)
        }
    }
}

/// Wraps the root content and shows the first-run welcome sheet.
private struct RootView: View {
    @EnvironmentObject var vm: CaliperViewModel
    @AppStorage("com.plainware.caliper.onboarding.v1") private var onboarded = false
    @State private var showOnboarding = false

    var body: some View {
        ContentView()
            .onAppear { if !onboarded { showOnboarding = true } }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    appName: "Caliper",
                    tagline: "Measure anything on screen — pixel-perfect.",
                    glyph: "ruler.fill",
                    accent: Color(red: 0.55, green: 0.35, blue: 0.85),
                    steps: [
                        .init(systemImage: "ruler", title: "Measure with edge-snap",
                              detail: "Drag to measure — Caliper snaps to the edges of UI elements automatically."),
                        .init(systemImage: "magnifyingglass", title: "Loupe & color picker",
                              detail: "Zoom into pixels and grab exact colors in multiple formats."),
                        .init(systemImage: "lock.shield", title: "Needs Screen Recording",
                              detail: "macOS will ask for Screen Recording permission so Caliper can read the pixels under your cursor. It all stays on your Mac."),
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
