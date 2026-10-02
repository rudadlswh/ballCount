import XCTest

final class LandscapeLayoutTests: XCTestCase {
    @MainActor private func launchApp(largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-kbo_live_onboarding_completed", "YES"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        if !app.tabBars.buttons["설정"].waitForExistence(timeout: 8) {
            print(app.debugDescription)
            attach("시작-화면-진단")
        }
        XCTAssertTrue(app.tabBars.buttons["설정"].exists)
        return app
    }

    @MainActor func testAppearanceAndEveryTab() throws {
        let app = launchApp()
        var colors: [[UInt8]] = []
        for mode in ["라이트", "다크"] {
            app.tabBars.buttons["설정"].tap()
            let appearance = app.buttons["appearance.\(mode)"]
            XCTAssertTrue(appearance.waitForExistence(timeout: 10))
            appearance.tap()
            XCTAssertTrue(appearance.isSelected)
            for tab in ["home", "standings", "schedule", "attendance", "settings"] {
                tabButton(tab, in: app).tap()
                XCTAssertTrue(app.buttons["알림"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.buttons["알림"].isHittable)
                if tab == "home" { colors.append(try backgroundPixel(XCUIScreen.main.screenshot())) }
                attach("\(mode)-\(tab)")
            }
        }
        XCTAssertGreaterThan(Int(colors[0][0]) - Int(colors[1][0]), 150)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["홈"].waitForExistence(timeout: 60))
        XCTAssertEqual(try backgroundPixel(XCUIScreen.main.screenshot()), colors[1])
    }

    @MainActor func testFavoriteTeamUpdatesWhileThemeStaysUnified() throws {
        let app = launchApp()
        app.tabBars.buttons["설정"].tap()
        app.buttons["appearance.라이트"].tap()
        var colors: [[UInt8]] = []
        for team in ["한화 이글스", "삼성 라이온즈", "롯데 자이언츠"] {
            app.tabBars.buttons["설정"].tap()
            app.buttons["favoriteTeamSelection"].tap()
            let row = app.buttons.containing(.staticText, identifier: team).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            for _ in 0..<6 where !row.isHittable || row.frame.maxY >= app.tabBars.buttons["홈"].frame.minY {
                app.scrollViews.firstMatch.swipeUp()
            }
            row.tap()
            if !app.buttons["favoriteTeamSelection"].waitForExistence(timeout: 10) {
                print(app.debugDescription)
                attach("응원팀-변경-진단")
            }
            XCTAssertTrue(app.buttons["favoriteTeamSelection"].exists)
            app.tabBars.buttons["홈"].tap()
            let teamName = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", team),
                                                     object: app.buttons["favoriteTeamMenu"])
            wait(for: [teamName], timeout: 10)
            colors.append(try backgroundPixel(XCUIScreen.main.screenshot()))
        }
        XCTAssertEqual(colors[0], colors[1])
        XCTAssertEqual(colors[1], colors[2])
    }

    @MainActor func testStandingsKeepsTeamColumnFixedWhileStatsScroll() throws {
        let app = launchApp()
        app.tabBars.buttons["순위"].tap()
        let teamHeader = app.staticTexts["팀"]
        let statsScroll = app.scrollViews["standingsStatsScroll"]
        let statsHeader = statsScroll.staticTexts["승률"]
        XCTAssertTrue(teamHeader.waitForExistence(timeout: 60))
        XCTAssertTrue(statsHeader.exists)
        XCTAssertLessThan(teamHeader.frame.maxX, statsScroll.frame.minX)
        let teamX = teamHeader.frame.minX
        let statsX = statsHeader.frame.minX
        statsScroll.swipeLeft()
        XCTAssertEqual(teamHeader.frame.minX, teamX, accuracy: 1)
        XCTAssertLessThan(statsHeader.frame.minX, statsX - 10)
        attach("순위-가로스크롤")
    }

    @MainActor func testTabContentStaysWithinSafeAreasAfterRotation() throws {
        let app = launchApp()
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let rotation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (app.frame.width > app.frame.height) == (orientation != .portrait)
            }, object: nil)
            wait(for: [rotation], timeout: 10)
            for tab in ["home", "standings", "schedule", "attendance", "settings"] {
                let button = tabButton(tab, in: app)
                XCTAssertTrue(button.isHittable)
                button.tap()
                let bell = app.buttons["알림"]
                XCTAssertTrue(bell.waitForExistence(timeout: 10))
                // Each screen remains vertically scrollable when the landscape viewport is short.
                if !bell.isHittable { app.scrollViews.firstMatch.swipeDown() }
                XCTAssertTrue(bell.isHittable)
                XCTAssertGreaterThanOrEqual(bell.frame.minY, app.frame.minY)
                XCTAssertLessThan(bell.frame.maxY, button.frame.minY)
                attach("\(tab)-회전-\(orientation.rawValue)")
            }
        }
    }

    @MainActor func testAccessibilityTextKeepsAllStatsReachableAfterRotation() throws {
        let app = launchApp(largeText: true)
        defer { XCUIDevice.shared.orientation = .portrait }
        app.tabBars.buttons["순위"].tap()
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let table = app.scrollViews["standingsTable"]
            XCTAssertTrue(table.waitForExistence(timeout: 60))
            let team = table.staticTexts["팀"]
            for _ in 0..<8 {
                let bottom = app.tabBars.buttons["홈"].frame.minY - 20
                if team.frame.minY > 60 && team.frame.maxY < bottom { break }
                let startY = (60 + bottom) / 2
                let desiredY = max(90, app.frame.height * 0.2)
                let endY = min(bottom - 10, max(70, startY + desiredY - team.frame.midY))
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: startY))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: endY)))
            }
            for _ in 0..<8 where !table.staticTexts["연속"].isHittable {
                let y = team.frame.midY - app.frame.minY
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: table.frame.maxX - 20, dy: y))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: table.frame.minX + 20, dy: y)))
            }
            if !table.staticTexts["연속"].isHittable { print(app.debugDescription); attach("큰글씨-진단") }
            XCTAssertTrue(table.staticTexts["연속"].isHittable)
            for _ in 0..<8 where !table.staticTexts["팀"].isHittable {
                let y = table.staticTexts["연속"].frame.midY - app.frame.minY
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: table.frame.minX + 20, dy: y))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: table.frame.maxX - 20, dy: y)))
            }
            XCTAssertTrue(table.staticTexts["팀"].isHittable)
            attach("큰글씨-순위-\(orientation.rawValue)")
        }
    }

    @MainActor private func tabButton(_ tab: String, in app: XCUIApplication) -> XCUIElement {
        let labels = ["home": "홈", "standings": "순위", "schedule": "일정", "attendance": "직관", "settings": "설정"]
        return app.tabBars.buttons[labels[tab]!]
    }

    @MainActor private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func backgroundPixel(_ screenshot: XCUIScreenshot) throws -> [UInt8] {
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: 4, y: image.height / 2, width: 1, height: 1)))
        var rgba = [UInt8](repeating: 0, count: 4)
        try rgba.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return Array(rgba.prefix(3))
    }
}
