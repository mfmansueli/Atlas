//
//  AppInformationPage.swift
//  Atlas
//

import Foundation

/// One page of App Information, in the order of the page strip.
enum AppInformationPage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case appCompliance
    case ageRating
    case accessibility
    case appPrivacy
    case appReview
    case exportCompliance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .appCompliance: String(localized: "App Compliance")
        case .ageRating: String(localized: "Age Rating")
        case .accessibility: String(localized: "Accessibility")
        case .appPrivacy: String(localized: "App Privacy")
        case .appReview: String(localized: "App Review")
        case .exportCompliance: String(localized: "Export Compliance")
        }
    }

    /// The card's symbol in the page strip (board 88).
    var systemImage: String {
        switch self {
        case .general: "info.circle"
        case .appCompliance: "checkmark.shield"
        case .ageRating: "person.crop.square"
        case .accessibility: "accessibility"
        case .appPrivacy: "hand.raised"
        case .appReview: "person.text.rectangle"
        case .exportCompliance: "lock"
        }
    }

    /// Never on the App Store: only App Review and Apple read it. The strip
    /// puts these after its "Only Apple sees" separator.
    var isSeenOnlyByApple: Bool {
        self == .appReview || self == .exportCompliance
    }

    /// The sentence at the top of the section while the page is open.
    func summary(appName: String, version: String?) -> String {
        let version = version ?? ""
        switch self {
        case .general:
            return version.isEmpty
                ? String(localized: "Copyright, categories and how the version is released.")
                : String(localized: "Copyright, categories and how \(version) is released.")
        case .appCompliance: return String(localized: "Rules and permits for some countries or kinds of apps.")
        case .ageRating: return String(localized: "Apple sets \(appName)’s age rating from these answers.")
        case .accessibility: return String(localized: "Accessibility Nutrition Labels: what people can do with each feature, per device.")
        case .appPrivacy: return String(localized: "What data \(appName) collects and why.")
        case .appReview:
            return version.isEmpty
                ? String(localized: "Who Apple contacts and what reviewers need to test the version.")
                : String(localized: "Who Apple contacts and what reviewers need to test \(version).")
        case .exportCompliance: return String(localized: "Whether \(appName) uses encryption that needs documents.")
        }
    }

    /// Over the page's cards, where they show on the App Store. Export
    /// Compliance says whether `version` is on the App Store yet, so
    /// "Not on the App Store" isn't read as the app's state.
    func whereShown(appName: String, version: StorePageVersion? = nil) -> String {
        if self == .exportCompliance, let version, !version.state.isLive {
            return String(localized: "Version \(version.versionString) isn’t on the App Store yet. These answers never show there.")
        }
        return switch self {
        case .general: String(localized: "On the App Store: the category under the name, and the Information section.")
        case .appCompliance: String(localized: "Partly on the App Store: a trader’s details show on \(appName)’s page in the EU.")
        case .ageRating: String(localized: "On the App Store: the age under the name, such as 4+.")
        case .accessibility: String(localized: "On the App Store: the Accessibility section lists what \(appName) supports.")
        case .appPrivacy: String(localized: "On the App Store: the App Privacy section.")
        case .appReview: String(localized: "Not on the App Store. Only App Review reads it.")
        case .exportCompliance: String(localized: "Never shown on the App Store: App Store Connect asks it per build.")
        }
    }
}
