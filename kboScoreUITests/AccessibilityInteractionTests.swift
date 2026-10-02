import XCTest

final class AccessibilityInteractionTests: XCTestCase {
    @MainActor func testCalendarAndNotificationSettingsRespondToPaddingTaps() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-kbo_live_onboarding_completed", "YES"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["일정"].waitForExistence(timeout: 30))
        app.tabBars.buttons["일정"].tap()
        let month = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+년 [0-9]+월")).firstMatch
        XCTAssertTrue(month.waitForExistence(timeout: 30))
        let previous = app.buttons["이전 달"]
        XCTAssertTrue(previous.isEnabled)
        XCTAssertGreaterThanOrEqual(previous.frame.width, 43.9)
        XCTAssertGreaterThanOrEqual(previous.frame.height, 43.9)
        let before = month.label
        tapPadding(of: previous, in: app, dx: 15, dy: 0)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in month.label != before }, object: nil)
        wait(for: [changed], timeout: 10)

        let myTeam = app.buttons["마이팀"]
        XCTAssertGreaterThanOrEqual(myTeam.frame.height, 43.9)
        tapPadding(of: myTeam, in: app, dx: 0, dy: 17)
        XCTAssertTrue(myTeam.isSelected)
        let opponentDay = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "상대팀")).firstMatch
        XCTAssertTrue(opponentDay.waitForExistence(timeout: 30))
        XCTAssertTrue(opponentDay.label.contains("홈 경기") || opponentDay.label.contains("원정 경기"))
        tapPadding(of: opponentDay, in: app, dx: 0, dy: 17)
        XCTAssertTrue(opponentDay.isSelected)

        app.tabBars.buttons["설정"].tap()
        let settings = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "경기 알림 설정")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(settings.frame.height, 43.9)
        tapPadding(of: settings, in: app, dx: 0, dy: 12)
        XCTAssertTrue(app.navigationBars["경기 알림 설정"].waitForExistence(timeout: 10))
    }

    @MainActor private func tapPadding(of element: XCUIElement, in app: XCUIApplication, dx: CGFloat, dy: CGFloat) {
        let frame = element.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX + dx, dy: frame.midY + dy)).tap()
    }
}
