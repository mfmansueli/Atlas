//
//  ChinaDeclarationChoice.swift
//  Atlas
//

import Foundation

/// The ways to answer a China mainland declaration (AI-generated content,
/// the Security Assessment): Yes, No, or stop selling there, which is the
/// one Apple's API takes, through Review & Push. An app that isn't sold
/// there has only Yes and No.
enum ChinaDeclarationChoice: String, CaseIterable, Identifiable, Hashable, Sendable {
    case yes
    // swiftlint:disable:next identifier_name
    case no
    case stopSelling

    var id: String { rawValue }

    static func choices(isSoldThere: Bool) -> [Self] {
        isSoldThere ? allCases : [.yes, .no]
    }

    func title(for rule: ComplianceRule) -> String {
        switch (self, rule) {
        case (.yes, .securityAssessment): String(localized: "Yes, it has features that need a Security Assessment")
        case (.no, .securityAssessment): String(localized: "No, nothing that needs one")
        case (.yes, _): String(localized: "Yes, it offers AI generation or synthetic content")
        case (.no, _): String(localized: "No, or it’s off or geoblocked in China mainland")
        case (.stopSelling, _): String(localized: "Stop selling in China mainland")
        }
    }

    func detail(for rule: ComplianceRule, appName: String, isSoldThere: Bool) -> String {
        if self == .no, !isSoldThere {
            return String(localized: "\(appName) isn’t sold in China mainland, so No is the answer there.")
        }
        return switch (self, rule) {
        case (.yes, .securityAssessment):
            String(localized: """
            For example sharing AI-generated content with other people, or end-to-end encrypted messaging. \
            App Store Connect takes the proof it passed and the report.
            """)
        case (.no, .securityAssessment):
            String(localized: "Answered No in App Store Connect.")
        case (.yes, _):
            String(localized: """
            Chatbots, image or video generation, voice or face changes. \
            App Store Connect takes the model’s or algorithm’s approved filing.
            """)
        case (.no, _):
            String(localized: "Answered No in App Store Connect.")
        case (.stopSelling, _):
            String(localized: """
            \(appName) stays everywhere else. It’s the one Apple’s API takes: the change waits in Review & Push. \
            App Store Connect still asks, and the answer is No.
            """)
        }
    }
}
