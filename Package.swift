// swift-tools-version:6.0
// Runs the Foundation-only core logic tests with `swift test` — no Xcode or simulator needed.
// The app itself builds from HealthTrack.xcodeproj; both compile the same files under HealthTrack/Core.
import PackageDescription

let package = Package(
    name: "HealthTrack",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "HealthTrack", path: "HealthTrack/Core"),
        .testTarget(name: "HealthTrackTests", dependencies: ["HealthTrack"], path: "HealthTrackTests/Core"),
    ],
    swiftLanguageModes: [.v5]
)
