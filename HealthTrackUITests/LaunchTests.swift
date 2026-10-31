import XCTest

/// Smoke tests: the app launches and every tab opens, empty and with 90 days of data.
final class LaunchTests: XCTestCase {
    static let tabs = ["Today", "Log", "Trends", "Weekly", "Settings"]

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-skipOnboarding"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func visitEveryTab(_ app: XCUIApplication) {
        for tab in Self.tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(tab) tab missing")
            button.tap()
            XCTAssertTrue(app.navigationBars[tab == "Weekly" ? "Weekly" : tab].waitForExistence(timeout: 10), "\(tab) didn't open")
        }
    }

    @MainActor
    func testEveryTabOpensWithNoData() {
        visitEveryTab(launch(["-mockHealth", "empty"]))
    }

    @MainActor
    func testEveryTabOpensWithNinetyDaysOfData() {
        visitEveryTab(launch(["-mockHealth", "full", "-seedSampleData"]))
    }

    @MainActor
    func testOneTapWaterLogging() {
        let app = launch(["-mockHealth", "empty"])
        let add = app.buttons["Add 250 millilitres"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.staticTexts["0.2 / 2.5 L"].waitForExistence(timeout: 5)
                      || app.staticTexts["0.3 / 2.5 L"].exists)
    }
}
