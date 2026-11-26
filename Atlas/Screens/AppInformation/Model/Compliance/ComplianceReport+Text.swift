//
//  ComplianceReport+Text.swift
//  Atlas
//

import Foundation

// What the App Compliance page says: the page's status in the page strip,
// the line at the top, and each regulation's explanation.
extension ComplianceReport {
    /// The page strip's line: "2 need you", "1 to finish at Apple",
    /// "Up to date".
    var status: String {
        if needCount > 0 {
            return needCount == 1 ? String(localized: "1 needs you") : String(localized: "\(needCount) need you")
        }
        if toEnterCount > 0 { return String(localized: "\(toEnterCount) to finish at Apple") }
        return String(localized: "Up to date")
    }

    /// The start of the line at the top of the page.
    var headline: String {
        var parts: [String] = []
        if needCount > 0 {
            parts.append(needCount == 1 ? String(localized: "1 needs your answer") : String(localized: "\(needCount) need your answer"))
        }
        if toEnterCount > 0 {
            parts.append(String(localized: "\(toEnterCount) to enter in App Store Connect"))
        }
        guard !parts.isEmpty else { return String(localized: "Everything answered or checked") }
        if passCount > 0 { parts.append(String(localized: "\(passCount) checked")) }
        return parts.joined(separator: " · ")
    }

    private var categoryName: String { AppCategory.name(for: primaryCategory) }

    /// A passing regulation's title: "Vietnam Game License · not needed".
    func passTitle(for rule: ComplianceRule) -> String {
        "\(rule.name) · \(passNote(for: rule))"
    }

    private func passNote(for rule: ComplianceRule) -> String {
        switch rule {
        case .traderStatus: traderPassNote
        case .icpFilingNumber: icpPassNote
        case .securityAssessment, .aiGeneratedContent: Self.declaredNote
        case .vietnamGameLicense: gameLicense == .needed ? Self.declaredNote : Self.notNeededNote
        case .medicalDevice: medicalDevice.isAsked ? Self.declaredNote : Self.notNeededNote
        }
    }

    private static var notNeededNote: String { String(localized: "not needed") }
    private static var declaredNote: String { String(localized: "declared") }
    private static var noCountriesNote: String { String(localized: "no countries yet") }

    private var traderPassNote: String {
        switch trader {
        case .noCountriesYet: Self.noCountriesNote
        case .declared: Self.declaredNote
        default: Self.notNeededNote
        }
    }

    private var icpPassNote: String {
        switch icp {
        case .noCountriesYet: Self.noCountriesNote
        case .noProblem: String(localized: "nothing missing")
        default: Self.notNeededNote
        }
    }

    /// The person marked it as declared in App Store Connect, which is
    /// all that makes it pass: its row offers Change.
    func isMarkedDeclared(_ rule: ComplianceRule) -> Bool {
        guard state(of: rule) == .passes, answers.declared.contains(rule) else { return false }
        switch rule {
        case .vietnamGameLicense: return gameLicense == .needed
        case .medicalDevice: return medicalDevice.isAsked
        case .securityAssessment, .aiGeneratedContent: return true
        case .traderStatus, .icpFilingNumber: return false
        }
    }

    /// The line under a regulation's title.
    func detail(for rule: ComplianceRule) -> String {
        switch rule {
        case .traderStatus: traderDetail
        case .icpFilingNumber: icpDetail
        case .securityAssessment: securityAssessmentDetail
        case .aiGeneratedContent: aiContentDetail
        case .vietnamGameLicense: gameLicenseDetail
        case .medicalDevice: medicalDeviceDetail
        }
    }

    private var traderDetail: String {
        switch trader {
        case .noCountriesYet:
            String(localized: "Checked once \(appName) has countries and regions in App Store Connect.")
        case .notSoldInEU:
            String(localized: "\(appName) isn’t sold in the European Union, so its page shows no trader details.")
        case .declared:
            String(localized: "Declared in App Store Connect. Apple’s API doesn’t say whether as a trader or a non-trader.")
        case .notProvided:
            String(localized: "Whether you sell as a trader. A trader’s name, address, phone and email show on \(appName)’s page in the EU.")
        case .verificationFailed:
            String(localized: "Apple couldn’t verify your trader details, so \(appName) can’t be sold in the EU. Correct them in App Store Connect.")
        case .verificationMissing:
            String(localized: "Apple is still waiting to verify your trader details: the codes it sends to the phone and the email.")
        }
    }

