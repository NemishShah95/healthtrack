// swift-tools-version:6.0
// Runs the logic and database tests on the Mac with `swift test` — no simulator needed.
// Needs Xcode selected (SwiftData, HealthKit); HealthKit compiles on macOS but only the mock runs here.
// The app itself builds from HealthTrack.xcodeproj, which compiles these same files.
import PackageDescription

let package = Package(
    name: "HealthTrack",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "HealthTrack", path: "HealthTrack", sources: ["Core", "Health", "Persistence"]),
        .testTarget(name: "HealthTrackTests", dependencies: ["HealthTrack"], path: "HealthTrackTests",
                    sources: ["Core", "Health", "Persistence"]),
    ],
    swiftLanguageModes: [.v5]
)
