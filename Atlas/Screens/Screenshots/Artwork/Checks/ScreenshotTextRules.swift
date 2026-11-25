//
//  ScreenshotTextRules.swift
//  Atlas
//

import Foundation

/// What App Review rejects in the text read in a screenshot: the Store
/// Page's caption rules (`StoreTextGuidelineCheck.issues(inCaption:)`)
/// with pricing split into “free” and trials, offers and amounts, plus
/// Apple's recognitions (`ArtworkForbiddenText`). Words that are the
/// app's own name are left out (“Free Notes” naming itself).
enum ScreenshotTextRules {
    static func findings(in lines: [String], appName: String = "") -> [ScreenshotTextFinding] {
        findings(in: lines.joined(separator: "\n"), appName: appName)
    }

    static func findings(in text: String, appName: String = "") -> [ScreenshotTextFinding] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let name = appName.lowercased()
        func kept(_ phrases: [String]) -> [String] {
            phrases.filter { name.isEmpty || !name.contains($0.lowercased()) }
        }
        var found: [ScreenshotTextFindingKind: [String]] = [:]
        for issue in StoreTextGuidelineCheck.issues(inCaption: text) {
            switch issue.kind {
            case .pricing:
                let free = StoreTextGuidelineCheck.phrases(in: text, matching: StoreTextGuidelinePatterns.free + StoreTextGuidelinePatterns.trials)
                let freeKeys = Set(free.map { $0.lowercased() })
                found[.free, default: []] += free
                for phrase in issue.phrases where !freeKeys.contains(phrase.lowercased()) {
                    found[isAmount(phrase) ? .amount : .offer, default: []].append(phrase)
                }
            case .otherPlatform: found[.otherPlatform, default: []] += issue.phrases
            case .placeholder: found[.placeholder, default: []] += issue.phrases
            case .prerelease: found[.prerelease, default: []] += issue.phrases
            case .comingSoon: found[.comingSoon, default: []] += issue.phrases
            case .kidsTerms: found[.kidsTerms, default: []] += issue.phrases
            case .unverifiableClaim, .otherApp, .emphasis: continue
            }
        }
        found[.appleRecognition] = ArtworkForbiddenText.matches(in: text).filter { $0.kind == .appleRecognition }.map(\.snippet)
        return ScreenshotTextFindingKind.allCases.compactMap { kind in
            let phrases = unique(kept(found[kind] ?? []))
            return phrases.isEmpty ? nil : ScreenshotTextFinding(kind: kind, phrases: phrases)
        }
    }

    /// "$4.99", "R$ 9,90", "9 dollars": a number with no percent sign.
    static func isAmount(_ phrase: String) -> Bool {
        phrase.contains(where: \.isNumber) && !phrase.contains("%") && !phrase.contains("％")
    }

    private static func unique(_ phrases: [String]) -> [String] {
        var seen: Set<String> = []
        return phrases.filter { seen.insert($0.lowercased()).inserted }
    }
}
