//
//  ProductPageComparison.swift
//  Atlas
//

import Foundation

/// A page's download rate next to the default page's: within 1.5 points is
/// about the same; under 200 page views is too few to say.
enum ProductPageComparison: Hashable, Sendable {
    /// Points it differs by is under the threshold.
    case aboutTheSame
    case above(points: Double)
    case below(points: Double)
    case tooFewViews(Int)

    /// Points closer than this read as about the same.
    static let sameWithin = 1.5

    init?(page: ProductPageNumbers, reference: ProductPageNumbers) {
        guard page.pageViews > 0, let rate = page.downloadRate else { return nil }
        guard page.pageViews >= ProductPageNumbers.fewestViewsToCompare else {
            self = .tooFewViews(page.pageViews)
            return
        }
        guard let referenceRate = reference.downloadRate else { return nil }
        let points = rate - referenceRate
        if abs(points) < Self.sameWithin {
            self = .aboutTheSame
        } else {
            self = points > 0 ? .above(points: points) : .below(points: -points)
        }
    }

    /// "about the same as default", "2.1 pt above default",
    /// "6.1 pt below default", "96 views is too few to compare"; the row
    /// puts `systemImage` before above and below.
    var text: String {
        switch self {
        case .aboutTheSame: String(localized: "about the same as default")
        case let .above(points): String(localized: "\(Self.points(points)) pt above default")
        case let .below(points): String(localized: "\(Self.points(points)) pt below default")
        case let .tooFewViews(views): String(localized: "\(ProductPageNumbersText.number(views)) views is too few to compare")
        }
    }

    /// The arrow symbol before above and below (README-DS §13).
    var systemImage: String? {
        switch self {
        case .above: "arrowtriangle.up.fill"
        case .below: "arrowtriangle.down.fill"
        case .aboutTheSame, .tooFewViews: nil
        }
    }

    /// The same words for VoiceOver, without the arrows.
    var spoken: String {
        switch self {
        case .aboutTheSame, .tooFewViews: text
        case let .above(points): String(localized: "\(Self.points(points)) points above default")
        case let .below(points): String(localized: "\(Self.points(points)) points below default")
        }
    }

    /// The rate reads as a weak number: there aren't enough views.
    var isTooFew: Bool {
        if case .tooFewViews = self { return true }
        return false
    }

    private static func points(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX")))
    }
}
