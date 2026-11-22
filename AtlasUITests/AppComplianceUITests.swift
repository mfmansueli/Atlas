//
//  AppComplianceUITests.swift
//  AtlasUITests
//

import XCTest

/// App Information → App Compliance, driven through the `info-comp*` DEBUG
/// scenes (sample data, simulated App Store Connect; nothing leaves the
/// Mac): Lumen Journal has no trader status in the EU, no ICP Filing
/// Number in China mainland, and Health & Fitness as a category.
@MainActor
final class AppComplianceUITests: XCTestCase {
    private var app: XCUIApplication!
    private let lumen = "6450000001"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testThePageSaysWhatNeedsThePerson() {
        launch(scene: "info-comp")
        XCTAssertTrue(element("appInformation.appCompliance").waitForExistence(timeout: 10))
        XCTAssertTrue(pageRowSays("5 need you"), rowLabel)
        XCTAssertTrue(value(of: "appInformation.compliance.headline").hasPrefix("5 need your answer · 1 checked."))
        XCTAssertTrue(element("appInformation.compliance.trader.question").exists)
        XCTAssertTrue(app.buttons["appInformation.compliance.icp.addNumber"].exists)
        XCTAssertEqual(value(of: "appInformation.compliance.vietnamGameLicense.title"), "Vietnam Game License · not needed")
        // Compliance takes no suggestions: no Accept All on this page.
        XCTAssertFalse(app.buttons["appInformation.acceptAll"].exists)
    }

    func testThePageIsReachedFromThePageColumn() {
        launch(scene: "info-general")
        XCTAssertTrue(element("appInformation.general").waitForExistence(timeout: 10))
        element("appInformation.pageRow.appCompliance").click()
        XCTAssertTrue(element("appInformation.appCompliance").waitForExistence(timeout: 5))
        XCTAssertTrue(element("appInformation.compliance.banner").exists)
    }

