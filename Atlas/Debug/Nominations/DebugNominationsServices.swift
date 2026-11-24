//
//  DebugNominationsServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Lumen's nominations in App Store Connect (`DebugNominationsData`), or
/// none, or a read that fails, for the DEBUG scenes and tests.
@MainActor
struct DebugNominationsServices: NominationsServices {
    var nominations: [Nomination] = DebugNominationsData.remote
    var context: NominationContext = DebugNominationsData.context
    var error: (any Error)?

    func nominations(for app: StoreApp) async throws -> [Nomination] {
        if let error { throw error }
        return nominations.filter { $0.content.appIDs.contains(app.id) }
    }

    func context(for app: StoreApp) async -> NominationContext {
        app.id == DebugNominationsData.lumen ? context : NominationContext(apps: DebugFixtures.apps, links: [NominationContext.appStoreLink(for: app)])
    }
}
#endif
