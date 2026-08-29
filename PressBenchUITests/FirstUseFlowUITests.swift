import XCTest

final class FirstUseFlowUITests: XCTestCase {
    func testZeroPatienceFirstUseShowsOnlyNextActionAndChainsMachineToSetup() {
        let app = XCUIApplication()
        app.launchArguments += ["--pressbench-ui-test-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to PressBench"].waitForExistence(timeout: 8))
        capture("01-onboarding")
        for label in [
            "I agree to the Terms of Use",
            "I have read and acknowledge the Safety Notice",
            "I have reviewed the Privacy Policy"
        ] {
            let acknowledgement = app.buttons[label]
            makeHittable(acknowledgement, in: app)
            acknowledgement.tap()
        }

        let continueWithoutBackup = app.buttons["Continue without signing in"]
        XCTAssertTrue(continueWithoutBackup.waitForExistence(timeout: 3))
        makeHittable(continueWithoutBackup, in: app)
        continueWithoutBackup.tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }

        XCTAssertTrue(app.staticTexts["Ready to build your first setup"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["1. Add your first machine"].exists)
        XCTAssertFalse(app.staticTexts["2. Create a setup"].exists)
        XCTAssertFalse(app.staticTexts["3. Record a run"].exists)
        capture("02-next-action-only")

        app.staticTexts["1. Add your first machine"].tap()
        let name = app.textFields["Name *"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        capture("03-machine-required-fields")
        enter("Main Press", in: name, app: app)
        choose("pb.choice.platen", option: "15 × 15 in", app: app)
        app.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Setup *"].exists)
        capture("04-chained-setup-editor")

        enter("Quick Tee", in: app.textFields["Setup *"], app: app)
        choose("pb.choice.material", option: "100% cotton T-shirt", app: app)
        choose("pb.choice.transfer", option: "Direct-to-film transfer (DTF)", app: app)
        enter("325", in: app.textFields["Temperature *"], app: app)
        enter("1", in: app.textFields["Duration (seconds) *"], app: app)
        choose("pb.choice.pressure", option: "Medium", app: app)
        choose("pb.choice.source", option: "Supplier instructions", app: app)
        enter("S-1", in: app.textFields["Reference *"], app: app)
        let saveSetup = app.buttons.matching(identifier: "Save").firstMatch
        makeHittable(saveSetup, in: app)
        saveSetup.tap()

        let startNewRun = app.staticTexts["Start New Run"]
        XCTAssertTrue(startNewRun.waitForExistence(timeout: 8))
        capture("05-ready-to-run")
        startNewRun.tap()
        let setup = app.staticTexts["Quick Tee"].firstMatch
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        setup.tap()
        let exactRepeat = app.staticTexts["Exact repeat"]
        XCTAssertTrue(exactRepeat.waitForExistence(timeout: 5))
        exactRepeat.tap()
        app.buttons["Continue"].tap()
        let startRun = app.buttons.matching(identifier: "Start Run").firstMatch
        XCTAssertTrue(startRun.waitForExistence(timeout: 5))
        startRun.tap()

        let confirmInstructions = app.buttons["Confirm instructions"]
        XCTAssertTrue(confirmInstructions.waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["pb.ad.banner"].exists)
        capture("06-run-preflight")
        confirmInstructions.tap()
        let startTimer = app.buttons["Start timer"]
        XCTAssertTrue(startTimer.waitForExistence(timeout: 5))
        startTimer.tap()
        let firstPiecePassed = app.buttons["First piece passed"]
        expectation(for: NSPredicate(format: "exists == true AND enabled == true"), evaluatedWith: firstPiecePassed)
        waitForExpectations(timeout: 8)
        firstPiecePassed.tap()

        let recordResult = app.buttons["Record result"]
        XCTAssertTrue(recordResult.waitForExistence(timeout: 5))
        capture("07-clean-result")
        recordResult.tap()
        let correctRecord = app.buttons["Correct record"]
        XCTAssertTrue(correctRecord.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["1. Press"].exists)
        capture("08-completed-history")

        correctRecord.tap()
        let reason = app.textViews.matching(identifier: "pb.correction.reason").firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        reason.tap(); reason.typeText("Audit check")
        app.buttons["Cancel"].firstMatch.tap()
        let discardCorrection = app.buttons.matching(identifier: "pb.correction.discard").firstMatch
        XCTAssertTrue(discardCorrection.waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))
        capture("09-correction-discard-guard")
        discardCorrection.tap()

        let deleteRecord = app.buttons["Delete record"]
        XCTAssertTrue(deleteRecord.waitForExistence(timeout: 5))
        deleteRecord.tap()
        XCTAssertTrue(app.staticTexts["Permanently delete “Quick Tee”? This cannot be undone."].waitForExistence(timeout: 3))
        capture("10-identified-delete-warning")
        app.buttons["Cancel"].firstMatch.tap()

        app.terminate()
        app.launchArguments = [
            "--pressbench-ui-test-limit-reached",
            "--pressbench-ui-test-product-unavailable",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Free runs left: 0 of 5"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["pb.ad.banner"].waitForExistence(timeout: 5))
        app.staticTexts["Start New Run"].tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["The subscription is unavailable right now. Try again in a moment."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Subscribe"].isEnabled)
        capture("11-sixth-run-upgrade")

        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Runs"].tap()
        let cappedRun = app.staticTexts["Quick Tee"].firstMatch
        XCTAssertTrue(cappedRun.waitForExistence(timeout: 5))
        cappedRun.tap()
        let repeatSetup = app.buttons["Repeat this setup"]
        XCTAssertTrue(repeatSetup.waitForExistence(timeout: 5))
        repeatSetup.tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        capture("12-capped-repeat-upgrade")

        app.terminate()
        app.launchArguments = ["--pressbench-ui-test-pro", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Start New Run"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["pb.ad.banner"].exists)
        XCTAssertFalse(app.staticTexts["Free runs left: 0 of 5"].exists)
        capture("13-pro-removes-ads-and-cap")
    }

    private func enter(_ value: String, in field: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !field.exists { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        makeHittable(field, in: app)
        field.tap()
        field.typeText(value)
        let dismissKeyboard = app.buttons.matching(identifier: "pb.keyboard.dismiss").firstMatch
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 2))
        XCTAssertTrue(dismissKeyboard.isHittable)
        dismissKeyboard.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))
    }

    private func choose(_ identifier: String, option: String, app: XCUIApplication) {
        let field = app.buttons.matching(identifier: identifier).firstMatch
        makeHittable(field, in: app)
        field.tap()
        let choice = app.buttons[option].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 4))
        makeHittable(choice, in: app)
        choice.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 4))
    }

    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
