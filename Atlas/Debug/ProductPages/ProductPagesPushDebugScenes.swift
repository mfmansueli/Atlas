//
//  ProductPagesPushDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The board's page push states (`cp-push*`), as Atlas has them: Push and
/// Submit… opens Review & Push limited to the page and its one progress
/// sheet pushes it (README-Built §2: no push sheet of the page's own).
/// Private diary, a new page, is what goes; nothing reaches Apple.
///
/// - `cp-push`: Review & Push on Private diary, with the switch to the
///   app's other changes.
/// - `cp-pushing`: its parts going, slowly.
/// - `cp-push-partial`: the page is made but its keywords are refused, so
///   the row names the step that didn't go in.
/// - `cp-push-done`: everything went; Submit for Review opens by itself.
/// - `cp-push-s`: the partial push with the sidebar hidden, for 860 × 560.
enum ProductPagesPushDebugScenes {
    typealias Data = DebugProductPagesData

    static let ids = ["cp-push", "cp-pushing", "cp-push-partial", "cp-push-done", "cp-push-s"]

    /// What the transport refuses in the partial scenes: the keyword writes
    /// that follow the page's create.
    static let partialFailures: [String: AppStoreConnectError] = [
        "searchKeywords": .rejected(
            statusCode: 409, code: "ENTITY_ERROR.RELATIONSHIP.INVALID", detail: "A keyword is not available for this localization."
        ),
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "cp-push":
            scene(pending: DebugWorkspace.pendingChanges + Data.pendingChanges)
        case "cp-pushing":
            scene(transport: DebugPushTransport(delay: .milliseconds(1500)), autoPush: true)
        case "cp-push-partial", "cp-push-s":
            scene(transport: DebugPushTransport(delay: .milliseconds(20), failures: partialFailures), autoPush: true)
        case "cp-push-done":
            scene(transport: DebugPushTransport(delay: .milliseconds(20)), autoPush: true)
        default:
            nil
        }
    }

    /// Private diary's editor with Review & Push open on it; `autoPush`
    /// sends what's pending (only the page's, unless given) as the scene
    /// opens.
    @MainActor
    private static func scene(
        pending: [PendingChange] = Data.pendingChanges,
        transport: DebugPushTransport = DebugPushTransport(),
        autoPush: Bool = false
    ) -> AnyView {
        var services = WorkspaceServices.debug
        services.productPages = DebugProductPagesServices()
        services.push = transport
        ProductPagesDebugLaunch.pending = ProductPagesDebugLaunch(pageID: Data.PageID.privateDiary, opensReview: true)
        return AnyView(DebugMainScene(
            services: services, section: .productPages, pendingChanges: pending,
            analytics: Data.analytics(), productPages: Data.store(), autoPush: autoPush
        ))
    }
}
#endif
