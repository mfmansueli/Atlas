//
//  ReviewShotProductState.swift
//  Atlas
//

import Foundation

/// A product's state as Atlas read it back from App Store Connect once its
/// review screenshot is there (README — Pricing: review screenshots, “What
/// this changes”): Ready to Submit, or still Missing Metadata, and then
/// what Atlas could find missing besides the screenshot (the product's
/// localization, its subscription group's, its prices). The Paid Apps
/// agreement can't be read with an API key, so it's only ever named.
struct ReviewShotProductState: Hashable, Sendable {
    /// What else App Store Connect lacks.
    enum Gap: Hashable, Sendable, CaseIterable {
        /// The subscription or in-app purchase has no localization.
        case localization
        /// Its subscription group has no localization.
        case groupLocalization
        /// It has no price.
        case prices

        /// “its localization”, as the cause names it.
        var name: String {
            switch self {
            case .localization: String(localized: "its localization", comment: "kind:description")
            case .groupLocalization: String(localized: "the group’s localization", comment: "kind:description")
            case .prices: String(localized: "its prices", comment: "kind:description")
            }
        }
    }

    /// Apple's `state`: `READY_TO_SUBMIT`, `MISSING_METADATA`…
    var code: String
    /// What Atlas found missing; empty when it found nothing, or didn't
    /// look (any state but Missing Metadata).
    var gaps: Set<Gap> = []

    static let missingMetadata = "MISSING_METADATA"

    var isMissingMetadata: Bool { code == Self.missingMetadata }

    /// “Ready to Submit”, for the card's pill.
    var title: String { LivePricingMapper.stateTitle(code) }

    /// The pill's colour: amber while it can't be submitted.
    var pillStyle: PillStyle {
        switch code {
        case Self.missingMetadata, "DEVELOPER_ACTION_NEEDED", "REJECTED": .warning
        default: .neutral
        }
    }

    /// Why it's still Missing Metadata, when it is: the gaps Atlas found,
    /// else the causes developers report (README — “What Apple says”).
    var cause: String? {
        guard isMissingMetadata else { return nil }
        let found = Gap.allCases.filter(gaps.contains)
        guard !found.isEmpty else {
            return String(
                localized: "Still Missing Metadata. Check its localization, the group’s, its prices and the Paid Apps agreement in App Store Connect.",
                comment: "kind:description"
            )
        }
        let names = ListFormatter.localizedString(byJoining: found.map(\.name))
        return String(localized: "Still Missing Metadata: \(names) missing in App Store Connect.", comment: "kind:description")
    }
}