    func testDecidingTraderShowsWhatIsLeftForAppStoreConnect() {
        launch(scene: "info-comp")
        let accept = app.buttons["appInformation.compliance.trader.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10))
        accept.click()

        XCTAssertTrue(element("appInformation.compliance.trader.answered").waitForExistence(timeout: 5))
        XCTAssertTrue(value(of: "appInformation.compliance.trader.answer").hasPrefix("Trader, with these details."))
        showThePreview()
        XCTAssertTrue(value(of: "appInformation.preview.trader.details").hasPrefix("Northpier Studio Ltd"))
        XCTAssertTrue(pageRowSays("4 need you"), rowLabel)

        app.buttons["appInformation.compliance.trader.change"].click()
        XCTAssertTrue(element("appInformation.compliance.trader.question").waitForExistence(timeout: 5))
        XCTAssertTrue(pageRowSays("5 need you"), rowLabel)
    }

    func testTheTraderDetailsCanBeEditedBeforeDeciding() {
        launch(scene: "info-comp")
        let edit = app.buttons["appInformation.compliance.trader.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.click()
        let name = app.textFields["appInformation.compliance.trader.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Northpier Labs GmbH")
        app.buttons["appInformation.compliance.trader.done"].click()
        XCTAssertTrue(app.buttons["appInformation.compliance.trader.edit"].waitForExistence(timeout: 5))
        XCTAssertEqual(value(of: "appInformation.compliance.trader.name"), "Northpier Labs GmbH")
    }

    func testAnICPFilingNumberIsCheckedForItsFormat() {
        launch(scene: "info-comp")
        let addNumber = app.buttons["appInformation.compliance.icp.addNumber"]
        XCTAssertTrue(addNumber.waitForExistence(timeout: 10))
        reveal(addNumber)
        addNumber.click()
        let field = app.textFields["appInformation.compliance.icp.number"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        reveal(field)
        field.click()
        field.typeText("ICP 123")
        XCTAssertTrue(element("appInformation.compliance.icp.malformed").waitForExistence(timeout: 5))
        XCTAssertFalse(element("appInformation.compliance.icp.checked").exists)
    }

    func testStoppingSalesInChinaWaitsInReviewAndPush() {
        launch(scene: "info-comp")
        let stopSelling = app.buttons["appInformation.compliance.icp.stopSelling"]
        XCTAssertTrue(stopSelling.waitForExistence(timeout: 10))
        reveal(stopSelling)
        stopSelling.click()
        XCTAssertTrue(element("appInformation.compliance.icp.stops").waitForExistence(timeout: 5))
        XCTAssertTrue(pageRowSays("2 need you"), rowLabel)
        XCTAssertTrue(pageRowSays("not pushed"), rowLabel)

        app.buttons["workspace.reviewPushButton"].click()
        XCTAssertTrue(element("review.row.appInformation.\(lumen).appCompliance.availability.CHN").waitForExistence(timeout: 5))
    }

    func testEverythingAnsweredLeavesWhatIsForAppStoreConnect() {
        launch(scene: "info-comp-done")
        XCTAssertTrue(element("appInformation.compliance.trader.answered").waitForExistence(timeout: 10))
        XCTAssertTrue(pageRowSays("3 to finish at Apple"), rowLabel)
        XCTAssertTrue(value(of: "appInformation.compliance.headline").hasPrefix("3 to enter in App Store Connect · 3 checked."))
        XCTAssertEqual(value(of: "appInformation.compliance.medicalDevice.title"), "Regulated Medical Devices · declared")

        // A link-style button is a link to XCUITest, not a button.
        let change = element("appInformation.compliance.medicalDevice.change")
        reveal(change)
        change.click()
        XCTAssertTrue(app.buttons["appInformation.compliance.medicalDevice.markDeclared"].waitForExistence(timeout: 5))
        XCTAssertTrue(pageRowSays("1 needs you"), rowLabel)
    }

    func testAnAssistantsAnswersWaitOnTheirCardsUntilAccepted() {
        launch(scene: "info-comp-suggested")
        let traderAnswer = "appInformation.compliance.traderStatus.suggestion.answer"
        XCTAssertTrue(element(traderAnswer).waitForExistence(timeout: 10))
        XCTAssertEqual(value(of: traderAnswer), "Trader, with these details")
        XCTAssertTrue(pageRowSays("5 need you · 5 suggested"), rowLabel)
        XCTAssertTrue(element("appInformation.compliance.suggestions").exists)
        // Suggested, never taken by Accept All.
        XCTAssertFalse(app.buttons["appInformation.acceptAll"].exists)

        app.buttons["appInformation.compliance.traderStatus.suggestion.accept"].click()
        XCTAssertTrue(element("appInformation.compliance.trader.answered").waitForExistence(timeout: 5))
        showThePreview()
        XCTAssertTrue(value(of: "appInformation.preview.trader.details").contains("14 Harbour Road"))
        XCTAssertTrue(pageRowSays("4 need you · 4 suggested"), rowLabel)

        let dismiss = app.buttons["appInformation.compliance.medicalDevice.suggestion.dismiss"]
        reveal(dismiss)
        dismiss.click()
        XCTAssertFalse(element("appInformation.compliance.medicalDevice.suggestion").waitForExistence(timeout: 2))
        XCTAssertTrue(pageRowSays("4 need you · 3 suggested"), rowLabel)
    }

    func testChinaMainlandsAIDeclarationTakesItsFiling() {
        launch(scene: "info-comp")
        let yes = app.buttons["appInformation.compliance.aiGeneratedContent.yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 10))
        reveal(yes)
        yes.click()

        let number = app.textFields["appInformation.compliance.ai.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        let declare = app.buttons["appInformation.compliance.aiGeneratedContent.markDeclared"]
        XCTAssertFalse(declare.isEnabled, "A Yes needs its filing first")
        number.click()
        number.typeText("Shanghai-LumenReflect-202603120001")
        let name = app.textFields["appInformation.compliance.ai.name"]
        name.click()
        name.typeText("Lumen Reflect")
        XCTAssertTrue(value(of: "appInformation.compliance.aiGeneratedContent.detail").contains("number Shanghai-LumenReflect-202603120001"))
        XCTAssertTrue(declare.isEnabled)

        reveal(declare)
        declare.click()
        XCTAssertEqual(value(of: "appInformation.compliance.aiGeneratedContent.title"), "AI Generated or Synthetic Content · declared")
    }

    /// App Store Connect asks China mainland's two declarations of every
    /// app: one not sold there starts at No, ready to mark as declared,
    /// with no Stop Selling choice.
    func testOutsideChinaMainlandBothAreStillAskedWithNo() {
        launch(scene: "info-comp-outside-china")
        let declare = app.buttons["appInformation.compliance.securityAssessment.markDeclared"]
        XCTAssertTrue(declare.waitForExistence(timeout: 10))
        XCTAssertTrue(value(of: "appInformation.compliance.securityAssessment.detail").contains("even one not sold in China mainland"))
        XCTAssertTrue(app.buttons["appInformation.compliance.aiGeneratedContent.no"].exists)
        XCTAssertFalse(app.buttons["appInformation.compliance.aiGeneratedContent.stopSelling"].exists)
        XCTAssertTrue(value(of: "appInformation.compliance.headline").hasPrefix("2 need your answer · 2 to enter in App Store Connect"))
        XCTAssertTrue(declare.isEnabled)

        reveal(declare)
        declare.click()
        XCTAssertEqual(value(of: "appInformation.compliance.securityAssessment.title"), "Security Assessment · declared")
    }

    // MARK: - Helpers

    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    /// The App Store preview shows beside a page 760 pt wide or more: in
    /// the test's 1200 pt window, only with the sidebar hidden.
    private func showThePreview() {
        guard !element("appInformation.preview.trader").exists else { return }
        app.typeKey("s", modifierFlags: [.control, .command])
        XCTAssertTrue(element("appInformation.preview.trader").waitForExistence(timeout: 5), "The preview shows with the sidebar hidden")
    }

    /// The App Compliance row in the page column, whose label carries its
    /// status: "App Compliance, 5 need you".
    private var rowLabel: String { element("appInformation.pageRow.appCompliance").label }

    private func pageRowSays(_ status: String) -> Bool {
        let row = element("appInformation.pageRow.appCompliance")
        let says = NSPredicate(format: "label CONTAINS %@", status)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: says, object: row)], timeout: 5) == .completed
    }

    /// A SwiftUI `Text` exposes its string as its value on macOS, not its
    /// label.
    private func value(of identifier: String) -> String {
        let text = element(identifier)
        guard text.waitForExistence(timeout: 5) else { return "" }
        return text.value as? String ?? ""
    }

    /// Scrolls the page until `target` is fully in view, so a click on a
    /// lower card lands inside the window.
    private func reveal(_ target: XCUIElement) {
        let page = element("appInformation.page")
        guard page.exists else { return }
        var tries = 0
        while tries < 12 {
            if target.frame.minY >= page.frame.minY, target.frame.maxY <= page.frame.maxY - 8 { return }
            page.scroll(byDeltaX: 0, deltaY: target.frame.minY < page.frame.minY ? 200 : -200)
            tries += 1
        }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
