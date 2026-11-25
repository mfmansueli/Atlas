//
//  AssistantChatContext.swift
//  Atlas
//

import Foundation

/// Where the person is when they ask (board 69: context in chips the
/// person can take out): the app and the section always; the version and,
/// in Pricing, the country it shows prices for, while they haven't removed
/// them. Every question goes with it.
struct AssistantChatContext: Hashable, Sendable {
    struct Chip: Identifiable, Hashable, Sendable {
        /// “version”, for the chips that can be removed.
        var id: String
        var label: String
        var isRemovable: Bool
    }

    var appID: StoreApp.ID
    var appName: String
    var section: AppWorkspaceSection
    /// “1.4”.
    var version: String?
    /// Pricing's chosen country, “Brazil”; nil in the other sections.
    var country: String?

    static let versionChip = "version"
    static let countryChip = "country"

    /// The chips under the panel's title, less the ones in `removed`.
    func chips(removing removed: Set<String>) -> [Chip] {
        var chips = [
            Chip(id: "app", label: appName, isRemovable: false),
            Chip(id: "section", label: section.title, isRemovable: false),
        ]
        if let version, !removed.contains(Self.versionChip) {
            chips.append(Chip(id: Self.versionChip, label: String(localized: "Version \(version)", comment: "kind:chip"), isRemovable: true))
        }
        if let country = country(removing: removed) {
            chips.append(Chip(id: Self.countryChip, label: country, isRemovable: true))
        }
        return chips
    }

    /// The version, unless its chip was removed.
    func version(removing removed: Set<String>) -> String? {
        removed.contains(Self.versionChip) ? nil : version
    }

    /// The country, unless its chip was removed.
    func country(removing removed: Set<String>) -> String? {
        removed.contains(Self.countryChip) ? nil : country
    }
}
