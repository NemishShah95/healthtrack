import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testAppLaunchesWithFiveTabs() {
        let app = XCUIApplication()
        app.launch()
        for tab in ["Today", "Log", "Trends", "Weekly", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5), "\(tab) tab missing")
        }
    }
}
