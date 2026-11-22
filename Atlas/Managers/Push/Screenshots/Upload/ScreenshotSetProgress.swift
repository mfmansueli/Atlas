//
//  ScreenshotSetProgress.swift
//  Atlas
//

import Foundation

/// One set in a running screenshot push: its ID once it exists and its
/// screenshots in the order this push has left them, so the last step
/// knows whether a reorder is needed.
struct ScreenshotSetProgress: Hashable, Sendable {
    var group: ScreenshotPlanGroup
    var setID: String?
    var order: [String]
    /// Set-level trouble, e.g. the reorder failed.
    var note: String?

    init(group: ScreenshotPlanGroup) {
        self.group = group
        setID = group.liveSet?.id ?? group.emptySetID
        order = group.liveSet?.screenshots.map(\.id) ?? []
    }

    /// The order the set should end in: each slot's new screenshot where
    /// one was committed, else what was live there (unless it was
    /// deleted), then anything left over.
    func desiredOrder(committed: [Int: String]) -> [String] {
        let live = group.liveSet?.screenshots.map(\.id) ?? []
        let slots = max(live.count, (committed.keys.max() ?? -1) + 1)
        var desired: [String] = []
        for slot in 0..<slots {
            if let id = committed[slot] {
                desired.append(id)
            } else if slot < live.count, order.contains(live[slot]) {
                desired.append(live[slot])
            }
        }
        return desired + order.filter { !desired.contains($0) }
    }

    /// The order a set changed by hand ends in: each place's screenshot,
    /// kept or uploaded (`uploaded` gives an item's new screenshot), then
    /// whatever else is still in the set.
    static func handOrder(_ arrangement: [ScreenshotHandTarget], order: [String], uploaded: (ScreenshotPlanItem.ID) -> String?) -> [String] {
        var desired: [String] = []
        for target in arrangement {
            switch target {
            case let .keep(id) where order.contains(id): desired.append(id)
            case let .upload(itemID): if let id = uploaded(itemID), order.contains(id) { desired.append(id) }
            case .keep: continue
            }
        }
        return desired + order.filter { !desired.contains($0) }
    }
}
