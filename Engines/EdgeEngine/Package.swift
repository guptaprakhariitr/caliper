// swift-tools-version:5.9
import PackageDescription

// EdgeEngine — the proprietary edge-detection / snapping core. In the OSS
// release this is consumed as a precompiled XCFramework binary; here (private
// repo) it builds from source.
let package = Package(
    name: "EdgeEngine",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EdgeEngine", targets: ["EdgeEngine"])],
    targets: [.target(name: "EdgeEngine")]
)
