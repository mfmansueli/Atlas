//
//  LinksCheck.swift
//  Atlas
//

import Foundation

/// 5.1.1(i) and 1.5: every app needs a Privacy Policy URL (the primary
/// language's is the one App Store Connect insists on) and a Support URL
/// in each language, and App Review opens the links: one that answers
/// 404 or 410 or doesn't answer is a common rejection, a server error or
/// a refusal only worth a look (it may block Atlas, not App Review), and
/// an http:// address worth a look. URLs waiting in Review & Push count
/// over the pushed ones (they aren't opened until pushed).
struct LinksCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.links

    /// Where a URL is used: a listing field, or the description's Terms
    /// of Use link.
    enum Place: Hashable, Sendable {
        case field(ListingField)
        case terms

        /// "Support URL", "Terms of Use link".
        var name: String {
            switch self {
            case let .field(field): field.title
            case .terms: String(localized: "Terms of Use link", comment: "kind:label · a link in the description")
            }
        }

        /// The field an assistant proposes the fix in.
        var field: ListingField {
            switch self {
            case let .field(field): field
            case .terms: .description
            }
        }

        /// Required ones first, so a URL used twice is named by the one
        /// that matters most.
        var order: Int {
            switch self {
            case .field(.privacyPolicyURL): 0
            case .field(.supportURL): 1
            case .terms: 2
            default: 3
            }
        }
    }

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let links = facts.links else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the app’s links.", comment: "kind:error")))
        }
        let privacy = Self.merged(links.privacyPolicyURLs, queued: facts.texts, field: .privacyPolicyURL)
        let support = Self.merged(links.supportURLs, queued: facts.texts, field: .supportURL)
        let marketing = Self.merged(links.marketingURLs, queued: facts.texts, field: .marketingURL)
        let locales = Self.locales(links, also: [privacy, support, marketing])
        var risks: [ReviewRisk] = []
        if let risk = privacyRisk(privacy, links: links, locales: locales) { risks.append(risk) }
        let noSupport = locales.filter { support[$0] == nil }
        if !noSupport.isEmpty { risks.append(supportRisk(noSupport)) }
        let uses = Self.uses(privacy: privacy, support: support, marketing: marketing, terms: links.termsURLs, locales: locales)
        for url in uses.keys.sorted() {
            let places = uses[url] ?? []
            if let status = links.statuses[url], let risk = brokenRisk(url, status: status, places: places) { risks.append(risk) }
            if url.lowercased().hasPrefix("http://") { risks.append(insecureRisk(url, places: places)) }
        }
        return .risks(risks)
    }

    // MARK: - Reading

    /// Each distinct URL with every place and language it's written in.
    private static func uses(
        privacy: [String: String], support: [String: String], marketing: [String: String], terms: [String: [String]], locales: [String]
    ) -> [String: [(place: Place, locale: String)]] {
        var uses: [String: [(place: Place, locale: String)]] = [:]
        for locale in locales {
            if let url = privacy[locale] { uses[url, default: []].append((place: .field(.privacyPolicyURL), locale: locale)) }
            if let url = support[locale] { uses[url, default: []].append((place: .field(.supportURL), locale: locale)) }
            for url in terms[locale] ?? [] { uses[url, default: []].append((place: .terms, locale: locale)) }
            if let url = marketing[locale] { uses[url, default: []].append((place: .field(.marketingURL), locale: locale)) }
        }
        return uses
    }

    /// The pushed URLs, with the ones waiting in Review & Push over them;
    /// empty ones left out.
    static func merged(_ pushed: [String: String], queued texts: ReviewRiskTextFacts?, field: ListingField) -> [String: String] {
        var urls = pushed.compactMapValues(trimmed)
        for text in texts?.listing(field) ?? [] where text.isQueued {
            urls[text.locale] = trimmed(text.text)
        }
        return urls
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// The store's languages, primary first; else every language a URL is in.
    static func locales(_ links: ReviewRiskLinkFacts, also maps: [[String: String]]) -> [String] {
        var locales = links.locales.isEmpty ? maps.flatMap(\.keys).sorted() : links.locales
        var seen: Set<String> = []
        locales = locales.filter { seen.insert($0).inserted }
        if let index = locales.firstIndex(of: links.primaryLocale), index > 0 { locales.insert(locales.remove(at: index), at: 0) }
        return locales
    }

    /// "German", for a locale code.
    static func name(of locale: String) -> String {
        StoreLocaleCatalog.locale(code: locale)?.name ?? locale
    }

    private static func place(_ place: Place, _ locale: String) -> String {
        String(localized: "\(place.name) · \(name(of: locale))", comment: "kind:label · where an App Review risk shows")
    }

    // MARK: - Missing

    /// No Privacy Policy URL at all, or none in the primary language.
    private func privacyRisk(_ privacy: [String: String], links: ReviewRiskLinkFacts, locales: [String]) -> ReviewRisk? {
        let primary = links.primaryLocale
        guard privacy[primary] == nil else { return nil }
        let others = privacy.count
        let fix = ReviewRiskFix(
            advice: String(
                localized: "Add your Privacy Policy URL in App Information → Privacy URLs.",
                comment: "kind:description · how to fix an App Review risk"
            ),
            tool: "propose_listing_text",
            arguments: ["field": ListingField.privacyPolicyURL.rawValue, "locales": primary]
        )
        let evidence = [ReviewRiskEvidence(place: Self.place(.field(.privacyPolicyURL), primary), locale: primary)]
        if others == 0 {
            return ReviewRisk(
                check: id, subject: "privacyPolicy.missing", level: .blocksReview,
                title: String(localized: "No Privacy Policy URL", comment: "kind:title · an App Review risk"),
                why: locales.count > 1
                    ? String(
                        localized: "App Review rejects apps without a Privacy Policy URL; none of \(locales.count) languages has one.",
                        comment: "kind:description · why an App Review risk matters"
                    )
                    : String(
                        localized: "App Review rejects every app without a Privacy Policy URL (5.1.1).",
                        comment: "kind:description · why an App Review risk matters"
                    ),
                evidence: evidence, howSure: .sure, fix: fix
            )
        }
        return ReviewRisk(
            check: id, subject: "privacyPolicy.primary", level: .blocksReview,
            title: String(localized: "Privacy Policy URL missing in \(Self.name(of: primary))", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Your primary language has none, while \(others) other languages do. App Store Connect needs it there.",
                comment: "kind:description · why an App Review risk matters"
            ),
            evidence: evidence, howSure: .fairlySure, fix: fix
        )
    }

    private func supportRisk(_ missing: [String]) -> ReviewRisk {
        let title = missing.count == 1
            ? String(localized: "No Support URL in \(Self.name(of: missing[0]))", comment: "kind:title · an App Review risk")
            : String(localized: "No Support URL in \(missing.count) languages", comment: "kind:title · an App Review risk")
        return ReviewRisk(
            check: id, subject: "supportURL.missing", guideline: "1.5", level: .blocksReview, title: title,
            why: String(
                localized: "App Store Connect needs a Support URL in every language; \(missing.count) have none.",
                comment: "kind:description · why an App Review risk matters"
            ),
            evidence: missing.map { ReviewRiskEvidence(place: Self.place(.field(.supportURL), $0), locale: $0) },
            howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add a Support URL with a way to contact you in each language.",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                tool: "propose_listing_text",
                arguments: ["field": ListingField.supportURL.rawValue, "locales": missing.joined(separator: ",")]
            )
        )
    }

    // MARK: - Opening

    /// A link that doesn't open: 404, 410 or no answer is likely
    /// rejected; a server error or a refusal (401, 403, 429…) may be the
    /// server blocking Atlas, so only worth a look. A Marketing URL isn't
    /// required: worth a look either way.
    private func brokenRisk(_ url: String, status: ReviewRiskURLStatus, places: [(place: Place, locale: String)]) -> ReviewRisk? {
        let main = places.min { $0.place.order < $1.place.order }?.place ?? .field(.supportURL)
        let isRequired = main.order < 3
        let level: ReviewRiskLevel
        let howSure: HowSure
        let why: String
        switch status {
        case .opens:
            return nil
        case let .httpError(code) where code == 404 || code == 410:
            level = isRequired ? .likely : .check
            howSure = .sure
            why = String(
                localized: "It answers \(code) (not found). App Review opens every link and rejects broken ones.",
                comment: "kind:description · why an App Review risk matters"
            )
        case let .httpError(code):
            level = .check
            howSure = code >= 500 ? .fairlySure : .notVerySure
            why = code >= 500
                ? String(
                    localized: "Its server answered \(code) (an error). Check it opens before App Review tries it.",
                    comment: "kind:description · why an App Review risk matters"
                )
                : String(
                    localized: "It answered \(code) to Atlas. Check it opens in a browser before App Review tries it.",
                    comment: "kind:description · why an App Review risk matters"
                )
        case .unreachable:
            level = isRequired ? .likely : .check
            howSure = .fairlySure
            why = String(
                localized: "It didn’t answer within 10 seconds. App Review rejects links that don’t open.",
                comment: "kind:description · why an App Review risk matters"
            )
        }
        return ReviewRisk(
            check: id, subject: "broken.\(url)", guideline: main == .field(.supportURL) ? "1.5" : nil, level: level,
            title: String(localized: "\(main.name) doesn’t open", comment: "kind:title · an App Review risk"),
            why: why,
            evidence: evidence(url, places: places),
            howSure: howSure,
            fix: fix(for: main, url: url, places: places, advice: String(
                localized: "Fix the page at this address, or point the link to one that opens.", comment: "kind:description · how to fix an App Review risk"
            ))
        )
    }

    private func insecureRisk(_ url: String, places: [(place: Place, locale: String)]) -> ReviewRisk {
        let main = places.min { $0.place.order < $1.place.order }?.place ?? .field(.supportURL)
        let count = Set(places.map(\.locale)).count
        return ReviewRisk(
            check: id, subject: "insecure.\(url)", level: .check,
            title: String(localized: "\(main.name) uses http, not https", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Used in \(count) languages without https. Browsers warn, and App Review may flag it.",
                comment: "kind:description · why an App Review risk matters"
            ),
            evidence: evidence(url, places: places),
            howSure: .fairlySure,
            fix: fix(for: main, url: url, places: places, advice: String(
                localized: "Use the https:// address of the same page.", comment: "kind:description · how to fix an App Review risk"
            ))
        )
    }

    private func evidence(_ url: String, places: [(place: Place, locale: String)]) -> [ReviewRiskEvidence] {
        places.map { ReviewRiskEvidence(place: Self.place($0.place, $0.locale), excerpt: url, locale: $0.locale) }
    }

    private func fix(for main: Place, url: String, places: [(place: Place, locale: String)], advice: String) -> ReviewRiskFix {
        let locales = places.filter { $0.place == main }.map(\.locale)
        return ReviewRiskFix(
            advice: advice,
            tool: "propose_listing_text",
            arguments: ["field": main.field.rawValue, "locales": locales.joined(separator: ","), "url": url]
        )
    }
}
