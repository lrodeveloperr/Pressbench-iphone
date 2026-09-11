import XCTest

final class FirstUseFlowUITests: XCTestCase {
    func testFaceIDFirstViewportLayout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["PRESSBENCH_UI_TEST_USAGE_SERVICE"] = UUID().uuidString
        app.launchArguments += ["--pressbench-ui-test-reset", "--pressbench-ui-test-subscription-products", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch.waitForExistence(timeout: 8))
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(waitForHittable(moreTab, timeout: 20), "The native tab bar must settle inside the Face ID viewport")
        capture("face-id-home-safe-area")
        let settingsLink = app.buttons.matching(identifier: "pb.more.settings").firstMatch
        XCTAssertTrue(openTab("More", until: settingsLink, app: app))
        assertControlSurface(settingsLink, name: "More → Settings")
        tapEdge(settingsLink, horizontal: 0.9)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))
        let plan = app.buttons.matching(identifier: "pb.settings.plan").firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 4))
        plan.tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Subscribe · $119.99"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "pb.upgrade.annual").firstMatch.exists)
        capture("face-id-subscription-paywall")
        app.buttons["Cancel"].firstMatch.tap()
        let backup = app.buttons.matching(identifier: "pb.settings.backup").firstMatch
        XCTAssertTrue(backup.waitForExistence(timeout: 4))
        XCTAssertTrue(backup.isHittable, "Backup must remain in the first Settings viewport")
        assertControlSurface(backup, name: "Create Backup")

        let deleteLocalData = app.buttons.matching(identifier: "pb.settings.deleteLocalData").firstMatch
        makeHittable(deleteLocalData, in: app)
        assertControlSurface(deleteLocalData, name: "Delete local data")
        tapEdge(deleteLocalData, horizontal: 0.9)
        XCTAssertTrue(app.staticTexts["This permanently deletes machines, setups, runs, and local settings from this device. Your App Store purchase is not deleted."].waitForExistence(timeout: 4))
        app.buttons["Cancel"].firstMatch.tap()
        capture("face-id-prioritized-settings")
    }

    func testZeroPatienceFirstUseReturnsHomeThenOffersSetupStartChoices() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["PRESSBENCH_UI_TEST_USAGE_SERVICE"] = UUID().uuidString
        app.launchArguments += ["--pressbench-ui-test-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let firstUseAction = app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch
        XCTAssertTrue(firstUseAction.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Add your first machine"].exists)
        XCTAssertFalse(app.staticTexts["Ready to build your first setup"].exists)
        capture("01-next-action-only")

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(waitForHittable(moreTab, timeout: 8))
        let settingsLink = app.buttons.matching(identifier: "pb.more.settings").firstMatch
        XCTAssertTrue(openTab("More", until: settingsLink, app: app))
        assertControlSurface(settingsLink, name: "More → Settings")
        tapEdge(settingsLink, horizontal: 0.9)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20))
        let plan = app.buttons.matching(identifier: "pb.settings.plan").firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 4))
        assertControlSurface(plan, name: "Unlock PressBench Pro")
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].exists)
        XCTAssertTrue(app.staticTexts["Free runs left: 2 of 2"].exists)
        let backup = app.buttons.matching(identifier: "pb.settings.backup").firstMatch
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(backup.isHittable, "Backup must remain in the first Settings viewport")
        assertControlSurface(backup, name: "Create Backup")
        let restoreBackup = app.buttons.matching(identifier: "pb.settings.restoreBackup").firstMatch
        XCTAssertTrue(restoreBackup.exists)
        makeHittable(restoreBackup, in: app)
        XCTAssertTrue(restoreBackup.isHittable, "Import backup must remain directly available without sign-in")
        assertControlSurface(restoreBackup, name: "Import Backup")
        let restorePurchase = app.buttons.matching(identifier: "pb.settings.restorePurchase").firstMatch
        XCTAssertTrue(restorePurchase.exists)
        assertControlSurface(restorePurchase, name: "Restore Purchase")
        XCTAssertTrue(app.staticTexts["Back up your data"].exists)
        XCTAssertFalse(app.buttons["Continue with Apple"].exists)
        XCTAssertFalse(app.buttons["Sign out"].exists)
        XCTAssertFalse(app.buttons["Roll back last restore"].exists)
        XCTAssertFalse(app.buttons["Delete iCloud backup"].exists)
        XCTAssertFalse(app.staticTexts["Production Report"].exists)
        capture("03-prioritized-settings")

        app.tabBars.buttons["Home"].tap()
        app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch.tap()
        let catalogMachine = app.buttons.matching(identifier: "pb.machine.catalog").firstMatch
        XCTAssertTrue(catalogMachine.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons.matching(identifier: "pb.machine.manual").firstMatch.exists)
        XCTAssertFalse(app.textFields["Name"].exists)
        XCTAssertFalse(app.textFields["Platen *"].exists)
        capture("04-machine-start-choices")
        catalogMachine.tap()
        choose("pb.choice.machineBrand", option: "HTVRONT", app: app)
        choose("pb.choice.machineModel", option: "Auto Heat Press 2", app: app)
        XCTAssertFalse(app.textFields["Name"].exists)
        XCTAssertFalse(app.textFields["Platen *"].exists)
        capture("04-machine-brand-model-only")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Create a setup"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Setup"].exists)
        capture("05-machine-save-returns-home")
        app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "pb.setup.presetPicker").firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(identifier: "pb.setup.presetBasePicker").firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(identifier: "pb.setup.savedBase").firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(identifier: "pb.setup.manual").firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Use a preset as is"].exists)
        XCTAssertFalse(app.textFields["pb.setup.title"].exists)
        capture("05-setup-start-choices")

        app.buttons.matching(identifier: "pb.setup.presetPicker").firstMatch.tap()
        chooseSystemPicker(
            "pb.setup.presetMaterialFilter",
            option: "100% polyester T-shirt",
            app: app
        )
        let easyWeed = app.buttons.matching(identifier: "pb.setup.preset.Siser|EasyWeed").firstMatch
        XCTAssertTrue(waitForInteractable(easyWeed, timeout: 5))
        easyWeed.tap()
        let exactMaterial = app.buttons.matching(identifier: "pb.choice.material").firstMatch
        XCTAssertTrue(exactMaterial.waitForExistence(timeout: 5))
        XCTAssertFalse(exactMaterial.isEnabled, "An exact preset must lock its selected compatible material")
        XCTAssertTrue(app.staticTexts["100% polyester T-shirt"].exists)
        XCTAssertFalse(app.buttons.matching(identifier: "pb.choice.transfer").firstMatch.isEnabled)
        capture("05a-filtered-exact-preset")
        app.buttons["Cancel"].firstMatch.tap()
        let createSetupAgain = app.buttons.matching(identifier: "pb.home.firstUseAction").firstMatch
        XCTAssertTrue(waitForInteractable(createSetupAgain, timeout: 5))
        createSetupAgain.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "pb.setup.manual").firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "pb.setup.manual").firstMatch.tap()

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

        let generatedSetupTitle = "100% cotton T-shirt · Heat transfer vinyl (HTV) · HTVRONT Auto Heat Press 2"
        let startNewRun = app.buttons.matching(identifier: "pb.home.startRun").firstMatch
        XCTAssertTrue(waitForInteractable(startNewRun, timeout: 8))
        capture("06-ready-to-run")
        startNewRun.tap()
        let startRun = app.buttons.matching(identifier: "Start Run").firstMatch
        XCTAssertTrue(waitForInteractable(startRun, timeout: 8),
                      "A single runnable setup must open run configuration directly")
        XCTAssertFalse(app.buttons.matching(identifier: "pb.startRun.setup").firstMatch.exists)
        capture("06a-single-setup-direct-start")
        makeHittable(startRun, in: app)
        XCTAssertTrue(waitForInteractable(startRun, timeout: 5))
        startRun.tap()

        let confirmInstructions = app.buttons["Confirm instructions"]
        XCTAssertTrue(confirmInstructions.waitForExistence(timeout: 8))
        XCTAssertFalse(confirmInstructions.isEnabled)
        for check in ["instructions", "materials", "press", "platen", "artwork"] {
            let control = app.buttons.matching(identifier: "pb.preflight.\(check)").firstMatch
            XCTAssertTrue(waitForInteractable(control, timeout: 5), "Missing preflight check: \(check)")
            control.tap()
        }
        XCTAssertTrue(waitForInteractable(confirmInstructions, timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Free runs left: 0 of 2"].waitForExistence(timeout: 8))
        let cappedStartRun = app.buttons.matching(identifier: "pb.home.startRun").firstMatch
        XCTAssertTrue(waitForInteractable(cappedStartRun, timeout: 8))
        cappedStartRun.tap()
        XCTAssertTrue(app.staticTexts["Unlock PressBench Pro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Subscriptions are unavailable right now. Try again in a moment."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Subscribe"].isEnabled)
        let unavailablePurchase = app.buttons.matching(identifier: "pb.upgrade.purchase").firstMatch
        let retryProduct = app.buttons.matching(identifier: "pb.upgrade.retry").firstMatch
        let restorePurchaseFromPaywall = app.buttons.matching(identifier: "pb.upgrade.restore").firstMatch
        assertControlSurface(unavailablePurchase, name: "Unavailable purchase")
        assertControlSurface(retryProduct, name: "Retry product")
        assertControlSurface(restorePurchaseFromPaywall, name: "Restore purchase")
        capture("12-third-run-upgrade")

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
        let cappedRun = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", generatedSetupTitle)).firstMatch
        guard waitForHittable(cappedRun, timeout: 5) else {
            XCTFail("Completed run was not visible")
            return
        }
        tapEdge(cappedRun, horizontal: 0.9)
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
        let reportsLink = app.buttons.matching(identifier: "pb.more.reports").firstMatch
        XCTAssertTrue(openTab("More", until: reportsLink, app: app))
        XCTAssertTrue(waitForInteractable(reportsLink, timeout: 8))
        assertControlSurface(reportsLink, name: "More → Reports")
        tapEdge(reportsLink, horizontal: 0.1)
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
        XCTAssertFalse(app.staticTexts["Free runs left: 0 of 2"].exists)
        let proSettingsLink = app.buttons.matching(identifier: "pb.more.settings").firstMatch
        XCTAssertTrue(openTab("More", until: proSettingsLink, app: app))
        XCTAssertTrue(waitForHittable(proSettingsLink, timeout: 20))
        assertControlSurface(proSettingsLink, name: "More → Settings (Pro)")
        tapEdge(proSettingsLink, horizontal: 0.9)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Purchases & Pro Access"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Purchase details"].exists)
        capture("15-pro-unlocks-plan")
    }

    private func enter(_ value: String, in field: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !field.exists { scrollForward(in: app) }
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        for _ in 0..<4 where !app.keyboards.firstMatch.exists {
            makeHittable(field, in: app)
            field.tap()
            if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
                scrollForward(in: app)
            }
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists, "The text field must have keyboard focus before typing")
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
        XCTAssertTrue(choiceCancel.waitForNonExistence(timeout: 12),
                      "The choice sheet must close after selecting an option")
        XCTAssertTrue(waitForHittable(field, timeout: 12),
                      "The selected field must return as the active editor control")
    }

    private func chooseSystemPicker(_ identifier: String, option: String, app: XCUIApplication) {
        let field = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        makeHittable(field, in: app)
        field.tap()
        let button = app.buttons[option].firstMatch
        let text = app.staticTexts[option].firstMatch
        let choice = button.waitForExistence(timeout: 4) ? button : text
        XCTAssertTrue(choice.waitForExistence(timeout: 4), "Missing picker option: \(option)")
        makeHittable(choice, in: app)
        choice.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 8), "The picker must close after selection")
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
            assertControlSurface(button, name: identifier)
            tapEdge(button, horizontal: 0.9)
            return true
        }
        return false
    }

    private func assertControlSurface(_ element: XCUIElement, name: String) {
        XCTAssertTrue(element.exists, "Missing parent control: \(name)")
        XCTAssertTrue(element.isHittable, "Parent control is not hittable: \(name)")
        XCTAssertGreaterThanOrEqual(element.frame.width, 44, "Control is too narrow: \(name)")
        XCTAssertGreaterThanOrEqual(element.frame.height, 44, "Control is too short: \(name)")
    }

    private func tapEdge(_ element: XCUIElement, horizontal: CGFloat) {
        element.coordinate(withNormalizedOffset: CGVector(dx: horizontal, dy: 0.5)).tap()
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
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
