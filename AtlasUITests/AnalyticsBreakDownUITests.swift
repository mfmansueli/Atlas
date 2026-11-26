//
//  AnalyticsBreakDownUITests.swift
//  AtlasUITests
//

import XCTest

/// Board 92 in its DEBUG scenes (canned reports; nothing reaches Apple):
/// Break It Down's sortable columns, its inspector and the proceeds
/// banner, and a finding's jump to the Store Page and back to the same
/// Analytics view.
@MainActor
final class AnalyticsBreakDownUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testAColumnSortsDescendingThenAscendingAndSaysSo() {
        app.launch(debugScene: "an-bd")
        let downloads = element("analytics.breakdown.sort.downloadRate")
        XCTAssertTrue(downloads.waitForExistence(timeout: 15))
        XCTAssertFalse(downloads.label.contains("sorted"))
        downloads.click()
        XCTAssertTrue(downloads.label.contains("sorted descending"), downloads.label)
        downloads.click()
        XCTAssertTrue(downloads.label.contains("sorted ascending"), downloads.label)
        XCTAssertTrue(element("analytics.breakdown.legend").exists, "The legend is in the table's footer")
    }

    func testARowOpensTheInspectorAndItsCloseButtonClosesIt() {
        app.launch(debugScene: "an-bd")
        let row = element("analytics.breakdown.row.DE")
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertFalse(element("analytics.breakdown.inspector").exists)
        row.click()
        let inspector = element("analytics.breakdown.inspector")
        XCTAssertTrue(inspector.waitForExistence(timeout: 5))
        element("analytics.breakdown.inspector.close").click()
        XCTAssertTrue(inspector.waitForNonExistence(timeout: 5))
    }

    func testTheProceedsNumberOpensTerritoriesWithAClosableBanner() {
        app.launch(debugScene: "an-bd-proc")
        let banner = element("analytics.breakdown.proceedsBanner")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertTrue(element("analytics.breakdown.sort.proceeds").label.contains("sorted descending"))
        element("analytics.breakdown.proceedsBanner.close").click()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("analytics.breakdown.table").exists)
    }

    func testAFindingOpensTheStorePageAndBackToAnalyticsReturnsToWhatToTry() {
        app.launch(debugScene: "an-find")
        let finding = element("analytics.finding.territory.downloads.DE")
        XCTAssertTrue(finding.waitForExistence(timeout: 15))
        finding.descendants(matching: .any)["analytics.finding.action"].firstMatch.click()

        // The Store Page, saying where the person came from.
        XCTAssertTrue(element("workspace.storePage").waitForExistence(timeout: 10))
        let bar = element("analytics.origin")
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        element("analytics.origin.back").click()

        XCTAssertTrue(element("analytics.findings").waitForExistence(timeout: 10), "Back on What to Try, the view it came from")
        XCTAssertFalse(bar.exists)
    }

    func testThePriceChangeLeadsToPricingAndBackToAfterChanges() {
        app.launch(debugScene: "an-chg-price")
        let open = element("analytics.changes.openPricing")
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.click()
        XCTAssertTrue(element("analytics.origin").waitForExistence(timeout: 10))
        element("analytics.origin.back").click()
        XCTAssertTrue(element("analytics.changes").waitForExistence(timeout: 10), "Back on After Changes")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
