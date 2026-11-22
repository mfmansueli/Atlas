//
//  GracePeriodSetting.swift
//  Atlas
//

import Foundation

/// The app's Billing Grace Period, as App Store Connect has it.
struct GracePeriodSetting: Hashable, Sendable {
    /// How long people keep access while Apple retries a failed charge.
    enum Duration: String, Hashable, Sendable, CaseIterable, Identifiable {
        case threeDays = "THREE_DAYS"
        case sixteenDays = "SIXTEEN_DAYS"
        case twentyEightDays = "TWENTY_EIGHT_DAYS"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .threeDays: 3
            case .sixteenDays: 16
            case .twentyEightDays: 28
            }
        }

        var title: String { String(localized: "\(days) days") }
    }

    var id: String
    var isOn: Bool
    var duration: Duration?
}
