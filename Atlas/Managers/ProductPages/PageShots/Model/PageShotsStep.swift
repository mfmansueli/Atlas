//
//  PageShotsStep.swift
//  Atlas
//

import Foundation

/// The three steps of Make Screenshots for This Page: three instead of
/// Autopilot's six, since the app, its devices and the template are known.
enum PageShotsStep: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case plan
    case making
    case result

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .plan: String(localized: "Plan")
        case .making: String(localized: "Making")
        case .result: String(localized: "Result")
        }
    }
}
