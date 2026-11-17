//
//  InAppEventChangeBuilder+QueuedEvents.swift
//  Atlas
//

import Foundation

// The new events waiting in Review & Push, read back from their requests:
// what `get_in_app_events` lists as queued, and the reference names a new
// event can't take.
extension InAppEventChangeBuilder {
    /// The app's new events in `changes`, in the order queued.
    func queuedNewEvents(in changes: [PendingChange]) -> [PendingChange] {
        changes.filter(isNewEvent)
    }

    /// A queued new event as it was described; nil when its `POST` can't
    /// be read.
    static func newEvent(in change: PendingChange) -> NewInAppEvent? {
        guard let create = change.requests.first, create.method == .post, create.path == newEventPath,
              let object = create.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              let attributes = (object["data"] as? [String: Any])?["attributes"] as? [String: Any]
        else { return nil }
        var event = NewInAppEvent()
        event.referenceName = attributes["referenceName"] as? String ?? ""
        event.badge = (attributes["badge"] as? String).flatMap(InAppEventBadge.init(rawValue:)) ?? event.badge
        event.purpose = (attributes["purpose"] as? String).flatMap(InAppEventPurpose.init(rawValue:)) ?? event.purpose
        event.priority = (attributes["priority"] as? String).flatMap(InAppEventPriority.init(rawValue:)) ?? event.priority
        event.purchaseRequirement = (attributes["purchaseRequirement"] as? String).flatMap(InAppEventPurchaseRequirement.init(rawValue:))
            ?? event.purchaseRequirement
        event.deepLink = attributes["deepLink"] as? String ?? ""
        event.primaryLocale = attributes["primaryLocale"] as? String ?? event.primaryLocale
        if let schedule = (attributes["territorySchedules"] as? [[String: Any]])?.first {
            let territories = schedule["territories"] as? [String] ?? []
            event.territories = NewInAppEventEverywhere.isEverywhere(territories) ? [] : territories
            event.publishStart = AppStoreConnectDate.date(schedule["publishStart"] as? String) ?? event.publishStart
            event.eventStart = AppStoreConnectDate.date(schedule["eventStart"] as? String) ?? event.eventStart
            event.eventEnd = AppStoreConnectDate.date(schedule["eventEnd"] as? String) ?? event.eventEnd
        }
        for request in change.requests.dropFirst() {
            guard let document = InAppEventWriteDocument.decode(request.body), let locale = document.data.attributes["locale"] else { continue }
            event.texts[locale] = document.texts
        }
        return event
    }

    /// The reference names a new event can't take: the app's events', live
    /// or not, and the other new events' waiting in Review & Push.
    func takenReferenceNames(events: [InAppEvent], changes: [PendingChange], except changeID: PendingChange.ID? = nil) -> Set<String> {
        let queued = queuedNewEvents(in: changes).filter { $0.id != changeID }.compactMap { Self.newEvent(in: $0)?.trimmedReferenceName }
        return Set(events.map(\.referenceName) + queued)
    }

    /// The queued new event with `referenceName` (compared without case).
    func queuedNewEvent(named referenceName: String, in changes: [PendingChange]) -> PendingChange? {
        let key = NewInAppEvent.nameKey(referenceName)
        return queuedNewEvents(in: changes).first { change in
            Self.newEvent(in: change).map { NewInAppEvent.nameKey($0.referenceName) == key } ?? false
        }
    }
}
