//
//  PushController+AppPreviews.swift
//  Atlas
//

import Foundation

// Sets of files a push uploads, more than one request each: a product
// page's own screenshots or App Previews (`ProductPageScreenshotsPush`) and
// the version's App Previews changed by hand in Screenshots
// (`AppPreviewSetPush`: one language's set on one device, uploads before
// deletes before the order).
extension PushController {
    /// Sends `request` if it's one of those sets; false for any other.
    func sendMediaSet(_ request: PushRequest, at index: Int, transport: any PushTransport) async throws -> Bool {
        if let screenshots = ProductPageScreenshotsPush(request) {
            try await send(screenshots, at: index, transport: transport)
            return true
        }
        guard let previews = AppPreviewSetPush(request) else { return false }
        try await send(previews, at: index, transport: transport)
        return true
    }

    func send(_ previews: AppPreviewSetPush, at index: Int, transport: any PushTransport) async throws {
        defer { update(index) { $0.progressNote = nil } }
        let id = try await previews.send(
            via: transport, note: { noteRequest($0) },
            progress: { note in update(index) { $0.progressNote = note } },
            processing: { wakeLoop?.yield(.waitingOnApple(index)) },
            pollInterval: { PushSchedule.pollInterval(waitingOnApple: waitingOnApple.count) }
        )
        update(index) { $0.createdID = id }
    }
}
