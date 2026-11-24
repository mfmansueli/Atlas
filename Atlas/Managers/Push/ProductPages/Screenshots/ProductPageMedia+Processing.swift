//
//  ProductPageMedia+Processing.swift
//  Atlas
//

import Foundation

// What a set's push does after the uploads, the same for a product page's
// own screenshots and App Previews (`ProductPageScreenshotsPush`) and the
// version's App Previews by hand (`AppPreviewSetPush`): wait for Apple to
// process each upload, then delete what goes.
@MainActor
extension ProductPageMedia {
    /// Deletes `ids` from their set; one already gone is fine.
    func delete(_ ids: [String], via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws {
        for id in ids {
            do {
                try await note(transport.send(delete(id: id)).rateLimit)
            } catch AppStoreConnectError.notFound {
                // Already gone.
            }
        }
    }

    /// Waits until Apple processed the upload `id`, or says why not.
    func waitUntilProcessed(
        _ id: String, fileName: String, via transport: any PushTransport, sleep: (Duration) async throws -> Void,
        note: (AppStoreConnectRateLimit?) -> Void, interval: () -> Duration
    ) async throws {
        var waited: Duration = .zero
        while true {
            let response = try await transport.fetch(statusPath(id: id))
            note(response.rateLimit)
            let state = ScreenshotUploadRequests.deliveryState(in: response.data)
            if state?.isComplete == true { return }
            if state?.isFailed == true {
                let details = state?.errors?.compactMap { $0.description ?? $0.code }.joined(separator: " ")
                throw ProductPageScreenshotsPushError.refused(fileName: fileName, details: details?.isEmpty == false ? details : nil)
            }
            guard waited < ProductPageScreenshotsPush.timeout else { throw ProductPageScreenshotsPushError.timedOut(fileName: fileName) }
            let pause = interval()
            try await sleep(pause)
            waited += pause
        }
    }
}