    private var icpDetail: String {
        switch icp {
        case .noCountriesYet:
            String(localized: "Checked once \(appName) has countries and regions in App Store Connect.")
        case .notSoldInChina:
            String(localized: "\(appName) isn’t sold in China mainland, so it needs no ICP Filing Number.")
        case .noProblem:
            String(localized: "\(appName) is sold in China mainland and Apple shows nothing missing there.")
        case .missing:
            String(localized: "\(appName) sells in China mainland without an ICP Filing Number. Apple needs one for \(appName) to stay.")
        case .invalid:
            String(localized: "Apple says \(appName)’s ICP Filing Number isn’t valid. \(appName) needs a valid one to stay in China mainland.")
        }
    }

    private var gameLicenseDetail: String {
        switch gameLicense {
        case .notAGame:
            return String(localized: "\(appName) isn’t a game (category: \(categoryName)), so it doesn’t need a Vietnam game license.")
        case .notSoldInVietnam:
            return String(localized: "\(appName) is a game, but it isn’t sold in Vietnam.")
        case .needed:
            if answers.declared.contains(.vietnamGameLicense) {
                return String(localized: "You marked the license as added in App Store Connect.")
            }
            let rule = String(localized: "\(appName) is a game sold in Vietnam, where games need a license from the Ministry of Information and Communications.")
            return rule + " " + String(localized: "Add its number in App Store Connect.")
        case .flaggedByApple:
            return String(localized: "Apple says \(appName)’s game registration number for Vietnam is missing or not verified. Add it in App Store Connect.")
        }
    }

    private var medicalDeviceDetail: String {
        switch medicalDevice {
        case .notNeeded:
            return String(localized: "\(appName) is in \(categoryName), and Medical or Treatment Information isn’t frequent in Age Rating, so there’s nothing to declare.")
        case .notSoldThere:
            return String(localized: "\(appName) isn’t sold in the European Economic Area, the United Kingdom or the United States, where the declaration applies.")
        case let .category(id):
            if answers.declared.contains(.medicalDevice) { return String(localized: "You marked it as declared in App Store Connect.") }
            if let answer = medicalDeviceAnswer { return answer }
            return String(localized: "\(appName) is in \(AppCategory.name(for: id)), so Apple asks whether it’s a regulated medical device. Most apps answer No. Declare it in App Store Connect.")
        case .frequentMedicalInformation:
            if answers.declared.contains(.medicalDevice) { return String(localized: "You marked it as declared in App Store Connect.") }
            if let answer = medicalDeviceAnswer { return answer }
            return String(localized: "Age Rating says Medical or Treatment Information is frequent, so Apple asks whether \(appName) is a regulated medical device. Declare it in App Store Connect.")
        }
    }

    /// The accepted answer, still to be declared in App Store Connect.
    private var medicalDeviceAnswer: String? {
        switch answers.regulatedMedicalDevice {
        case true?: String(localized: "Your answer: \(appName) is a regulated medical device. Declare it in App Store Connect, with its registration, then mark it as declared.")
        case false?: String(localized: "Your answer: \(appName) isn’t a regulated medical device. Answer No in App Store Connect, then mark it as declared.")
        case nil: nil
        }
    }

    /// Why the built-in check suggests "trader", or how to decide without
    /// a suggestion.
    var traderReason: String {
        let fact = suggestsTrader
            ? String(localized: "\(appName) sells subscriptions or in-app purchases in the EU.")
            : String(localized: "Apple asks everyone who sells in the EU.")
        let guidance = String(localized: "Apple’s guidance: if you make money from the app, you’re most likely a trader.")
        let call = String(localized: "It’s your call: Atlas prepares it, it never decides it.")
        return [fact, guidance, call].joined(separator: " ")
    }
}
