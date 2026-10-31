import XCTest

/// Visual QA helper, skipped in normal runs. Capture every screen with 90 days of data:
///   TEST_RUNNER_SCREENSHOTS=1 xcodebuild test ... -only-testing:HealthTrackUITests/ScreenshotTour
///   xcrun xcresulttool export attachments --path <result.xcresult> --output-path <dir>
final class ScreenshotTour: XCTestCase {
    @MainActor
    func testCaptureEveryTab() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] != nil, "Set TEST_RUNNER_SCREENSHOTS=1")
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-skipOnboarding", "-seedSampleData", "-mockHealth", "full"]
        app.launch()
        for tab in ["Today", "Log", "Trends", "Weekly", "Settings"] {
            app.tabBars.buttons[tab].tap()
            for page in 1...3 {
                sleep(1)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "\(tab)-\(page)"
                shot.lifetime = .keepAlways
                add(shot)
                app.swipeUp()
            }
        }
    }
}
