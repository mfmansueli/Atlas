//
//  SubscriptionOfferRules.swift
//  Atlas
//

import Foundation

/// App Store Connect's limits for promotional offers, win-back offers and
/// offer codes, and the checks their names, identifiers and custom codes
/// share. Reference names and identifiers are only seen by the developer;
/// a custom code is what customers type, so it also follows App Review's
/// text rules that apply to it (no other platforms, betas or placeholders).
enum SubscriptionOfferRules {
    static let nameLength = 64
    static let identifierLength = 64
    static let customCodeLength = 64
    /// Active promotional offers, and active offer codes, per subscription.
    static let activePerSubscription = 10
    /// A custom code's redemptions, and one batch of one-time codes.
    static let numberOfCodes = 1...1_000_000
    /// `customerEligibilityPaidSubscriptionDurationInMonths` and the time
    /// since they last subscribed.
    static let eligibilityMonths = 1...60
    /// `customerEligibilityWaitBetweenOffersInMonths`.
    static let waitMonths = 1...60

    /// The name trimmed; problems for an empty or too long one.
    static func nameProblems(_ name: String, label: String) -> [SubscriptionOfferProblem] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [.missingName(label)] }
        return trimmed.count > nameLength ? [.nameTooLong(label, limit: nameLength)] : []
    }

    /// Letters, digits, `_` and `.`, up to 64.
    static func isValidIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty, identifier.count <= identifierLength else { return false }
        return identifier.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == ".")
        }
    }

    /// An identifier from a name: "Half price for 3 months" →
    /// `half_price_for_3_months`.
    static func identifier(from name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        var slug = ""
        for scalar in folded.unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else if !slug.isEmpty, !slug.hasSuffix("_") {
                slug.append("_")
            }
        }
        while slug.hasSuffix("_") { slug.removeLast() }
        return String(slug.prefix(identifierLength))
    }

    /// A custom code as customers type it: uppercase letters and digits.
    static func customCode(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func customCodeProblems(_ code: String, taken: Set<String>) -> [SubscriptionOfferProblem] {
        let valid = !code.isEmpty && code.count <= customCodeLength
            && code.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.alphanumerics.contains($0) }
        guard valid else { return [.invalidCustomCode] }
        var problems: [SubscriptionOfferProblem] = []
        if taken.contains(code) { problems.append(.customCodeTaken(code)) }
        let issues = StoreTextGuidelineCheck.issues(in: code, kinds: [.otherPlatform, .prerelease, .placeholder, .kidsTerms])
        problems += issues.map { .customCodeGuideline($0.message) }
        return problems
    }

    /// Problems for a first and last day: none before today, the last
    /// after the first.
    static func dateProblems(start: Date?, end: Date?, today: Date) -> [SubscriptionOfferProblem] {
        var problems: [SubscriptionOfferProblem] = []
        let calendar = Calendar.current
        if let start, calendar.startOfDay(for: start) < calendar.startOfDay(for: today) { problems.append(.startsInThePast) }
        if let end, calendar.startOfDay(for: end) <= calendar.startOfDay(for: start ?? today) { problems.append(.endsBeforeStart) }
        return problems
    }
}
