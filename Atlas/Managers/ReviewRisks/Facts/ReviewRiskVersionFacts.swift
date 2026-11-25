//
//  ReviewRiskVersionFacts.swift
//  Atlas
//

import Foundation

/// The version the checks read (the one being prepared, else the live
/// one) and its What's New per language, with what waits in Review & Push
/// laid on top.
struct ReviewRiskVersionFacts: Hashable, Sendable {
    var versionID: String
    /// e.g. "1.4".
    var versionString: String
    /// App Store Connect's state, e.g. "PREPARE_FOR_SUBMISSION".
    var state: String
    /// The app's first version: it has no What's New.
    var isFirstVersion = false
    /// Not live or in review yet: its texts can still change.
    var isEditable = true
    /// The app's primary store locale, e.g. "en-US".
    var primaryLocale = "en-US"
    /// What's New by store locale code, every language of the version
    /// ("" when it's empty), the queued text where one waits.
    var whatsNew: [String: String] = [:]
    /// The locales whose What's New waits in Review & Push.
    var queuedWhatsNew: Set<String> = []

    init(
        versionID: String,
        versionString: String,
        state: String,
        isFirstVersion: Bool = false,
        isEditable: Bool = true,
        primaryLocale: String = "en-US",
        whatsNew: [String: String] = [:],
        queuedWhatsNew: Set<String> = []
    ) {
        self.versionID = versionID
        self.versionString = versionString
        self.state = state
        self.isFirstVersion = isFirstVersion
        self.isEditable = isEditable
        self.primaryLocale = primaryLocale
        self.whatsNew = whatsNew
        self.queuedWhatsNew = queuedWhatsNew
    }

    /// The locales, primary first, then by code.
    var locales: [String] {
        whatsNew.keys.sorted { lhs, rhs in
            if lhs == primaryLocale { return true }
            if rhs == primaryLocale { return false }
            return lhs < rhs
        }
    }
}
