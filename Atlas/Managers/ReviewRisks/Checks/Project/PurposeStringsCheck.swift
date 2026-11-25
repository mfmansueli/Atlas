//
//  PurposeStringsCheck.swift
//  Atlas
//

import Foundation

/// 5.1.1(ii), ITMS-90683: every permission the app asks for needs a text
/// (purpose string) that says what the app does with it. Reads the Swift
/// code and the project: an API in use with no text blocks the build (iOS
/// stops the app when it asks); a text that's short or generic ("We need
/// access") is a common rejection; a text left in the development language
/// while the app and its store speak others is worth a look.
struct PurposeStringsCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.purposeStrings
    /// Shorter than this rarely says what the app does with the access.
    static let shortLimit = 25
    /// The same for Chinese, Japanese and Korean, which say more per character.
    static let shortLimitCJK = 10
    static let evidenceLimit = 6

    /// Texts App Review reads as saying nothing, lowercased without the end's
    /// punctuation; short ones are caught by length.
    static let genericTexts: Set<String> = [
        "this app requires your permission", "we need your permission to continue", "allow access to continue",
        "access is required for this feature", "required for the app to work", "needed for app functionality",
        "this permission is required", "this app needs your permission", "the app needs your permission",
    ]

    /// "This app needs access to your camera", "We require access to the photo library".
    private static let genericPattern = try? NSRegularExpression(
        pattern: #"^((this|the) app|app|we|\S+) (needs?|requires?|wants?|would like) (to )?"#
            + #"(access|permission|your permission)( to)?( use)?( (your|the))?( [\p{L}]+){0,2}$"#
    )

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let project = ReviewRiskProjectCheckSupport.readable(facts) else {
            return .notChecked(ReviewRiskProjectCheckSupport.unreadableReason(facts))
        }
        var risks = missing(project) + vague(project)
        if let untranslated = untranslated(project, texts: facts.texts) { risks.append(untranslated) }
        return .risks(risks)
    }

    // MARK: - Missing

    private func missing(_ project: ReviewRiskProjectFacts) -> [ReviewRisk] {
        ReviewRiskPermission.allCases.compactMap { permission -> ReviewRisk? in
            let uses = project.uses(permission)
            guard !uses.isEmpty, project.purposeString(for: permission) == nil, let key = permission.keys.first else { return nil }
            let count = uses.count
            let name = permission.name
            let why = permission.missingLevel == .blocksReview
                ? String(
                    localized: "The code asks for it in \(count) places; iOS stops the app and App Store Connect refuses the build.",
                    comment: "kind:why · App Review risk: a permission text is missing; the number of places in the code"
                )
                : String(
                    localized: "The code uses it in \(count) places; without the text, iOS won’t ask and it fails.",
                    comment: "kind:why · App Review risk: Face ID's permission text is missing; the number of places in the code"
                )
            return ReviewRisk(
                check: id,
                subject: "missing.\(key)",
                level: permission.missingLevel,
                title: String(
                    localized: "\(name) permission text missing",
                    comment: "kind:title · App Review risk: a permission's text (purpose string) is missing, e.g. Camera"
                ),
                why: why,
                evidence: [ReviewRiskEvidence(place: "Info.plist · \(key)")] + ReviewRiskProjectCheckSupport.evidence(uses),
                howSure: .fairlySure,
                fix: ReviewRiskFix(
                    advice: String(
                        localized: "Add \(key) to the target’s Info.plist (the Info tab), saying what the app does with it, with an example.",
                        comment: "kind:body · how to fix an App Review risk; the Info.plist key"
                    )
                )
            )
        }
    }

    // MARK: - Vague

    private func vague(_ project: ReviewRiskProjectFacts) -> [ReviewRisk] {
        let missingKeys = Set(ReviewRiskPermission.allCases.filter { !project.uses($0).isEmpty && project.purposeString(for: $0) == nil }
            .flatMap(\.keys))
        return project.purposeStrings.values.sorted { $0.key < $1.key }.compactMap { purpose -> ReviewRisk? in
            guard !missingKeys.contains(purpose.key), Self.isVague(purpose.value, key: purpose.key) else { return nil }
            let name = ReviewRiskPermission.permission(forKey: purpose.key)?.name ?? purpose.key
            let count = purpose.value.trimmingCharacters(in: .whitespacesAndNewlines).count
            return ReviewRisk(
                check: id,
                subject: "vague.\(purpose.key)",
                level: .likely,
                title: String(
                    localized: "\(name) permission text too vague",
                    comment: "kind:title · App Review risk: a permission's text doesn't say why, e.g. Camera"
                ),
                why: String(
                    localized: "It’s \(count) characters and doesn’t say what the app does with the access.",
                    comment: "kind:why · App Review risk: a vague permission text; its length in characters"
                ),
                evidence: [ReviewRiskEvidence(place: purpose.place, excerpt: purpose.value)],
                howSure: .fairlySure,
                fix: ReviewRiskFix(
                    advice: String(
                        localized: "Say what the app does with it, with an example: “Scans receipts so you can file expenses.”",
                        comment: "kind:body · how to fix an App Review risk"
                    )
                )
            )
        }
    }

    /// Empty, the key itself, short, or a stock phrase without a reason.
    static func isVague(_ value: String, key: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == key || trimmed.contains("UsageDescription") { return true }
        let isCJK = trimmed.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value) || (0xAC00...0xD7AF).contains(scalar.value)
        }
        if trimmed.count < (isCJK ? shortLimitCJK : shortLimit) { return true }
        let normalized = trimmed.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if genericTexts.contains(normalized) { return true }
        guard let genericPattern else { return false }
        return genericPattern.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil
    }

    // MARK: - Not translated

    private func untranslated(_ project: ReviewRiskProjectFacts, texts: ReviewRiskTextFacts?) -> ReviewRisk? {
        guard let texts else { return nil }
        let store = Set((texts.texts.map(\.locale) + [texts.primaryLocale]).map(ReviewRiskLanguageCode.base))
        guard store.count > 1 else { return nil }
        let development = ReviewRiskLanguageCode.base(project.developmentLanguage)
        let wanted = store.intersection(project.languages).subtracting([development])
        guard !wanted.isEmpty else { return nil }
        var evidence: [ReviewRiskEvidence] = []
        var count = 0
        for purpose in project.purposeStrings.values.sorted(by: { $0.key < $1.key }) where purpose.isWritten {
            let missing = wanted.subtracting(purpose.languages)
            guard !missing.isEmpty else { continue }
            count += 1
            guard evidence.count < Self.evidenceLimit else { continue }
            let name = ReviewRiskPermission.permission(forKey: purpose.key)?.name ?? purpose.key
            let languages = missing.sorted().map(ReviewRiskLanguageCode.name).formatted(.list(type: .and))
            evidence.append(ReviewRiskEvidence(place: "\(name) · \(languages)", excerpt: purpose.value))
        }
        guard count > 0 else { return nil }
        let developmentName = ReviewRiskLanguageCode.name(development)
        return ReviewRisk(
            check: id,
            subject: "translations",
            level: .check,
            title: count == 1
                ? String(localized: "Permission text not translated", comment: "kind:title · App Review risk: one permission text has no translation")
                : String(localized: "Permission texts not translated", comment: "kind:title · App Review risk: permission texts have no translation"),
            why: count == 1
                ? String(
                    localized: "1 permission text shows in \(developmentName) in languages the app and its store use.",
                    comment: "kind:why · App Review risk: one untranslated permission text; the development language"
                )
                : String(
                    localized: "\(count) permission texts show in \(developmentName) in languages the app and its store use.",
                    comment: "kind:why · App Review risk: untranslated permission texts; how many, and the development language"
                ),
            evidence: evidence,
            howSure: .fairlySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Translate them in InfoPlist.xcstrings (or each language’s InfoPlist.strings).",
                    comment: "kind:body · how to fix an App Review risk"
                )
            )
        )
    }
}
