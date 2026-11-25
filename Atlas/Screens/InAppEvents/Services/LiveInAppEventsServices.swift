//
//  LiveInAppEventsServices.swift
//  Atlas
//

import Foundation

/// The real `InAppEventsServices`, backed by App Store Connect: one read
/// for the events and their texts, then their images and video: every
/// language's while an event is coming or live (to say which still lacks
/// its own card or details page; Apple shows the primary language's
/// there), only the primary language's once it's over, none once it's
/// archived. A language whose media read fails keeps what the last read
/// that worked found (`InAppEventMediaMemory`).
@MainActor
struct LiveInAppEventsServices: InAppEventsServices {
    let client: AppStoreConnectClient
    var mediaMemory = InAppEventMediaMemory()

    func events(for app: StoreApp) async throws -> [InAppEvent] {
        var events: [InAppEvent] = []
        for page in try await client.appEvents(appID: app.id) {
            let localizations = Dictionary((page.included ?? []).map { ($0.id, $0) }) { first, _ in first }
            events += page.data.map { Self.event($0, localizations: localizations) }
        }
        let ids = events.filter { $0.state != .archived }.flatMap { event in
            event.state.isOver ? [event.primaryLocalization?.id].compactMap(\.self) : event.localizations.map(\.id)
        }
        let media = await mediaMemory.settle(Self.media(localizationIDs: ids, client: client))
        for index in events.indices {
            for position in events[index].localizations.indices {
                events[index].localizations[position].media = media[events[index].localizations[position].id] ?? []
            }
        }
        return events.sorted(by: Self.isShownBefore)
    }

    /// Each language's media, four languages at a time; nil for a language
    /// whose read failed, rather than failing the list.
    private static func media(localizationIDs: [String], client: AppStoreConnectClient) async -> [String: [InAppEventMedia]?] {
        await withTaskGroup(of: (String, [InAppEventMedia]?).self) { group in
            var found: [String: [InAppEventMedia]?] = [:]
            var pending = localizationIDs[...]
            func start(_ id: String) {
                group.addTask { await (id, media(localizationID: id, client: client)) }
            }
            for _ in 0..<4 {
                guard let id = pending.popFirst() else { break }
                start(id)
            }
            while let (id, media) = await group.next() {
                found[id] = media
                if let next = pending.popFirst() { start(next) }
            }
            return found
        }
    }

    private nonisolated static func media(localizationID: String, client: AppStoreConnectClient) async -> [InAppEventMedia]? {
        do {
            let screenshots = try await client.appEventScreenshots(localizationID: localizationID)
            let clips = try await client.appEventVideoClips(localizationID: localizationID)
            return screenshots.compactMap { media($0.attributes, isVideo: false) } + clips.compactMap { media($0.attributes, isVideo: true) }
        } catch {
            return nil
        }
    }

    // MARK: - Mapping

    static func event(_ resource: AppEventsDocument.Event, localizations: [String: AppStoreConnectResource<AppEventLocalizationAttributes>]) -> InAppEvent {
        let attributes = resource.attributes
        let state = InAppEventState(apiValue: attributes.eventState)
        let schedules = (state.isOver ? attributes.archivedTerritorySchedules ?? attributes.territorySchedules : attributes.territorySchedules) ?? []
        return InAppEvent(
            id: resource.id,
            referenceName: attributes.referenceName ?? "",
            badge: attributes.badge.flatMap(InAppEventBadge.init(rawValue:)),
            state: state,
            deepLink: attributes.deepLink,
            purchaseRequirement: attributes.purchaseRequirement.flatMap(InAppEventPurchaseRequirement.init(rawValue:)),
            primaryLocale: attributes.primaryLocale,
            priority: attributes.priority.flatMap(InAppEventPriority.init(rawValue:)) ?? .normal,
            purpose: attributes.purpose.flatMap(InAppEventPurpose.init(rawValue:)),
            schedules: schedules.map(schedule),
            localizations: resource.localizationIDs.compactMap { localizations[$0] }.map(localization)
        )
    }

    static func schedule(_ schedule: AppEventAttributes.Schedule) -> InAppEventSchedule {
        InAppEventSchedule(
            territories: schedule.territories ?? [],
            publishStart: AppStoreConnectDate.date(schedule.publishStart),
            eventStart: AppStoreConnectDate.date(schedule.eventStart),
            eventEnd: AppStoreConnectDate.date(schedule.eventEnd)
        )
    }

    static func localization(_ resource: AppStoreConnectResource<AppEventLocalizationAttributes>) -> InAppEventLocalization {
        InAppEventLocalization(
            id: resource.id,
            locale: resource.attributes.locale ?? "",
            name: resource.attributes.name ?? "",
            shortDescription: resource.attributes.shortDescription ?? "",
            longDescription: resource.attributes.longDescription ?? ""
        )
    }

    nonisolated static func media(_ attributes: AppEventMediaAttributes, isVideo: Bool) -> InAppEventMedia? {
        guard let kind = attributes.appEventAssetType.flatMap(InAppEventMedia.Kind.init(rawValue:)) else { return nil }
        let asset = attributes.shownImage
        let delivery = attributes.deliveryState(isVideo: isVideo)
        return InAppEventMedia(
            kind: kind, isVideo: isVideo, width: asset?.width, height: asset?.height, imageURL: asset?.url(width: 640),
            videoURL: isVideo ? attributes.videoUrl.flatMap(URL.init(string:)) : nil, fileName: attributes.fileName,
            fileSize: attributes.fileSize, previewFrameTimeCode: isVideo ? attributes.previewFrameTimeCode : nil, state: delivery?.state,
            stateErrors: (delivery?.errors ?? []).compactMap { $0.description ?? $0.code }
        )
    }

    /// Drafts and what's with App Review first, then what's live, then
    /// what's over; within each, the later event first.
    static func isShownBefore(_ lhs: InAppEvent, _ rhs: InAppEvent) -> Bool {
        func rank(_ event: InAppEvent) -> Int {
            if event.state.isOver { return 2 }
            return event.state == .published ? 1 : 0
        }
        let (left, right) = (rank(lhs), rank(rhs))
        if left != right { return left < right }
        return (lhs.schedule?.eventStart ?? .distantFuture) > (rhs.schedule?.eventStart ?? .distantFuture)
    }
}
