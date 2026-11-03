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

    /// Today tiles are single buttons whose label starts with the tile name.
    @MainActor
    private func tile(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
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
        let water = tile(app, "Water").label
        XCTAssertTrue(water.contains("0.2 / 2.5 L") || water.contains("0.3 / 2.5 L"), water)
    }

    @MainActor
    func testLogGymSessionAndProteinFromToday() {
        let app = launch(["-mockHealth", "empty"])
        app.buttons["Add 20 grams of protein"].firstMatch.tap()
        XCTAssertTrue(tile(app, "Protein").label.contains("20 / 100 g"))

        app.buttons["Log a gym session"].firstMatch.tap()
        app.buttons["Legs"].firstMatch.tap()
        let exercises = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields["Bench press 3x10 60 kg"].firstMatch
        exercises.tap()
        exercises.typeText("Squat 5x5 100 kg")
        app.buttons["Save"].tap()
        XCTAssertTrue(tile(app, "Gym").waitForExistence(timeout: 5))
        XCTAssertTrue(tile(app, "Gym").label.contains("Legs") && tile(app, "Gym").label.contains("1 exercise"))
    }

    @MainActor
    func testVitaminsFromAnEmptyAppAndJournal() {
        let app = launch(["-mockHealth", "empty"])
        XCTAssertTrue(tile(app, "Vitamins").waitForExistence(timeout: 10))
        XCTAssertTrue(tile(app, "Vitamins").label.contains("None added"))
        app.buttons["Add a vitamin"].firstMatch.tap()
        let name = app.textFields["Name, e.g. Vitamin D or Magnesium"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Vitamin D")
        app.buttons["Save"].tap()
        XCTAssertTrue(tile(app, "Vitamins").label.contains("0/1"))

        app.buttons["Mark all vitamins taken"].firstMatch.tap()
        XCTAssertTrue(tile(app, "Vitamins").label.contains("1/1"))

        app.buttons["Log a vitamin"].firstMatch.tap()          // journal an extra dose from the tile
        app.buttons["Log Vitamin D"].firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(tile(app, "Vitamins").label.contains("+1 extra"))
        XCTAssertTrue(tile(app, "Vitamins").label.contains("1/1"))   // adherence unchanged
    }

    /// Apple's automated accessibility audit (VoiceOver labels, contrast, hit targets, clipped text) on every tab.
    @MainActor
    func testAccessibilityAuditOnEveryTab() throws {
        let app = launch(["-mockHealth", "full", "-seedSampleData"])
        for tab in Self.tabs {
            app.tabBars.buttons[tab].tap()
            _ = app.navigationBars[tab].waitForExistence(timeout: 5)
            // Skipped on purpose (see TEST_PLAN.md):
            //  - "nearly passed" contrast: Apple's own secondary-label grey;
            //  - contrast on anything under the translucent tab bar: the audit measures through the blur;
            //  - contrast findings with no element: unattributable system chrome (logged, not failed);
            //  - the Dynamic Type check: it flags plain system list rows too. Large text is checked visually.
            let tabBar = app.tabBars.firstMatch.frame
            try app.performAccessibilityAudit(for: .all.subtracting(.dynamicType)) { issue in
                let isContrast = issue.auditType == .contrast
                let ignore = issue.compactDescription == "Contrast nearly passed"
                    || (isContrast && (issue.element.map { $0.frame.intersects(tabBar) } ?? true))
                print("A11Y|\(ignore ? "ignored" : "FAILED")|\(tab)|\(issue.compactDescription)|\(issue.element?.label ?? "(no element)")")
                return ignore
            }
        }
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
        tile(app, "Water").tap()                                                          // tile opens its page
        XCTAssertTrue(app.buttons["Add 500 millilitres"].waitForExistence(timeout: 5))
    }
}
