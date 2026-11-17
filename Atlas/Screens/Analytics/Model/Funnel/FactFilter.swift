//
//  FactFilter.swift
//  Atlas
//

import Foundation

/// Which facts a total counts: some territories, one source, one device.
/// nil leaves that dimension open.
struct FactFilter: Hashable, Sendable {
    var territories: Set<String>?
    var source: String?
    var device: String?

    static let all = FactFilter()

    func matches(_ fact: EngagementFact) -> Bool {
        if let territories, !territories.contains(fact.territory) { return false }
        if let source, fact.source != source { return false }
        if let device, fact.device != device { return false }
        return true
    }

    /// Apple doesn't link sales to a source, so a source filter has none.
    var allowsSales: Bool { source == nil }

    func matches(territory: String, device: String) -> Bool {
        if let territories, !territories.contains(territory) { return false }
        if let wanted = self.device, !Self.sameDevice(wanted, device) { return false }
        return true
    }

    /// Analytics reports say "Desktop" or "Mac" where sales say "Desktop".
    static func sameDevice(_ lhs: String, _ rhs: String) -> Bool {
        func family(_ name: String) -> String {
            let name = name.lowercased()
            if name.contains("mac") || name.contains("desktop") { return "mac" }
            if name.contains("vision") { return "vision" }
            if name.contains("tv") { return "tv" }
            return name
        }
        return family(lhs) == family(rhs)
    }
}
