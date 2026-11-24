//
//  FunnelGap.swift
//  Atlas
//

import Foundation

/// Why a step of the funnel has no number, said on the step itself.
enum FunnelGap: Hashable, Sendable {
    case needsVendorNumber
    case keyCannotReadSales
    /// Sales arrive with Apple's next report.
    case salesWaiting
    /// The analytics reports were asked for and haven't arrived.
    case engagementWaiting(asked: Date?)

    var text: String {
        switch self {
        case .needsVendorNumber: String(localized: "Needs your vendor number")
        case .keyCannotReadSales: String(localized: "Your key can’t read sales")
        case .salesWaiting: String(localized: "Sales arrive with Apple’s next report")
        case let .engagementWaiting(asked):
            if let asked {
                String(localized: "Waiting for Apple · asked \(AnalyticsText.day(asked))")
            } else {
                String(localized: "Waiting for Apple")
            }
        }
    }

    /// The button under the text, when the person can do something.
    var actionTitle: String? {
        switch self {
        case .needsVendorNumber: String(localized: "Add Vendor Number…")
        case .keyCannotReadSales: String(localized: "See How to Fix…")
        case .salesWaiting, .engagementWaiting: nil
        }
    }

    /// Why the chart is empty for this step.
    var chartText: String {
        switch self {
        case .needsVendorNumber: String(localized: "This step needs your vendor number.")
        case .keyCannotReadSales: String(localized: "Your key’s role can’t read sales.")
        case .salesWaiting: String(localized: "This step arrives with Apple’s next sales report.")
        case let .engagementWaiting(asked):
            if let asked {
                String(localized: "This step arrives with Apple’s analytics reports, asked for on \(AnalyticsText.day(asked)).")
            } else {
                String(localized: "This step arrives with Apple’s analytics reports.")
            }
        }
    }
}
