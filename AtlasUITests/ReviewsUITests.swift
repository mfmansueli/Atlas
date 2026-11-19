//
//  ReviewsUITests.swift
//  AtlasUITests
//

import XCTest

/// Ratings & Reviews (⌘8) in its DEBUG scenes (board 38; the sample
/// reviews, nothing reaches Apple): reviews translated with a suggested
/// reply, Show Original, editing and sending, Undo, Reply to All, the
/// filters, the Free plan and the Overview's card.
@MainActor
final class ReviewsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testEachReviewIsTranslatedWithASuggestedReplyInItsLanguage() {
        app.launch(debugScene: "rv")
        XCTAssertTrue(element("reviews.card.r-de1").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("reviews.card.title.r-de1")), "Sync broken since 1.3")
        XCTAssertTrue(app.staticTexts["Translated from German"].exists)
        let suggestion = text(of: element("reviews.suggestion.text.r-de1"))
        XCTAssertTrue(suggestion.hasPrefix("Danke, dass du das meldest"), suggestion)
        XCTAssertTrue(app.staticTexts["Suggested reply, in German"].exists)
        XCTAssertTrue(element("reviews.ratings").exists)
        XCTAssertTrue(element("reviews.theme.sync").exists)
        XCTAssertEqual(element("reviews.theme.action.sync").label, "Reply to All 38…")
        attach("rv")
    }

    func testShowOriginalShowsTheReviewAsWritten() {
        app.launch(debugScene: "rv")
        XCTAssertTrue(element("reviews.card.r-jp1").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("reviews.card.title.r-jp1")), "The yearly price is too high")
        element("reviews.card.translation.r-jp1").click()
        XCTAssertEqual(text(of: element("reviews.card.title.r-jp1")), "年額が高すぎる")
        XCTAssertTrue(app.staticTexts["Original, in Japanese"].exists)
        attach("rv-orig")
    }

    func testTheSwitchShowsEveryReviewAsWritten() {
        app.launch(debugScene: "rv")
        XCTAssertTrue(element("reviews.card.r-de1").waitForExistence(timeout: 15))
        element("reviews.translate").click()
        XCTAssertEqual(text(of: element("reviews.card.title.r-de1")), "Sync seit 1.3 kaputt")
    }

    func testSendReplyShowsItUnderTheReviewAndUndoTakesItBack() {
        app.launch(debugScene: "rv")
        XCTAssertTrue(element("reviews.suggestion.r-de1").waitForExistence(timeout: 15))
        element("reviews.suggestion.send.r-de1").click()
        let reply = element("reviews.reply.r-de1")
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        // "You replied Nov 16." or "16 Nov", as the Mac writes dates.
        let sent = NSPredicate(format: "value BEGINSWITH %@ AND value ENDSWITH %@", "You replied ", "Apple shows it under the review, usually within a day.")
        XCTAssertTrue(app.staticTexts.matching(sent).firstMatch.exists)
        XCTAssertTrue(element("reviews.reply.edit.r-de1").exists, "Edit stays available")
        attach("rv-sent")
        app.buttons["Undo"].firstMatch.click()
        XCTAssertTrue(element("reviews.suggestion.r-de1").waitForExistence(timeout: 10))
    }

    func testASuggestedReplyCanBeEditedBeforeSending() {
        app.launch(debugScene: "rv-edit")
        let editor = element("reviews.editor.text.r-jp1")
        XCTAssertTrue(editor.waitForExistence(timeout: 15))
        XCTAssertTrue((editor.value as? String ?? "").contains("¥600"), "\(String(describing: editor.value))")
        let meaning = "In English: Thank you for the kind review. There is a monthly plan too: you can choose it in Settings → Lumen Pro."
        XCTAssertTrue(app.staticTexts[meaning].exists)
        attach("rv-edit")
        element("reviews.editor.send.r-jp1").click()
        XCTAssertTrue(element("reviews.reply.r-jp1").waitForExistence(timeout: 10))
    }

    func testDismissKeepsTheReviewAndRestoreBringsTheSuggestionBack() {
        app.launch(debugScene: "rv")
        XCTAssertTrue(element("reviews.suggestion.r-de1").waitForExistence(timeout: 15))
        element("reviews.suggestion.dismiss.r-de1").click()
        XCTAssertTrue(element("reviews.card.restore.r-de1").waitForExistence(timeout: 5))
        XCTAssertFalse(element("reviews.suggestion.r-de1").exists)
        XCTAssertTrue(app.staticTexts["Suggested reply dismissed. The review still has no reply."].exists)
        element("reviews.card.restore.r-de1").click()
        XCTAssertTrue(element("reviews.suggestion.r-de1").waitForExistence(timeout: 5))
    }

    func testReplyToAllSendsOneMessagePerLanguage() {
        app.launch(debugScene: "rv-bulk")
        XCTAssertTrue(element("reviews.bulk").waitForExistence(timeout: 15))
        XCTAssertEqual(text(of: element("reviews.bulk.title")), "Reply to 38 reviews about iCloud sync since 1.3")
        XCTAssertEqual(element("reviews.bulk.send").label, "Send 38 Replies")
        attach("rv-bulk")
        // Without English: six reviews fewer. (A row near the top: the last ones need scrolling.)
        element("reviews.bulk.toggle.en").click()
        XCTAssertEqual(element("reviews.bulk.send").label, "Send 32 Replies")
        element("reviews.bulk.send").click()
        XCTAssertTrue(element("reviews.bulk").waitForNonExistence(timeout: 20))
        let sent = "32 replies sent in 6 languages. Apple shows them under the reviews, usually within a day."
        XCTAssertTrue(app.staticTexts[sent].waitForExistence(timeout: 5))
        // The German review of the group got its reply.
        XCTAssertTrue(element("reviews.reply.r-de1").waitForExistence(timeout: 5))
    }

    func testAllShowsOptionalRepliesAndAnEarlierReply() {
        app.launch(debugScene: "rv-all")
        XCTAssertTrue(element("reviews.card.r-us1").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["A reply is optional"].exists)
        attach("rv-all")
    }

    func testAGroupsShowReviewsFiltersTheList() {
        app.launch(debugScene: "rv")
        XCTAssertTrue(element("reviews.theme.action.widget").waitForExistence(timeout: 15))
        element("reviews.theme.action.widget").click()
        XCTAssertTrue(element("reviews.filter.theme").waitForExistence(timeout: 5))
        XCTAssertTrue(element("reviews.card.r-br1").exists)
        XCTAssertFalse(element("reviews.card.r-de1").exists)
        element("reviews.filter.theme.clear").click()
        XCTAssertTrue(element("reviews.card.r-de1").waitForExistence(timeout: 5))
    }

    func testFreeRepliesByHandAndLocksTheGroups() {
        app.launch(debugScene: "rv-free")
        XCTAssertTrue(element("reviews.card.r-de1").waitForExistence(timeout: 15))
        XCTAssertFalse(element("reviews.suggestion.r-de1").exists)
        XCTAssertTrue(element("reviews.themes.locked").exists)
        XCTAssertEqual(element("sidebar.section.reviews").label, "Reviews", "No suggested replies to count in Free")
        attach("rv-free")
        element("reviews.card.write.r-de1").click()
        let editor = element("reviews.editor.text.r-de1")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String ?? "", "", "Free starts from an empty reply")
    }

    /// 5.6.1: no marketing in a reply. The editor warns; Send Reply stays.
    func testAPromoCodeInAReplyIsWarned() {
        app.launch(debugScene: "rv-free")
        XCTAssertTrue(element("reviews.card.r-de1").waitForExistence(timeout: 15))
        element("reviews.card.write.r-de1").click()
        let editor = element("reviews.editor.text.r-de1")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertFalse(element("reviews.editor.guideline.r-de1").exists)
        editor.click()
        editor.typeText("Danke! Use code SPRING for 50% off.")
        let warning = element("reviews.editor.guideline.r-de1")
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: warning).contains("Guideline 5.6.1"), text(of: warning))
        XCTAssertTrue(element("reviews.editor.send.r-de1").isEnabled)
    }

    func testTheOverviewCardOpensReplyToAll() {
        app.launch(debugScene: "rv-overview")
        let card = element("overview.reviewsCard")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        element("overview.reviewsCard.replyToAll").click()
        XCTAssertTrue(element("reviews.bulk").waitForExistence(timeout: 15))
    }

    func testWithoutSuggestionsTheReviewsOfferWritingAndAsking() {
        app.launch(debugScene: "rv-none")
        XCTAssertTrue(element("reviews.card.write.r-de1").waitForExistence(timeout: 15))
        XCTAssertTrue(element("reviews.themes.empty").exists)
        XCTAssertTrue(element("reviews.ask").exists)
    }

    func testAFailedReadOffersToTryAgainAndARefusedReplySaysWhy() {
        app.launch(debugScene: "rv-error")
        XCTAssertTrue(element("reviews.error").waitForExistence(timeout: 15))
        app.terminate()
        app.launch(debugScene: "rv-refused")
        XCTAssertTrue(element("reviews.suggestion.send.r-de1").waitForExistence(timeout: 15))
        element("reviews.suggestion.send.r-de1").click()
        XCTAssertTrue(element("reviews.card.error.r-de1").waitForExistence(timeout: 10))
        XCTAssertTrue(element("reviews.suggestion.r-de1").exists, "Nothing was sent: the suggestion stays")
    }

    func testALanguageThatIsntDownloadedOffersTheDownload() {
        app.launch(debugScene: "rv-download")
        XCTAssertTrue(element("reviews.download").waitForExistence(timeout: 15))
        XCTAssertTrue(element("reviews.downloadLanguages").exists)
        XCTAssertEqual(text(of: element("reviews.card.title.r-jp1")), "年額が高すぎる")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A SwiftUI text's words are its value; a button's are its label.
    private func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
