//
//  PushController+Nominations.swift
//  Atlas
//

import Foundation

/// A draft on this Mac's Submit row names it by placeholder
/// (`NominationPlaceholder`): filled in with the ID its Create row got in
/// this push, or, when an earlier push created it, the app's draft of that
/// name in App Store Connect.
extension PushController {
    func resolvingNomination(_ request: PushRequest, at _: Int, via transport: any PushTransport) async throws -> PushRequest {
        guard let placeholder = NominationPlaceholder(in: request) else { return request }
        let createID = NominationChangeBuilder.changeID(.create, nominationID: placeholder.localID)
        if let create = items.first(where: { $0.change.id == createID }) {
            guard create.status == .done, let id = create.createdIDs["nominations"] ?? create.createdID else {
                throw NominationPlaceholder.NotCreated(name: placeholder.name)
            }
            return request.replacing(placeholder.token, with: id)
        }
        let response = try await transport.fetch(AppStoreConnectClient.draftNominationsPath(appID: placeholder.appID))
        noteRequest(response.rateLimit)
        let page = try JSONDecoder().decode(NominationsDocument.self, from: response.data)
        guard let match = page.data.first(where: { ($0.attributes.name ?? "") == placeholder.name }) else {
            throw NominationPlaceholder.NotCreated(name: placeholder.name)
        }
        return request.replacing(placeholder.token, with: match.id)
    }
}
