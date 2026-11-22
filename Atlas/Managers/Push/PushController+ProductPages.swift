//
//  PushController+ProductPages.swift
//  Atlas
//

import Foundation

// Custom product pages' steps that are more than one request: a new page
// (`ProductPageCreate`) and a page's own screenshots
// (`ProductPageScreenshotsPush`), sharing what the push learned about the
// pages (`ProductPagePushState`).
extension PushController {
    /// A new custom product page: made, or the one Apple made although it
    /// answered with an error. While Atlas looks for it, the row says so and
    /// doesn't hold a place.
    func send(_ create: ProductPageCreate, at index: Int, transport: any PushTransport) async throws {
        defer { update(index) { $0.progressNote = nil } }
        let item = items[index]
        let context = ProductPageCreate.Context(appID: item.change.appID, state: productPages, transport: transport, pacing: productPagePacing)
        let id = try await create.send(
            in: context,
            mayHaveMadeItBefore: item.mayHaveMadePage.map(ProductPageBrief.key) == ProductPageBrief.key(create.name),
            note: { noteRequest($0) },
            looking: {
                update(index) { item in
                    item.mayHaveMadePage = create.name
                    item.progressNote = String(localized: "Looking for “\(create.name)” in App Store Connect…")
                }
                wakeLoop?.yield(.waitingOnApple(index))
            },
            made: { id in update(index) { Self.notePage(id, in: &$0) } }
        )
        update(index) { Self.notePage(id, in: &$0) }
    }

    /// A custom product page's own screenshots of one language and device,
    /// into the page's language.
    func send(_ screenshots: ProductPageScreenshotsPush, at index: Int, transport: any PushTransport) async throws {
        defer { update(index) { $0.progressNote = nil } }
        let content = screenshots.content
        let made = items.first { $0.change.groupID == content.pageID && $0.change.appID == content.appID }?.createdIDs["appCustomProductPages"]
        let localizationID = try await productPages.localization(for: screenshots, made: made, transport: transport) { [weak self] in
            self?.noteRequest($0)
        }
        let id = try await screenshots.send(
            into: localizationID, via: transport, note: { noteRequest($0) },
            progress: { note in update(index) { $0.progressNote = note } },
            processing: { wakeLoop?.yield(.waitingOnApple(index)) },
            pollInterval: { PushSchedule.pollInterval(waitingOnApple: waitingOnApple.count) }
        )
        update(index) { $0.createdID = id }
    }

    private static func notePage(_ id: String, in item: inout PushItem) {
        item.createdID = id
        item.createdIDs[ProductPageChangeBuilder.pageType] = id
    }
}
