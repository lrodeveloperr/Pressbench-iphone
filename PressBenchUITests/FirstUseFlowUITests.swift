import XCTest

final class FirstUseFlowUITests: XCTestCase {
    func testFaceIDFirstViewportLayout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--pressbench-ui-test-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to PressBench"].waitForExistence(timeout: 8))
        XCTAssertTrue(tapButton("pb.onboarding.continue", app: app, timeout: 20),
                      "The first onboarding action must settle inside the Face ID viewport")
        let acknowledgement = app.buttons.matching(identifier: "pb.onboarding.accept").firstMatch
        if !acknowledgement.waitForExistence(timeout: 8) {
            _ = tapButton("pb.onboarding.continue", app: app, timeout: 8)
        }
        XCTAssertTrue(acknowledgement.waitForExistence(timeout: 8))
        acknowledgement.tap()
        app.buttons.matching(identifier: "pb.onboarding.continue").firstMatch.tap()
        let skipBackup = app.buttons.matching(identifier: "pb.onboarding.skipBackup").firstMatch
        XCTAssertTrue(skipBackup.waitForExistence(timeout: 3))
        skipBackup.tap()

        XCTAssertTrue(app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch.waitForExistence(timeout: 8))
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(waitForHittable(moreTab, timeout: 20), "The native tab bar must settle inside the Face ID viewport")
        capture("face-id-home-safe-area")
        let settingsLink = app.staticTexts["Settings"].firstMatch
        XCTAssertTrue(openTab("More", until: settingsLink, app: app))
        settingsLink.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))
        let backup = app.descendants(matching: .any)["pb.settings.backup"]
        XCTAssertTrue(backup.waitForExistence(timeout: 4))
        XCTAssertTrue(backup.isHittable, "Backup must remain in the first Settings viewport")
        capture("face-id-prioritized-settings")
    }

    func testZeroPatienceFirstUseShowsOnlyNextActionAndChainsMachineToSetup() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--pressbench-ui-test-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to PressBench"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["pb.onboarding.temperatureUnit"].exists)
        XCTAssertTrue(app.buttons["°F"].exists)
        XCTAssertTrue(app.buttons["°C"].exists)
        XCTAssertTrue(app.buttons["°F"].isSelected)
        capture("01-onboarding")

        let preferencesContinue = app.buttons.matching(identifier: "pb.onboarding.continue").firstMatch
        XCTAssertTrue(preferencesContinue.waitForExistence(timeout: 3))
        preferencesContinue.tap()
        let acknowledgement = app.buttons.matching(identifier: "pb.onboarding.accept").firstMatch
        XCTAssertTrue(acknowledgement.waitForExistence(timeout: 3))
        acknowledgement.tap()
        let legalContinue = app.buttons.matching(identifier: "pb.onboarding.continue").firstMatch
        XCTAssertTrue(legalContinue.isEnabled)
        legalContinue.tap()

        let continueWithoutBackup = app.buttons.matching(identifier: "pb.onboarding.skipBackup").firstMatch
        XCTAssertTrue(continueWithoutBackup.waitForExistence(timeout: 3))
        continueWithoutBackup.tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }

        let firstUseAction = app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch
        XCTAssertTrue(firstUseAction.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Add your first machine"].exists)
        XCTAssertFalse(app.staticTexts["Ready to build your first setup"].exists)
        capture("02-next-action-only")

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(waitForHittable(moreTab, timeout: 8))
        moreTab.tap()
        let settingsLink = app.staticTexts["Settings"].firstMatch
        XCTAssertTrue(waitForHittable(settingsLink, timeout: 8))
        settingsLink.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))
        let plan = app.descendants(matching: .any)["pb.settings.plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 4))
        XCTAssertTrue(plan.isHittable)
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].exists)
        XCTAssertTrue(app.staticTexts["Free runs left: 5 of 5"].exists)
        let backup = app.descendants(matching: .any)["pb.settings.backup"]
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(backup.isHittable, "Backup must remain in the first Settings viewport")
        XCTAssertTrue(app.staticTexts["Back up your data"].exists)
        XCTAssertFalse(app.staticTexts["Production Report"].exists)
        capture("03-prioritized-settings")

        app.tabBars.buttons["Home"].tap()
        app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch.tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        capture("04-machine-required-fields")
        choose("pb.choice.platen", option: "15 × 15 in", app: app)
        XCTAssertEqual(name.value as? String, "15 × 15 in")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Setup"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["pb.setup.title"].exists)
        capture("05-chained-setup-editor")

        choose("pb.choice.material", option: "100% cotton T-shirt", app: app)
        choose("pb.choice.transfer", option: "Direct-to-film transfer (DTF)", app: app)
        enter("325", in: app.descendants(matching: .any)["pb.stage.temperature"].firstMatch, app: app)
        enter("1", in: app.descendants(matching: .any)["pb.stage.duration"].firstMatch, app: app)
        choose("pb.choice.pressure", option: "Medium", app: app)
        choose("pb.choice.source", option: "Supplier instructions", app: app)
        enter("S-1", in: app.descendants(matching: .any)["pb.setup.sourceReference"].firstMatch, app: app)
        let saveSetup = app.buttons.matching(identifier: "Save").firstMatch
        makeHittable(saveSetup, in: app)
        saveSetup.tap()

        let generatedSetupTitle = "100% cotton T-shirt · Direct-to-film transfer (DTF) · 15 × 15 in"
        let startNewRun = app.staticTexts["Start New Run"]
        XCTAssertTrue(startNewRun.waitForExistence(timeout: 8))
        capture("06-ready-to-run")
        startNewRun.tap()
        let setup = app.staticTexts[generatedSetupTitle].firstMatch
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
        capture("07-run-preflight")
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
        capture("08-clean-result")
        recordResult.tap()
        let correctRecord = app.buttons["Correct record"]
        XCTAssertTrue(correctRecord.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["1. Press"].exists)
        capture("09-completed-history")

        correctRecord.tap()
        let reason = app.descendants(matching: .any)
            .matching(identifier: "pb.correction.reason").firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        reason.tap(); reason.typeText("Audit check")
        app.buttons["Cancel"].firstMatch.tap()
        let discardCorrection = app.buttons.matching(identifier: "pb.correction.discard").firstMatch
        XCTAssertTrue(discardCorrection.waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))
        capture("10-correction-discard-guard")
        discardCorrection.tap()

        let deleteRecord = app.buttons["Delete record"]
        XCTAssertTrue(deleteRecord.waitForExistence(timeout: 5))
        deleteRecord.tap()
        XCTAssertTrue(app.staticTexts["Permanently delete “\(generatedSetupTitle)”? This cannot be undone."].waitForExistence(timeout: 3))
        capture("11-identified-delete-warning")
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
        capture("12-sixth-run-upgrade")

        app.buttons["Cancel"].firstMatch.tap()
        let runsTab = app.tabBars.buttons["Runs"]
        guard runsTab.waitForExistence(timeout: 5), runsTab.isHittable else {
            XCTFail("Runs tab is not available after closing the paywall")
            return
        }
        runsTab.tap()
        guard app.scrollViews["pb.runs.screen"].waitForExistence(timeout: 5) else {
            XCTFail("Runs screen did not open")
            return
        }
        let cappedRun = app.staticTexts[generatedSetupTitle].firstMatch
        guard cappedRun.waitForExistence(timeout: 5) else {
            XCTFail("Completed run was not visible")
            return
        }
        cappedRun.tap()
        let repeatSetup = app.buttons["Repeat this setup"]
        guard repeatSetup.waitForExistence(timeout: 5) else {
            XCTFail("Completed-run Repeat action was not visible")
            return
        }
        repeatSetup.tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        capture("13-capped-repeat-upgrade")

        app.terminate()
        app.launchArguments = ["--pressbench-ui-test-pro", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Start New Run"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["pb.ad.banner"].exists)
        XCTAssertFalse(app.staticTexts["Free runs left: 0 of 5"].exists)
        app.tabBars.buttons["More"].tap()
        let proSettingsLink = app.staticTexts["Settings"].firstMatch
        XCTAssertTrue(waitForHittable(proSettingsLink, timeout: 8))
        proSettingsLink.tap()
        XCTAssertTrue(app.staticTexts["Purchases & Pro Access"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Manage subscription"].exists)
        capture("14-pro-removes-ads-and-cap")
    }

    private func enter(_ value: String, in field: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !field.exists { scrollForward(in: app) }
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
        let otherChoice = app.buttons["Other"].firstMatch
        XCTAssertTrue(otherChoice.waitForExistence(timeout: 5))
        makeHittable(choice, in: app)
        choice.tap()
        XCTAssertTrue(otherChoice.waitForNonExistence(timeout: 5),
                      "The choice sheet must dismiss before the editor continues")
    }

    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { scrollForward(in: app) }
        XCTAssertTrue(element.isHittable)
    }

    private func scrollForward(in app: XCUIApplication) {
        app.swipeUp()
    }

    private func openTab(_ name: String, until destination: XCUIElement, app: XCUIApplication) -> Bool {
        for _ in 0..<3 {
            if destination.exists, destination.isHittable { return true }
            let tab = app.tabBars.buttons[name]
            guard waitForHittable(tab, timeout: 4) else { continue }
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if destination.waitForExistence(timeout: 4), destination.isHittable { return true }
        }
        return false
    }

    private func tapButton(_ identifier: String, app: XCUIApplication, timeout: TimeInterval) -> Bool {
        for _ in 0..<3 {
            let button = app.buttons.matching(identifier: identifier).firstMatch
            guard waitForHittable(button, timeout: timeout / 3) else { continue }
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return true
        }
        return false
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
