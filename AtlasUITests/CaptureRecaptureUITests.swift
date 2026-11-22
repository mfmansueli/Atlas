//
//  CaptureRecaptureUITests.swift
//  AtlasUITests
//

import AppKit
import XCTest

/// Redoing only some captures, on `StudioDebugRecapture`'s scenes: Claude
/// Code's request in Screenshots (Accept opens the capture-only run,
/// Decline drops it), and in Screenshots → Captures choosing captures (a
/// row, a column, ⌘-click), the Out of date label and Replace…. Each test
/// attaches the window's screenshot.
@MainActor
final class CaptureRecaptureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - The request

    func testAcceptingTheRequestOpensTheCaptureOnlyRun() {
        app.launch(debugScene: "ap-recapture-request")
        let banner = element("screenshots.recaptureRequest")
        XCTAssertTrue(banner.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts.matching(Self.says("wants to redo")).firstMatch.exists)
        attachScreenshot("Screenshots · Claude Code's request")

        element("screenshots.recaptureRequest.accept").click()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        let title = element("autopilot.guided.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The Autopilot sheet opens on the run")
        XCTAssertTrue(text(of: title).hasPrefix("Redoing"), text(of: title))
        attachScreenshot("Making it · capture-only run")
    }

    /// Alba's case: no Autopilot run was saved, only the set's captures.
    /// Accept still opens the capture-only run, made from them.
    func testAcceptingARequestWithNoPreviousRunOpensTheCaptureOnlyRun() {
        app.launch(debugScene: "ap-recapture-no-run")
        let banner = element("screenshots.recaptureRequest")
        XCTAssertTrue(banner.waitForExistence(timeout: 20), "The request waits though the app has no run")
        XCTAssertTrue(app.staticTexts.matching(Self.says("wants to redo")).firstMatch.exists)
        attachScreenshot("Screenshots · request with no previous run")

        element("screenshots.recaptureRequest.accept").click()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("screenshots.notice").exists, "No “has no Autopilot run” notice")
        let title = element("autopilot.guided.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The Autopilot sheet opens on the run made from the captures")
        XCTAssertTrue(text(of: title).hasPrefix("Redoing"), text(of: title))
        attachScreenshot("Making it · capture-only run from the set's captures")
    }

    /// Alba's pr-40a1e4a1: the pretend Mac has the iOS 27.2 runtime but no
    /// iPhone Duo simulator. Accept opens the run, Atlas makes the
    /// simulator itself, and no problem card waits for the person.
    func testAcceptingMakesTheMissingDuoSimulatorAndTheRunGoesOn() {
        app.launch(debugScene: "ap-recapture-make-duo")
        let banner = element("screenshots.recaptureRequest")
        XCTAssertTrue(banner.waitForExistence(timeout: 20))
        attachScreenshot("Screenshots · request for iPhone Duo's captures")

        element("screenshots.recaptureRequest.accept").click()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        let title = element("autopilot.guided.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The Autopilot sheet opens on the run")
        XCTAssertTrue(text(of: title).hasPrefix("Redoing"), text(of: title))

        let details = element("autopilot.guided.making.details")
        XCTAssertTrue(details.waitForExistence(timeout: 10), "The run's log has entries")
        details.click()
        let log = element("autopilot.log")
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        let made = "iPhone Duo: simulator made on iOS 27.2"
        let deadline = Date.now.addingTimeInterval(15)
        while !text(of: log).contains(made), Date.now < deadline {
            RunLoop.current.run(until: .now.addingTimeInterval(0.5))
        }
        XCTAssertTrue(text(of: log).contains(made), text(of: log))
        XCTAssertFalse(element("autopilot.problem").exists, "Nothing for the person: Atlas made the simulator")
        XCTAssertFalse(app.staticTexts.matching(Self.says("report_capture_problem")).firstMatch.exists)
        attachScreenshot("Making it · iPhone Duo's simulator made by Atlas")
    }

    func testDecliningDropsTheRequest() {
        app.launch(debugScene: "ap-recapture-request")
        let decline = element("screenshots.recaptureRequest.decline")
        XCTAssertTrue(decline.waitForExistence(timeout: 20))
        decline.click()
        XCTAssertTrue(element("screenshots.recaptureRequest").waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("autopilot.guided.title").exists)
    }

    func testPickShowsOnlyTheRedoneCaptures() {
        app.launch(debugScene: "ap-recapture-pick")
        XCTAssertTrue(element("autopilot.recapturePick").waitForExistence(timeout: 20))
        XCTAssertFalse(element("autopilot.pick").exists, "Not the whole run's Pick")
        attachScreenshot("Pick · redone captures beside the ones before")
    }

    // MARK: - Choosing captures

    func testCapturesAreChosenByRowColumnAndCommandClick() {
        app.launch(debugScene: "ap-captures-stale")
        let bar = element("captures.selection")
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "The scene selects two captures")
        XCTAssertEqual(text(of: element("captures.selection.count")), "2 selected")
        let stale = NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "captures.coverage.", "Out of date")
        XCTAssertTrue(app.descendants(matching: .any).matching(stale).firstMatch.exists, "A capture says it's out of date")
        attachScreenshot("Captures · out of date, two selected")

        element("captures.selection.clear").click()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5))

        element("captures.coverage.column.1").click()
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        let column = text(of: element("captures.selection.count"))
        XCTAssertNotEqual(column, "1 selected", "A column is every language's capture of that screen")
        element("captures.coverage.column.1").click()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5), "Clicking the column again deselects it")

        let cell = element("captures.coverage.en-US.2")
        XCTAssertTrue(cell.exists)
        XCUIElement.perform(withKeyModifiers: .command) { cell.click() }
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: element("captures.selection.count")), "1 selected")
        XCTAssertTrue(element("captures.selection.replace").isEnabled)
    }

    func testReplaceSwapsTheCaptureWithoutARun() throws {
        let png = try Self.writeScreenshotPNG()
        app.launch(debugScene: "ap-captures-stale")
        XCTAssertTrue(element("captures.selection").waitForExistence(timeout: 20))
        element("captures.selection.clear").click()
        let cell = element("captures.coverage.en-US.2")
        XCUIElement.perform(withKeyModifiers: .command) { cell.click() }
        element("captures.selection.replace").click()

        let panel = app.sheets.firstMatch.exists ? app.sheets.firstMatch : app.dialogs.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "The open panel")
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(png.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        let notice = element("screenshots.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 15))
        XCTAssertTrue(
            text(of: notice).contains("Replaced") || app.staticTexts.matching(Self.says("Replaced")).firstMatch.exists,
            text(of: notice)
        )
        XCTAssertFalse(element("autopilot.guided.title").exists, "No run opens")
        attachScreenshot("Captures · replaced by hand")
    }

    // MARK: - Helpers

    /// A full-size iPhone screenshot in the runner's temporary folder.
    private static func writeScreenshotPNG() throws -> URL {
        let image = NSImage(size: NSSize(width: 1320, height: 2868))
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1320, pixelsHigh: 2868, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemIndigo.setFill()
        NSRect(x: 0, y: 0, width: 1320, height: 2868).fill()
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        let url = FileManager.default.temporaryDirectory.appending(path: "Recapture-Today.png")
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// A static text's words are its value on macOS, sometimes its label.
    private static func says(_ words: String) -> NSPredicate {
        NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)
    }
}
