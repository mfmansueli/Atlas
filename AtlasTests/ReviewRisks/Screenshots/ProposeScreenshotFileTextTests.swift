//
//  ProposeScreenshotFileTextTests.swift
//  AtlasTests
//

#if DEBUG
import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// `propose_screenshot_file` reads the text in the file: “free”, other
/// platforms and Apple's recognitions refuse it with what it shows; an
/// amount only comes back as a note.
@MainActor
@Suite("App Review risks · text in an assistant's screenshot file")
struct ProposeScreenshotFileTextTests {
    private let appID = MCPScreenshotsFixtures.appID

    /// Sends `lines` drawn in a file through `tool`'s upload link and
    /// proposes it for screenshot 1 of the English (U.S.) iPhone set.
    private func propose(
        _ lines: [String], reader: ScreenshotFileTextCheck.Reader? = nil
    ) async throws -> (MCPToolOutcome, CenteredScreenshotsServices) {
        let (workspace, services) = MCPScreenshotsFixtures.workspace()
        let data = try #require(ScreenshotTextTestImage.png(lines))
        let folder = ScreenshotHandFilesFolder.shared
        let file = try folder.save(data, fileName: "01.png", pixelSize: ScreenshotTextTestImage.size, appID: appID)
        defer { try? FileManager.default.removeItem(at: folder.url(for: file, appID: appID)) }
        let uploads = ScreenshotHandUploads()
        uploads.add(ScreenshotHandUploads.Upload(appID: appID, file: file, hasTransparency: false))
        var tool = ProposeScreenshotFileTool(uploads: uploads)
        if let reader { tool.readText = reader }
        let arguments: [String: JSONValue] = [
            "locale": "en-US", "displayType": "iphone", "position": 1, "fileId": .string(file.id), "reason": "Shows the week view.",
        ]
        return try await (MCPScreenshotsFixtures.call(tool, arguments, in: workspace), services)
    }

    @Test func freeInTheFileRefusesItWithWhatItShows() async throws {
        let (outcome, services) = try await propose(["FREE"], reader: { _, _ in ["Your week", "FREE"] })
        #expect(outcome.result["status"] == "refused")
        let reason = try #require(outcome.result["reason"]?.stringValue)
        #expect(reason.contains("“FREE”"))
        #expect(reason.contains("2.3.7"))
        #expect(reason.hasSuffix("Send one without it."))
        #expect(services.storedDocument?.handProposals?.isEmpty ?? true)
    }

    @Test func applesRecognitionsRefuseIt() async throws {
        let (outcome, _) = try await propose(["Editor’s Choice"], reader: { _, _ in ["Editor’s Choice"] })
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("5.2.5") == true)
    }

    @Test func anAmountIsANoteNotARefusal() async throws {
        let (outcome, services) = try await propose(["Groceries"], reader: { _, _ in ["Groceries", "$4.99"] })
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["check"]?.stringValue?.contains("$4.99") == true)
        #expect(services.storedDocument?.handProposals?.count == 1)
    }

    @Test func ordinaryTextAndAnUnreadableFileAreQueued() async throws {
        let (clean, _) = try await propose(["Your week"], reader: { _, _ in ["Your week", "Ad-free journaling"] })
        #expect(clean.result["status"] == "queued")
        #expect(clean.result["check"] == nil)
        let (unread, _) = try await propose(["Your week"], reader: { _, _ in nil })
        #expect(unread.result["status"] == "queued")
    }

    @Test(.timeLimit(.minutes(1)))
    func visionReadsOtherPlatformsInARenderedFile() async throws {
        let (outcome, _) = try await propose(["Get it on", "Google Play"])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("2.3.10") == true)
    }

    @Test func theRefusalNamesEveryRuleOnce() {
        let findings = ScreenshotTextRules.findings(in: ["FREE", "Also on Google Play", "$4.99"])
        let refusal = ScreenshotFileTextCheck.refusal(for: findings)
        #expect(refusal?.contains("2.3.7") == true)
        #expect(refusal?.contains("2.3.10") == true)
        #expect(refusal?.contains("$4.99") == false)
        #expect(ScreenshotFileTextCheck.note(for: findings)?.contains("$4.99") == true)
        #expect(ScreenshotFileTextCheck.refusal(for: ScreenshotTextRules.findings(in: ["$4.99"])) == nil)
    }
}
#endif
