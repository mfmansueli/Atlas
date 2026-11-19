//
//  ComplianceRule.swift
//  Atlas
//

import Foundation

/// One of the regulations App Store Connect's App Compliance page asks
/// about, in the page's order.
enum ComplianceRule: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    /// The EU's Digital Services Act: trader or non-trader.
    case traderStatus
    /// China mainland's ICP Filing Number.
    case icpFilingNumber
    /// China mainland: whether the app has features that need a Security
    /// Assessment (since November 2026).
    case securityAssessment
    /// China mainland: whether the app offers AI-generated or synthetic
    /// content, with its model's filing (since November 2026).
    case aiGeneratedContent
    /// Vietnam's license for games.
    case vietnamGameLicense
    /// Whether the app is a regulated medical device (EEA, UK, US).
    case medicalDevice

    var id: String { rawValue }

    /// Without the place: "Digital Services Act".
    var name: String {
        switch self {
        case .traderStatus: String(localized: "Digital Services Act")
        case .icpFilingNumber: String(localized: "ICP Filing Number")
        case .securityAssessment: String(localized: "Security Assessment")
        case .aiGeneratedContent: String(localized: "AI Generated or Synthetic Content")
        case .vietnamGameLicense: String(localized: "Vietnam Game License")
        case .medicalDevice: String(localized: "Regulated Medical Devices")
        }
    }

    var title: String {
        switch self {
        case .traderStatus: String(localized: "Digital Services Act · European Union")
        case .icpFilingNumber: String(localized: "ICP Filing Number · China mainland")
        case .securityAssessment: String(localized: "Security Assessment · China mainland")
        case .aiGeneratedContent: String(localized: "AI Generated or Synthetic Content · China mainland")
        case .vietnamGameLicense: String(localized: "Vietnam Game License")
        case .medicalDevice: String(localized: "Regulated Medical Devices")
        }
    }
}
