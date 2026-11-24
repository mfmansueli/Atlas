//
//  AppPreviewHandDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// App Previews by hand on the Screenshots language page, as DEBUG scenes
/// (`-AtlasDebugScene <id>`), on Lumen Journal in English (U.S.) on iPhone:
///
/// - `ap-hand`: the live App Preview and Choose App Previews….
/// - `ap-hand-changed`: the live one replaced by a file, one added after it
///   and one suggested by Claude Code, waiting in Review & Push.
/// - `ap-hand-problem`: a chosen video refused: wrong size and too short.
enum AppPreviewHandDebugScenes {
    static let ids = ["ap-hand", "ap-hand-changed", "ap-hand-problem"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        let changes = id == "ap-hand-changed" ? DebugWorkspace.pendingChanges + [changed] : DebugWorkspace.pendingChanges
        let center = ScreenshotsDocumentCenter.shared
        center.diskStore = nil
        let opening = ScreenshotsDebugOpening { model in
            model.pageLocale = .englishUS
            model.displayType = .iPhone
            if id == "ap-hand-problem" {
                model.appPreviewProblems = [
                    "“Lumen-en-3.mov” is 1080 × 1920. iPhone 6.9″ takes 886 × 1920, upright or turned.",
                    "“Lumen-en-3.mov” is 9 seconds long. An App Preview is 15 to 30 seconds.",
                ]
            }
        }
        let screenshots = DebugScreenshotsServices(opening: opening, documentCenter: center)
        screenshots.opensLanguagePage = true
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return AnyView(DebugMainScene(services: services, section: .screenshots, pendingChanges: changes))
    }

    /// English (U.S.)'s set changed by hand.
    @MainActor
    static var changed: PendingChange {
        var content = AppPreviewSetPush.Content.start(
            appID: DebugFixtures.AppID.lumen, localizationID: "loc-en-US", locale: "en-US", displayType: .iPhone,
            live: ScreenshotsDebugDocuments.live.previewSets.first { $0.locale == "en-US" }
        )
        content.replace(at: 0, with: file("Lumen-en-1.mov"))
        content.add([file("Lumen-en-2.mov")])
        content.add([file("Lumen-en-search.mov")], proposedBy: "Claude Code")
        return AppPreviewHandChange.change(content, localeName: "English (U.S.)", liveCount: 1)
    }

    private static func file(_ name: String) -> ProductPageScreenshotsPush.File {
        ProductPageScreenshotsPush.File(
            path: "/tmp/AtlasAppPreviewFiles/\(name)", fileName: name, fileSize: 24_000_000, checksum: "", mimeType: "video/quicktime"
        )
    }
}
#endif
