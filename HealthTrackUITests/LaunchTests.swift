import XCTest

/// Smoke tests: the app launches and every tab opens, empty and with 90 days of data.
final class LaunchTests: XCTestCase {
    static let tabs = ["Today", "Trends", "Weekly", "Settings"]

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
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 10), "\(tab) didn't open")
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

    @MainActor
    func testLogGymSessionAndProteinFromToday() {
        let app = launch(["-mockHealth", "empty"])
        app.buttons["Add 20 grams of protein"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["20 / 100 g"].waitForExistence(timeout: 5))

        app.buttons["Log a gym session"].firstMatch.tap()
        app.buttons["Legs"].firstMatch.tap()
        let exercises = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields["Bench press 3x10 60 kg"].firstMatch
        exercises.tap()
        exercises.typeText("Squat 5x5 100 kg")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Legs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 exercise"].exists)
    }

    @MainActor
    func testSwipeBackThroughTheLastFiveDays() {
        let app = launch(["-mockHealth", "full", "-seedSampleData"])
        let yesterday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Yesterday'")).firstMatch
        XCTAssertTrue(yesterday.waitForExistence(timeout: 10))
        yesterday.tap()
        XCTAssertTrue(app.navigationBars["Yesterday"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertFalse(app.navigationBars["Yesterday"].waitForExistence(timeout: 2))   // moved further back
        app.staticTexts["Water"].firstMatch.tap()                                         // tile opens its page
        XCTAssertTrue(app.buttons["Add 500 millilitres"].waitForExistence(timeout: 5))
    }
}
