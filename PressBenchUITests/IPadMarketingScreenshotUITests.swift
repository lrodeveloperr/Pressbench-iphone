import XCTest

final class IPadMarketingScreenshotUITests: XCTestCase {
    func testHomeOverview() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launchEnvironment["PRESSBENCH_UI_TEST_USAGE_SERVICE"] = UUID().uuidString
        app.launchArguments = [
            "--pressbench-ui-test-reset",
            "--pressbench-ipad-marketing-screenshot",
            "--pressbench-ui-test-pro",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        let startRun = app.buttons.matching(identifier: "pb.home.startRun").firstMatch
        _ = startRun.waitForExistence(timeout: 12)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "pressbench-ipad-home-overview"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(startRun.exists)
        XCTAssertTrue(app.staticTexts["Recent setups"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["First-pass yield"].exists)
        XCTAssertTrue(app.staticTexts["Waste rate"].exists)
    }
}
