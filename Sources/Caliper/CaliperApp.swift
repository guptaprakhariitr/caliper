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
            ContentView()
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
