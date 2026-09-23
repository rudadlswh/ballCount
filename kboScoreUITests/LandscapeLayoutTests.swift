import XCTest

final class LandscapeLayoutTests: XCTestCase {
    @MainActor
    func testStandingsKeepsTeamColumnFixedWhileStatsScroll() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-kbo_live_onboarding_completed", "YES"]
        app.launch()
        XCTAssertLessThan(app.frame.width, app.frame.height)
        XCTAssertTrue(app.tabBars.buttons["순위"].waitForExistence(timeout: 60))
        app.tabBars.buttons["순위"].tap()

        let teamHeader = app.staticTexts["팀"]
        let statsScroll = app.scrollViews["standingsStatsScroll"]
        let statsHeader = statsScroll.staticTexts["승률"]
        XCTAssertTrue(teamHeader.waitForExistence(timeout: 60))
        XCTAssertTrue(statsHeader.exists)
        XCTAssertLessThan(teamHeader.frame.maxX, statsScroll.frame.minX)
        let teamX = teamHeader.frame.minX
        let statsX = statsHeader.frame.minX
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "순위-스크롤-전"
        before.lifetime = .keepAlways
        add(before)

        statsScroll.swipeLeft()
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "순위-스크롤-후"
        after.lifetime = .keepAlways
        add(after)

        XCTAssertEqual(teamHeader.frame.minX, teamX, accuracy: 1)
        XCTAssertLessThan(teamHeader.frame.maxX, statsScroll.frame.minX)
        XCTAssertLessThan(statsHeader.frame.minX, statsX - 10)
    }

    @MainActor
    func testTabContentStaysBelowNavigationBarAfterRotation() throws {
        continueAfterFailure = false
        let device = XCUIDevice.shared
        device.orientation = .portrait
        defer { device.orientation = .portrait }

        let app = XCUIApplication()
        app.launchArguments += ["-kbo_live_onboarding_completed", "YES"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60))

        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            device.orientation = orientation
            XCTAssertEqual(app.frame.width > app.frame.height, orientation != .portrait)
            for title in ["홈", "순위", "일정", "직관"] {
                app.tabBars.buttons[title].tap()
                let navigationBar = app.navigationBars.firstMatch
                let notification = navigationBar.buttons["알림"]
                XCTAssertTrue(notification.waitForExistence(timeout: 5), title)
                XCTAssertTrue(notification.isHittable, title)
                XCTAssertTrue(navigationBar.frame.contains(notification.frame), title)

                let firstText = app.scrollViews.firstMatch.staticTexts.firstMatch
                XCTAssertTrue(firstText.waitForExistence(timeout: 10), title)
                XCTAssertGreaterThanOrEqual(
                    firstText.frame.minY,
                    navigationBar.frame.maxY - 1,
                    "\(title): first content is hidden behind the navigation bar"
                )

                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "\(title)-\(orientation.rawValue)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
        }
    }
}
