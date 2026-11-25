//
//  ProposeAppPreviewFileToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_app_preview_file` on Lumen Journal's sample: a video sent to
/// the upload link goes into a language's App Previews on iPhone or iPad,
/// replacing one or after the last, checked like one the person chooses,
/// and waits in Review & Push; what can't go is refused with the fix.
@MainActor
@Suite("propose_app_preview_file")
struct ProposeAppPreviewFileToolTests {
    private static let folder = FileManager.default.temporaryDirectory.appending(path: "ProposeAppPreviewFileToolTests")

    /// An upload of `name` with its facts, its bytes on disk.
    private static func uploads(
        _ name: String = "ja-search.mov", size: PixelSize? = PixelSize(width: 886, height: 1920), seconds: Double? = 22
    ) throws -> AppPreviewUploads {
        let uploads = AppPreviewUploads(token: "t")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Data(count: 64).write(to: url)
        let file = ProductPageScreenshotsPush.File(path: url.path, fileName: name, fileSize: 64, checksum: "", mimeType: "video/quicktime")
        uploads.add(AppPreviewUploads.Upload(id: "apf-1", appID: MCPScreenshotsFixtures.appID, file: file, pixelSize: size, seconds: seconds))
        return uploads
    }

    private static func arguments(_ extra: [String: JSONValue] = [:]) -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [
            "locale": "ja", "displayType": "iphone", "fileId": "apf-1", "reason": "Japanese reviews ask how search works.",
        ]
        arguments.merge(extra) { _, new in new }
        return arguments
    }

    @Test func aVideoGoesAfterTheLastAndWaitsInReviewAndPush() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let uploads = try Self.uploads()
        let outcome = try await MCPScreenshotsFixtures.call(ProposeAppPreviewFileTool(uploads: uploads), Self.arguments(), in: workspace)
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["appPreviews"] == 2)
        #expect(outcome.logLines.first?.outcome == .proposed)
        let change = try #require(workspace.changes.change(id: outcome.result["changeId"]?.stringValue ?? ""))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.groupNote == "Japanese reviews ask how search works.")
        let content = try #require(AppPreviewHandChange.content(of: change))
        #expect(content.localizationID.hasSuffix("-ja"))
        #expect(content.slots.map(\.fileName) == ["Lumen-ja.mov", "ja-search.mov"])
        #expect(content.slots[1].proposedBy == "Claude Code")
        #expect(uploads.upload(id: "apf-1", appID: MCPScreenshotsFixtures.appID) == nil, "An upload is used once")
    }

    @Test func howSureAndDetailsGoOnTheChange() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let outcome = try await MCPScreenshotsFixtures.call(
            ProposeAppPreviewFileTool(uploads: Self.uploads()),
            Self.arguments(["confidence": 2, "details": "4 of 31 Japanese reviews this month ask how search works."]),
            in: workspace
        )
        let change = try #require(workspace.changes.change(id: outcome.result["changeId"]?.stringValue ?? ""))
        #expect(change.layers?.confidence == .fairlySure)
        #expect(change.layers?.details == "4 of 31 Japanese reviews this month ask how search works.")
        #expect(ProposeAppPreviewFileTool().definition.inputSchema.jsonString().contains("\"confidence\""))

        await #expect(throws: MCPToolError.self) {
            _ = try await MCPScreenshotsFixtures.call(
                ProposeAppPreviewFileTool(uploads: Self.uploads()), Self.arguments(["confidence": 7]), in: MCPScreenshotsFixtures.workspace().0
            )
        }
    }

    @Test func aPositionReplacesTheLiveOne() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let outcome = try await MCPScreenshotsFixtures.call(
            ProposeAppPreviewFileTool(uploads: Self.uploads()), Self.arguments(["position": 1]), in: workspace
        )
        let change = try #require(workspace.changes.change(id: outcome.result["changeId"]?.stringValue ?? ""))
        let content = try #require(AppPreviewHandChange.content(of: change))
        #expect(content.slots.map(\.fileName) == ["ja-search.mov"])
        #expect(content.deletedIDs == ["preview|ja|0"])
    }

    @Test func whatAppStoreConnectRefusesIsRefusedWithTheFix() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let wrong = try await MCPScreenshotsFixtures.call(
            ProposeAppPreviewFileTool(uploads: Self.uploads(size: PixelSize(width: 1080, height: 1920), seconds: 40)), Self.arguments(), in: workspace
        )
        #expect(wrong.result["status"] == "refused")
        let reason = wrong.result["reason"]?.stringValue ?? ""
        #expect(reason.contains("886 × 1920"), "\(reason)")
        #expect(reason.contains("15 to 30 seconds"), "\(reason)")
        #expect(workspace.changes.changes.isEmpty)

        let missing = try await MCPScreenshotsFixtures.call(
            ProposeAppPreviewFileTool(uploads: AppPreviewUploads(token: "t")), Self.arguments(), in: workspace
        )
        #expect(missing.result["status"] == "refused")

        let noPlace = try await MCPScreenshotsFixtures.call(
            ProposeAppPreviewFileTool(uploads: Self.uploads()), Self.arguments(["position": 3]), in: workspace
        )
        #expect(noPlace.result["status"] == "refused")

        await #expect(throws: MCPToolError.self) {
            _ = try await MCPScreenshotsFixtures.call(
                ProposeAppPreviewFileTool(uploads: Self.uploads()), Self.arguments(["displayType": "watch"]), in: workspace
            )
        }
    }

    @Test func theContextGivesTheUploadLinkAndTheSet() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let outcome = try await MCPScreenshotsFixtures.call(GetScreenshotContextTool(), ["locale": "ja", "displayType": "iphone"], in: workspace)
        #expect(outcome.result["appPreviewUploadURL"]?.stringValue?.contains(MCPEndpoint.appPreviewFilePath) == true)
        let previews = try #require(outcome.result["appPreviews"]?["appPreviews"]?.arrayValue)
        #expect(previews.first?["madeBy"] == "live")
        #expect(previews.first?["position"] == 1)
    }

    @Test func itsInTheToolbox() {
        #expect(MCPToolbox.standard.tools.contains { $0.definition.name == "propose_app_preview_file" })
    }
}
#endif
