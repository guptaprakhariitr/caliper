// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Caliper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Packages/Core"),
        .package(path: "Engines/EdgeEngine"),
    ],
    targets: [
        // The open-source shell UI (becomes the public OSS module later).
        .target(
            name: "CaliperUI",
            dependencies: [
                "EdgeEngine",
                .product(name: "DesignSystem", package: "Core"),
                .product(name: "CommonUI", package: "Core"),
                .product(name: "SettingsKit", package: "Core"),
                .product(name: "RemoteConfigKit", package: "Core"),
                .product(name: "LicenseKit", package: "Core"),
                .product(name: "UpdateKit", package: "Core"),
                .product(name: "LogKit", package: "Core"),
            ],
            path: "Sources/CaliperUI"
        ),
        .executableTarget(
            name: "Caliper",
            dependencies: [
                "CaliperUI",
                .product(name: "CommonUI", package: "Core"),
                .product(name: "RemoteConfigKit", package: "Core"),
                .product(name: "LicenseKit", package: "Core"),
                .product(name: "LogKit", package: "Core"),
            ],
            path: "Sources/Caliper"
        ),
        .executableTarget(
            name: "CaliperChecks",
            dependencies: [
                "CaliperUI",
                "EdgeEngine",
                .product(name: "ScreenshotKit", package: "Core"),
            ],
            path: "Sources/CaliperChecks"
        ),
    ]
)
