// swift-tools-version:6.0
// Runs the logic and database tests on the Mac with `swift test` — no simulator needed.
// Core/ needs only Command Line Tools; Persistence/ (SwiftData) needs Xcode selected.
// The app itself builds from HealthTrack.xcodeproj, which compiles these same files.
import PackageDescription

let package = Package(
    name: "HealthTrack",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "HealthTrack", path: "HealthTrack", sources: ["Core", "Persistence"]),
        .testTarget(name: "HealthTrackTests", dependencies: ["HealthTrack"], path: "HealthTrackTests",
                    sources: ["Core", "Persistence"]),
    ],
    swiftLanguageModes: [.v5]
)
