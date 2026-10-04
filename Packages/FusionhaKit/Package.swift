// swift-tools-version:5.10
import PackageDescription

// Pure Foundation: no UIKit/SwiftUI, so `swift test` also runs on a macOS host.
let package = Package(
    name: "FusionhaKit",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        .library(name: "FusionhaKit", targets: ["FusionhaKit"]),
    ],
    targets: [
        .target(name: "FusionhaKit"),
        .testTarget(
            name: "FusionhaKitTests",
            dependencies: ["FusionhaKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
