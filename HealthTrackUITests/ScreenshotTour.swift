import XCTest

/// Visual QA helper, skipped in normal runs. Capture every screen with 90 days of data:
///   TEST_RUNNER_SCREENSHOTS=1 xcodebuild test ... -only-testing:HealthTrackUITests/ScreenshotTour
///   xcrun xcresulttool export attachments --path <result.xcresult> --output-path <dir>
final class ScreenshotTour: XCTestCase {
    @MainActor
    func testCaptureEveryTab() throws {
        let mode = ProcessInfo.processInfo.environment["SCREENSHOTS"]
        try XCTSkipUnless(mode != nil, "Set TEST_RUNNER_SCREENSHOTS=1 (or =empty for a brand-new install)")
        let app = XCUIApplication()
        app.launchArguments = mode == "empty"
            ? ["-inMemoryStore", "-skipOnboarding", "-mockHealth", "empty"]
            : ["-inMemoryStore", "-skipOnboarding", "-seedSampleData", "-mockHealth", "full"]
        app.launch()
        func capture(_ name: String) {
            sleep(1)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }
        capture("Today")
        app.swipeUp()
        capture("Today-2")
        app.swipeDown()
        for name in ["Sleep", "Meals", "Protein", "Workouts", "Vitamins", "Recovery"] {
            let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            guard tile.exists else { continue }
            tile.tap()
            capture("Today-\(name)")
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Yesterday'")).firstMatch.tap()
        capture("Today-yesterday")
        app.buttons["Log a gym session"].firstMatch.tap()
        capture("Gym-editor")
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Training"].tap()
        capture("Training")
        app.swipeUp()
        capture("Training-2")
        app.navigationBars.buttons["Add goal"].tap()
        capture("Training-goal-editor")
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Trends"].tap()
        app.staticTexts["Sleep duration"].firstMatch.tap()
        capture("Trends-detail")
        app.navigationBars.buttons.firstMatch.tap()
        for tab in ["Trends", "Weekly", "Settings"] {
            app.tabBars.buttons[tab].tap()
            capture(tab)
            app.swipeUp()
            capture("\(tab)-2")
        }
    }
}
