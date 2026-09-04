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
        app.buttons["°C"].tap()
        XCTAssertTrue(app.buttons["°C"].isSelected, "The temperature segment must change on its first tap")
        app.buttons["°F"].tap()
        XCTAssertTrue(app.buttons["°F"].isSelected, "The temperature segment must change back on its first tap")
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

        let firstUseAction = app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch
        XCTAssertTrue(firstUseAction.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Add your first machine"].exists)
        XCTAssertFalse(app.staticTexts["Ready to build your first setup"].exists)
        capture("02-next-action-only")

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(waitForHittable(moreTab, timeout: 8))
        let settingsLink = app.descendants(matching: .any)["pb.more.settings"].firstMatch
        XCTAssertTrue(openTab("More", until: settingsLink, app: app))
        settingsLink.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20))
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
        let moreDisclosure = app.buttons["More"].firstMatch
        XCTAssertTrue(waitForInteractable(moreDisclosure, timeout: 5))
        moreDisclosure.tap()
        let notesEditor = app.textViews["Notes"].firstMatch
        XCTAssertTrue(notesEditor.waitForExistence(timeout: 5),
                      "The full More row must expand on its first tap")
        moreDisclosure.tap()
        XCTAssertTrue(notesEditor.waitForNonExistence(timeout: 5),
                      "The full More row must collapse on its first tap")
        choose("pb.choice.platen", option: "15 × 15 in", app: app)
        XCTAssertEqual(name.value as? String, "15 × 15 in")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Setup"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["pb.setup.title"].exists)
        capture("05-chained-setup-editor")

        choose("pb.choice.material", option: "100% cotton T-shirt", app: app)
        choose("pb.choice.transfer", option: "Heat transfer vinyl (HTV)", app: app)
        enter("325", in: app.descendants(matching: .any)["pb.stage.temperature"].firstMatch, app: app)
        enter("1", in: app.descendants(matching: .any)["pb.stage.duration"].firstMatch, app: app)
        choose("pb.choice.pressure", option: "Medium", app: app)
        choose("pb.choice.source", option: "Supplier instructions", app: app)
        enter("S-1", in: app.descendants(matching: .any)["pb.setup.sourceReference"].firstMatch, app: app)
        let saveSetup = app.buttons.matching(identifier: "Save").firstMatch
        makeHittable(saveSetup, in: app)
        saveSetup.tap()

        let generatedSetupTitle = "100% cotton T-shirt · Heat transfer vinyl (HTV) · 15 × 15 in"
        let startNewRun = app.buttons.matching(identifier: "pb.home.startRun").firstMatch
        XCTAssertTrue(waitForInteractable(startNewRun, timeout: 8))
        capture("06-ready-to-run")
        startNewRun.tap()
        let exactRepeat = app.staticTexts["Exact repeat"]
        XCTAssertTrue(waitForHittable(exactRepeat, timeout: 8),
                      "A single runnable setup must bypass redundant setup selection")
        XCTAssertFalse(app.buttons.matching(identifier: "pb.startRun.setup").firstMatch.exists)
        capture("06a-single-setup-direct-start")
        exactRepeat.tap()
        let continueRun = app.buttons["Continue"].firstMatch
        makeHittable(continueRun, in: app)
        XCTAssertTrue(waitForInteractable(continueRun, timeout: 5))
        continueRun.tap()
        let startRun = app.buttons.matching(identifier: "Start Run").firstMatch
        makeHittable(startRun, in: app)
        XCTAssertTrue(waitForInteractable(startRun, timeout: 5))
        startRun.tap()

        let confirmInstructions = app.buttons["Confirm instructions"]
        XCTAssertTrue(waitForInteractable(confirmInstructions, timeout: 8))
        capture("07-run-preflight")
        confirmInstructions.tap()
        let startTimer = app.buttons["Start timer"]
        XCTAssertTrue(waitForInteractable(startTimer, timeout: 5))
        startTimer.tap()
        let firstPiecePassed = app.buttons["First piece passed"]
        XCTAssertTrue(waitForInteractable(firstPiecePassed, timeout: 8))
        firstPiecePassed.tap()

        let recordResult = app.buttons["Record result"]
        XCTAssertTrue(recordResult.waitForExistence(timeout: 5))
        makeHittable(recordResult, in: app)
        XCTAssertTrue(waitForInteractable(recordResult, timeout: 5))
        capture("08-clean-result")
        recordResult.tap()
        let correctRecord = app.buttons["Correct record"]
        XCTAssertTrue(correctRecord.waitForExistence(timeout: 8))
        makeHittable(correctRecord, in: app)
        XCTAssertTrue(waitForInteractable(correctRecord, timeout: 5))
        XCTAssertTrue(app.staticTexts["1. Press"].exists)
        capture("09-completed-history")

        correctRecord.tap()
        let reason = app.descendants(matching: .any)
            .matching(identifier: "pb.correction.reason").firstMatch
        for _ in 0..<8 where !reason.exists { scrollForward(in: app) }
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        makeHittable(reason, in: app)
        reason.tap(); reason.typeText("Audit check")
        let cancelCorrection = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(waitForHittable(cancelCorrection, timeout: 5))
        cancelCorrection.tap()
        let discardCorrection = app.buttons.matching(identifier: "pb.correction.discard").firstMatch
        XCTAssertTrue(waitForHittable(discardCorrection, timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))
        capture("10-correction-discard-guard")
        discardCorrection.tap()

        let deleteRecord = app.buttons["Delete record"]
        XCTAssertTrue(deleteRecord.waitForExistence(timeout: 5))
        makeHittable(deleteRecord, in: app)
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
        let cappedStartRun = app.buttons.matching(identifier: "pb.home.startRun").firstMatch
        XCTAssertTrue(waitForInteractable(cappedStartRun, timeout: 8))
        cappedStartRun.tap()
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
        guard waitForHittable(cappedRun, timeout: 5) else {
            XCTFail("Completed run was not visible")
            return
        }
        cappedRun.tap()
        let repeatSetup = app.buttons["Repeat this setup"]
        guard repeatSetup.waitForExistence(timeout: 5) else {
            XCTFail("Completed-run Repeat action was not visible")
            return
        }
        makeHittable(repeatSetup, in: app)
        guard waitForInteractable(repeatSetup, timeout: 5) else {
            XCTFail("Completed-run Repeat action was not tappable")
            return
        }
        repeatSetup.tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        capture("13-capped-repeat-upgrade")

        app.buttons["Cancel"].firstMatch.tap()
        let reportsLink = app.descendants(matching: .any)["pb.more.reports"].firstMatch
        XCTAssertTrue(openTab("More", until: reportsLink, app: app))
        XCTAssertTrue(waitForInteractable(reportsLink, timeout: 8))
        reportsLink.tap()
        XCTAssertTrue(app.navigationBars["Production Report"].waitForExistence(timeout: 8))
        let lockedPDF = app.buttons.matching(identifier: "pb.reports.pdf").firstMatch
        XCTAssertTrue(waitForInteractable(lockedPDF, timeout: 5))
        lockedPDF.tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        capture("14-free-report-requires-pro")

        app.terminate()
        app.launchArguments = ["--pressbench-ui-test-pro", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons.matching(identifier: "pb.home.startRun").firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Free runs left: 0 of 5"].exists)
        let proSettingsLink = app.descendants(matching: .any)["pb.more.settings"].firstMatch
        XCTAssertTrue(openTab("More", until: proSettingsLink, app: app))
        XCTAssertTrue(waitForHittable(proSettingsLink, timeout: 20))
        proSettingsLink.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Purchases & Pro Access"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Manage subscription"].exists)
        capture("15-pro-unlocks-plan")
    }

    func testDeleteLocalDataRespondsOnFirstTapAndCompletesOnce() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--pressbench-ui-test-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        completeOnboarding(in: app)

        let settingsLink = app.descendants(matching: .any)["pb.more.settings"].firstMatch
        XCTAssertTrue(openTab("More", until: settingsLink, app: app))
        settingsLink.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let delete = app.buttons.matching(identifier: "pb.settings.deleteLocalData").firstMatch
        makeHittable(delete, in: app)
        delete.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        let confirm = app.buttons.matching(identifier: "pb.settings.confirmDeleteLocalData").firstMatch
        XCTAssertTrue(waitForInteractable(confirm, timeout: 5), "One tap anywhere in the visible row must open confirmation")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Welcome to PressBench"].waitForExistence(timeout: 8),
                      "A single confirmation tap must delete local data and return to onboarding")
    }

    func testPrimaryTouchTargetRespondsAtLeftAndRightEdges() {
        for horizontalOffset in [0.12, 0.88] {
            let app = XCUIApplication()
            app.launchArguments = ["--pressbench-ui-test-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            let button = app.buttons.matching(identifier: "pb.onboarding.continue").firstMatch
            XCTAssertTrue(waitForInteractable(button, timeout: 8))
            button.coordinate(withNormalizedOffset: CGVector(dx: horizontalOffset, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons.matching(identifier: "pb.onboarding.accept").firstMatch.waitForExistence(timeout: 5),
                          "The full visible button width must respond on the first tap")
            app.terminate()
        }
    }

    private func completeOnboarding(in app: XCUIApplication) {
        let firstContinue = app.buttons.matching(identifier: "pb.onboarding.continue").firstMatch
        XCTAssertTrue(waitForInteractable(firstContinue, timeout: 8))
        firstContinue.tap()
        let acknowledgement = app.buttons.matching(identifier: "pb.onboarding.accept").firstMatch
        XCTAssertTrue(waitForInteractable(acknowledgement, timeout: 5))
        acknowledgement.tap()
        let legalContinue = app.buttons.matching(identifier: "pb.onboarding.continue").firstMatch
        XCTAssertTrue(waitForInteractable(legalContinue, timeout: 5))
        legalContinue.tap()
        let skip = app.buttons.matching(identifier: "pb.onboarding.skipBackup").firstMatch
        XCTAssertTrue(waitForInteractable(skip, timeout: 5))
        skip.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch.waitForExistence(timeout: 8))
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
        let choiceCancel = app.buttons.matching(identifier: "\(identifier).cancel").firstMatch
        XCTAssertTrue(choiceCancel.waitForExistence(timeout: 5))
        makeHittable(choice, in: app)
        choice.tap()
        let editorCancel = app.buttons.matching(identifier: "pb.editor.cancel").firstMatch
        XCTAssertTrue(waitForHittable(editorCancel, timeout: 12),
                      "The editor must return after the choice sheet closes")
    }

    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { scrollForward(in: app) }
        XCTAssertTrue(element.isHittable)
    }

    private func scrollForward(in app: XCUIApplication) {
        app.swipeUp()
    }

    private func openTab(_ name: String, until destination: XCUIElement, app: XCUIApplication) -> Bool {
        if destination.exists, destination.isHittable { return true }
        let tab = app.tabBars.buttons[name]
        guard waitForHittable(tab, timeout: 4) else { return false }
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return destination.waitForExistence(timeout: 4) && destination.isHittable
    }

    private func tapButton(_ identifier: String, app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        guard waitForHittable(button, timeout: timeout) else { return false }
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForInteractable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func capture(_ name: String) {
        auditVisibleButtonTargets(in: XCUIApplication(), screen: name)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Every visible, enabled app button on each audited production screen must
    /// expose Apple's minimum 44-by-44-point touchscreen target. Edge-specific
    /// tests separately prove that transparent left/right label space responds
    /// on the first tap.
    private func auditVisibleButtonTargets(in app: XCUIApplication, screen: String) {
        let systemSegmentFrames = app.segmentedControls.allElementsBoundByIndex.map(\.frame)
        let systemNavigationFrames = app.navigationBars.allElementsBoundByIndex.map(\.frame)
        for button in app.buttons.allElementsBoundByIndex where button.exists && button.isHittable && button.isEnabled {
            let frame = button.frame
            guard !frame.isEmpty else { continue }
            // UIKit exposes each segment's visual 32-point frame even though
            // the parent segmented control owns its hit testing. Those controls
            // are first-tap state-tested above instead of judged by glyph frame.
            if systemSegmentFrames.contains(where: { $0.intersects(frame) }) { continue }
            // UIKit likewise reports the visual label frame for navigation-title
            // and toolbar elements, while UINavigationBar owns the larger hit
            // region. Save/Cancel transitions are first-tap tested in the flow.
            if systemNavigationFrames.contains(where: { $0.intersects(frame) }) { continue }
            XCTAssertGreaterThanOrEqual(frame.width, 43.5,
                "Button \(button.label) [\(button.identifier)] is too narrow on \(screen): \(frame)")
            XCTAssertGreaterThanOrEqual(frame.height, 43.5,
                "Button \(button.label) [\(button.identifier)] is too short on \(screen): \(frame)")
        }
    }
}
