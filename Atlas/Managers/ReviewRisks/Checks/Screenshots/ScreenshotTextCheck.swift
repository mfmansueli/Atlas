//
//  ScreenshotTextCheck.swift
//  Atlas
//

import Foundation

/// 2.3.7, 2.3.10, 5.2.5, 2.3.3: what the live screenshots show, from the
/// text Vision read in them (`ReviewRiskScreenshotFacts`).
///
/// - The Store Page's caption rules and Apple's recognitions per
///   screenshot (`ScreenshotTextRules`): “free”, offers, other platforms,
///   “Editors’ Choice” and placeholder text are likely rejections; an
///   amount like “$4.99” is often the app's own content, so it's worth a
///   look only, as are betas, “coming soon” and “For Kids”. The same image
///   in several languages (same checksum) is one risk with every place.
/// - A set whose screenshots mostly don't show the app in use (mostly
///   blank, a system permission alert, a sign-in screen) is worth a look.
struct ScreenshotTextCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.screenshotText

    /// Places listed in one risk's evidence.
    static let evidenceLimit = 6

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let screenshots = facts.screenshots else {
            return .notChecked(facts.gap(
                for: id,
                fallback: String(localized: "Atlas couldn’t read the screenshots from App Store Connect.", comment: "kind:error · App Review check not run")
            ))
        }
        guard !screenshots.screenshots.isEmpty else {
            return .notChecked(String(localized: "No screenshots in App Store Connect to read yet.", comment: "kind:error · App Review check not run"))
        }
        let read = screenshots.screenshots.filter(\.wasRead)
        guard !read.isEmpty else {
            return .notChecked(String(localized: "Atlas couldn’t download or read the screenshots.", comment: "kind:error · App Review check not run"))
        }
        let risks = textRisks(read, appName: facts.appName) + appInUseRisks(read)
        return .risks(risks.sorted(by: ReviewRisk.ordered))
    }

    // MARK: - Text

    /// One screenshot with a finding: the screenshot, and the lines that
    /// show it.
    private struct Place {
        var screenshot: ReviewRiskScreenshot
        var finding: ScreenshotTextFinding
    }

    private func textRisks(_ screenshots: [ReviewRiskScreenshot], appName: String) -> [ReviewRisk] {
        var order: [String] = []
        var groups: [String: [Place]] = [:]
        for screenshot in screenshots {
            for finding in ScreenshotTextRules.findings(in: screenshot.lines, appName: appName) {
                let image = screenshot.checksum.flatMap { $0.isEmpty ? nil : $0 } ?? "\(screenshot.setKey).\(screenshot.slot)"
                let key = "\(finding.kind.rawValue)|\(image)"
                if groups[key] == nil { order.append(key) }
                groups[key, default: []].append(Place(screenshot: screenshot, finding: finding))
            }
        }
        return order.compactMap { groups[$0] }.compactMap(risk)
    }

    private func risk(_ places: [Place]) -> ReviewRisk? {
        guard let first = places.first else { return nil }
        let kind = first.finding.kind
        let shot = first.screenshot
        var phrases: [String] = []
        for phrase in places.flatMap(\.finding.phrases) where !phrases.contains(where: { $0.lowercased() == phrase.lowercased() }) {
            phrases.append(phrase)
        }
        let phrase = ReviewRiskEvidence.cut(phrases.first ?? "", limit: 20)
        let evidence = places.prefix(Self.evidenceLimit).map { place in
            ReviewRiskEvidence(
                place: place.screenshot.place,
                excerpt: Self.excerpt(place.finding.phrases, in: place.screenshot.lines),
                locale: place.screenshot.locale
            )
        }
        var subject = "\(shot.setKey).\(shot.slot).\(kind.rawValue)"
        if let checksum = shot.checksum, !checksum.isEmpty { subject += ".\(checksum.prefix(8))" }
        return ReviewRisk(
            check: id,
            subject: subject,
            guideline: kind.guideline,
            level: Self.level(of: kind),
            title: Self.title(kind, slot: shot.slot, phrase: phrase),
            why: Self.why(kind),
            evidence: Array(evidence),
            howSure: Self.howSure(of: kind),
            fix: ReviewRiskFix(
                advice: Self.advice(kind, slot: shot.slot, quoted: first.finding.quotedPhrases),
                tool: "propose_screenshot_file",
                arguments: [
                    "locale": shot.locale,
                    "displayType": shot.displayType.mcpValue,
                    "position": "\(shot.slot)",
                ]
            )
        )
    }

    static func level(of kind: ScreenshotTextFindingKind) -> ReviewRiskLevel {
        switch kind {
        case .free, .offer, .otherPlatform, .appleRecognition, .placeholder: .likely
        case .amount, .prerelease, .comingSoon, .kidsTerms: .check
        }
    }

    /// Vision can misread a word, and an amount, a beta or a shelf “for
    /// kids” is often the app's own content.
    static func howSure(of kind: ScreenshotTextFindingKind) -> HowSure {
        switch kind {
        case .free, .offer, .otherPlatform, .appleRecognition, .placeholder, .comingSoon: .fairlySure
        case .amount, .prerelease, .kidsTerms: .notVerySure
        }
    }

    private static func title(_ kind: ScreenshotTextFindingKind, slot: Int, phrase: String) -> String {
        switch kind {
        case .amount:
            String(localized: "Screenshot \(slot) shows a price", comment: "kind:suggestion-title · an App Review risk")
        case .placeholder:
            String(localized: "Screenshot \(slot) shows placeholder text", comment: "kind:suggestion-title · an App Review risk")
        case .otherPlatform:
            String(localized: "Screenshot \(slot) names “\(phrase)”", comment: "kind:suggestion-title · an App Review risk")
        case .comingSoon:
            String(localized: "Screenshot \(slot) promises “\(phrase)”", comment: "kind:suggestion-title · an App Review risk")
        case .free, .offer, .appleRecognition, .prerelease, .kidsTerms:
            String(localized: "Screenshot \(slot) shows “\(phrase)”", comment: "kind:suggestion-title · an App Review risk")
        }
    }

    private static func why(_ kind: ScreenshotTextFindingKind) -> String {
        switch kind {
        case .free:
            String(
                localized: "App Review rejects “free” and trial lengths in screenshots (Guideline 2.3.7).",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .offer:
            String(localized: "App Review rejects discounts and offers in screenshots (Guideline 2.3.7).", comment: "kind:suggestion-why · an App Review risk")
        case .amount:
            String(
                localized: "Prices in screenshots break Guideline 2.3.7, unless it’s the app’s own content.",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .otherPlatform:
            String(
                localized: "App Review rejects other platforms and their stores in screenshots (Guideline 2.3.10).",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .appleRecognition:
            String(
                localized: "Apple’s awards and recognitions can’t appear in screenshots (Guideline 5.2.5).",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .placeholder:
            String(
                localized: "App Review rejects placeholder text in metadata and screenshots (Guideline 2.1).",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .prerelease:
            String(
                localized: "Screenshots of betas and demos break Guideline 2.2; check it isn’t the app’s own content.",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .comingSoon:
            String(
                localized: "Screenshots show what this version does; “coming soon” breaks Guideline 2.3.",
                comment: "kind:suggestion-why · an App Review risk"
            )
        case .kidsTerms:
            String(
                localized: "“For Kids” is only for the Kids Category (Guideline 2.3.8); check it isn’t app content.",
                comment: "kind:suggestion-why · an App Review risk"
            )
        }
    }

    private static func advice(_ kind: ScreenshotTextFindingKind, slot: Int, quoted: String) -> String {
        switch kind {
        case .amount, .prerelease, .kidsTerms:
            String(
                localized: "If \(quoted) isn’t the app’s own content, replace screenshot \(slot) or change its caption.",
                comment: "kind:description · how to fix an App Review risk"
            )
        default:
            String(
                localized: "Replace screenshot \(slot) with one without \(quoted), or change its caption.",
                comment: "kind:description · how to fix an App Review risk"
            )
        }
    }

    /// The lines that show the phrases, else the phrases.
    static func excerpt(_ phrases: [String], in lines: [String]) -> String {
        let wanted = phrases.map { ArtworkForbiddenText.fold($0).lowercased() }
        let shown = lines.filter { line in
            let folded = ArtworkForbiddenText.fold(line).lowercased()
            return wanted.contains { folded.contains($0) }
        }
        return (shown.isEmpty ? phrases : shown).joined(separator: " · ")
    }

    // MARK: - The app in use (2.3.3)

    private func appInUseRisks(_ screenshots: [ReviewRiskScreenshot]) -> [ReviewRisk] {
        var order: [String] = []
        var sets: [String: [ReviewRiskScreenshot]] = [:]
        for screenshot in screenshots {
            if sets[screenshot.setKey] == nil { order.append(screenshot.setKey) }
            sets[screenshot.setKey, default: []].append(screenshot)
        }
        return order.compactMap { key -> ReviewRisk? in
            guard let set = sets[key], let first = set.first else { return nil }
            let out = set.filter(\.looksOutOfUse)
            // Most of the set: one sign-in screen among six is fine.
            guard !out.isEmpty, out.count * 2 > set.count else { return nil }
            let display = first.displayType
            return ReviewRisk(
                check: id,
                subject: "\(key).appInUse",
                guideline: "2.3.3",
                level: .check,
                title: String(localized: "Screenshots may not show the app", comment: "kind:suggestion-title · an App Review risk (2.3.3)"),
                why: String(
                    localized: "\(display.shortTitle): \(out.count) of \(set.count) look blank, a sign-in or a system alert; App Review wants the app in use.",
                    comment: "kind:suggestion-why · an App Review risk (2.3.3)"
                ),
                evidence: out.prefix(Self.evidenceLimit).map { ReviewRiskEvidence(place: $0.place, excerpt: Self.look(of: $0), locale: $0.locale) },
                howSure: out.count == set.count && set.count >= 3 ? .fairlySure : .notVerySure,
                fix: ReviewRiskFix(
                    advice: String(
                        localized: "Replace them with screens of the app in use, from Screenshot Autopilot or files of your own.",
                        comment: "kind:description · how to fix an App Review risk"
                    ),
                    tool: "propose_screenshot_file",
                    arguments: ["locale": first.locale, "displayType": display.mcpValue]
                )
            )
        }
    }

    /// "System alert: “Lumen” Would Like to…", "Sign-in screen: Sign In ·
    /// Password" or "Mostly blank".
    private static func look(of screenshot: ReviewRiskScreenshot) -> String {
        if let alert = screenshot.systemAlertLine {
            return String(localized: "System alert: \(alert)", comment: "kind:label · what a screenshot shows")
        }
        if !screenshot.signInLines.isEmpty {
            return String(localized: "Sign-in screen: \(screenshot.signInLines.joined(separator: " · "))", comment: "kind:label · what a screenshot shows")
        }
        return String(localized: "Mostly blank", comment: "kind:label · what a screenshot shows")
    }
}
