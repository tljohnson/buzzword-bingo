import XCTest

final class BoardUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testBoardWinSettingsAndRestoration() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["mode-quick"].waitForExistence(timeout: 10))
        app.buttons["mode-quick"].tap()
        app.swipeUp()
        app.buttons["new-board"].tap()
        if app.buttons["Start New Board"].waitForExistence(timeout: 1) {
            app.buttons["Start New Board"].tap()
        }
        app.swipeDown()
        for index in 0..<5 { app.buttons["tile-\(index)"].tap() }
        XCTAssertTrue(app.descendants(matching: .any)["bingo-banner"].waitForExistence(timeout: 2))
        let win = XCTAttachment(screenshot: app.screenshot())
        win.name = "Bingo celebration"
        win.lifetime = .keepAlways
        add(win)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tile-0"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["bingo-banner"].exists)
        app.buttons["settings"].tap()
        XCTAssertTrue(app.switches["Satisfying pops"].waitForExistence(timeout: 3))
        app.switches["Satisfying pops"].tap()
        app.buttons["Done"].tap()
        app.buttons["mode-daily"].tap()
        XCTAssertTrue(app.staticTexts["The daily stand-up"].exists)
        app.buttons["mode-quick"].tap()
        XCTAssertTrue(app.buttons["tile-0"].isSelected)
        app.buttons["statistics"].tap()
        XCTAssertTrue(app.staticTexts["Boards with bingo"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
    }

    func testLargeTextLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 10))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["new-board"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessibility text layout"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
