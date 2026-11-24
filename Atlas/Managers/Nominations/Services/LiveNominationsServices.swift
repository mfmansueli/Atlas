//
//  LiveNominationsServices.swift
//  Atlas
//

import Foundation

/// The real `NominationsServices`: three reads of `GET /v1/nominations`
/// (drafts, submitted, archived) filtered to the app, and the context from
/// the account's other sections' services.
@MainActor
struct LiveNominationsServices: NominationsServices {
    let client: AppStoreConnectClient

    func nominations(for app: StoreApp) async throws -> [Nomination] {
        var nominations: [Nomination] = []
        for state in AppStoreConnectClient.nominationStates {
            for page in try await client.nominations(state: state, appID: app.id) {
                nominations += Self.nominations(in: page)
            }
        }
        return nominations
    }

    func context(for app: StoreApp) async -> NominationContext {
        await NominationContextReader(
            appList: LiveAppListServices(client: client),
            storePage: LiveStorePageServices(client: client),
            inAppEvents: LiveInAppEventsServices(client: client),
            productPages: LiveProductPagesServices(client: client)
        ).context(for: app)
    }

    // MARK: - Mapping

    /// A page's nominations, with the names its included apps, events and
    /// actors give.
    static func nominations(in page: NominationsDocument) -> [Nomination] {
        let included = Dictionary((page.included ?? []).map { ("\($0.type)/\($0.id)", $0) }) { first, _ in first }
        return page.data.map { nomination($0, included: included) }
    }

    static func nomination(_ resource: NominationsDocument.Resource, included: [String: NominationsDocument.Included]) -> Nomination {
        let attributes = resource.attributes
        let relationships = resource.relationships
        let appIDs = relationships?.relatedApps?.ids ?? []
        let eventIDs = relationships?.inAppEvents?.ids ?? []
        let territories = relationships?.supportedTerritories?.ids ?? []
        let content = NominationContent(
            name: attributes.name ?? "",
            type: attributes.type.flatMap(NominationType.init(rawValue:)),
            description: attributes.description ?? "",
            publishStart: AppStoreConnectDate.date(attributes.publishStartDate),
            publishEnd: AppStoreConnectDate.date(attributes.publishEndDate),
            devices: (attributes.deviceFamilies ?? []).compactMap(NominationDevice.init(rawValue:)),
            locales: attributes.locales ?? [],
            territories: NewInAppEventEverywhere.isEverywhere(territories) ? [] : territories,
            launchInSelectMarketsFirst: attributes.launchInSelectMarketsFirst ?? false,
            preOrderEnabled: attributes.preOrderEnabled ?? false,
            eventIDs: eventIDs,
            materials: attributes.supplementalMaterialsUris ?? [],
            notes: attributes.notes ?? "",
            appIDs: appIDs
        )
        func actor(_ linkage: NominationsDocument.ToOne?) -> String? {
            linkage?.data.flatMap { included["actors/\($0.id)"]?.actorName }
        }
        return Nomination(
            id: resource.id,
            state: attributes.state.flatMap(NominationState.init(rawValue:)) ?? .draft,
            content: content,
            createdDate: AppStoreConnectDate.date(attributes.createdDate),
            lastModifiedDate: AppStoreConnectDate.date(attributes.lastModifiedDate),
            submittedDate: AppStoreConnectDate.date(attributes.submittedDate),
            createdBy: actor(relationships?.createdByActor),
            submittedBy: actor(relationships?.submittedByActor),
            appNames: Dictionary(appIDs.compactMap { id in included["apps/\(id)"]?.attributes?.name.map { (id, $0) } }) { first, _ in first },
            eventNames: Dictionary(eventIDs.compactMap { id in included["appEvents/\(id)"]?.attributes?.referenceName.map { (id, $0) } }) { first, _ in first }
        )
    }
}
