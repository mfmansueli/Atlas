//
//  ReviewRiskFactsLoader+Links.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// Most distinct URLs opened in one run.
    static let urlProbes = 15

    /// Each language's Privacy Policy URL (App Information's privacy URLs,
    /// else the store page's), Support and Marketing URLs and the Terms of
    /// Use links in its description, as pushed, and what opening each
    /// distinct URL gave (at most `urlProbes`, in parallel). Nil when
    /// the store page couldn't be read.
    func linkFacts(for _: StoreApp, shared: ReviewRiskSharedContent) async -> ReviewRiskLinkFacts? {
        guard var facts = Self.linkFacts(storePage: shared.storePage, privacyURLs: shared.privacyURLs) else { return nil }
        let urls = facts.urlsToProbe
        let probed = Array(urls.prefix(Self.urlProbes))
        facts.unprobed = Array(urls.dropFirst(Self.urlProbes))
        facts.statuses = await Self.probe(probed, with: urlProbe)
        return facts
    }

    /// Everything but opening the URLs.
    static func linkFacts(storePage: StorePageContent?, privacyURLs: PrivacyURLsContent?) -> ReviewRiskLinkFacts? {
        guard let storePage else { return nil }
        var facts = ReviewRiskLinkFacts(locales: storePage.locales.map(\.code), primaryLocale: storePage.primaryLocale.code)
        for locale in storePage.locales {
            let texts = storePage.texts[locale] ?? [:]
            func value(_ field: ListingField) -> String? {
                guard let text = texts[field]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return text
            }
            facts.supportURLs[locale.code] = value(.supportURL)
            facts.marketingURLs[locale.code] = value(.marketingURL)
            facts.privacyPolicyURLs[locale.code] = value(.privacyPolicyURL)
            if let description = value(.description) {
                let terms = ReviewRiskTermsLink.urls(in: description)
                if !terms.isEmpty { facts.termsURLs[locale.code] = terms }
            }
        }
        for remote in privacyURLs?.locales ?? [] {
            let policy = remote.policyURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !policy.isEmpty { facts.privacyPolicyURLs[remote.locale.code] = policy }
        }
        return facts
    }

    /// Opens each URL once, in parallel; one that isn't a web address
    /// counts as unreachable.
    static func probe(_ urls: [String], with probe: any ReviewRiskURLProbing) async -> [String: ReviewRiskURLStatus] {
        await withTaskGroup(of: (String, ReviewRiskURLStatus).self) { group in
            for written in urls {
                group.addTask {
                    guard let url = webURL(written) else { return (written, .unreachable("not a web address")) }
                    return await (written, probe.probe(url))
                }
            }
            var statuses: [String: ReviewRiskURLStatus] = [:]
            for await (written, status) in group {
                statuses[written] = status
            }
            return statuses
        }
    }

    /// The URL to open for one as written: "example.com/help" opens as
    /// https.
    nonisolated static func webURL(_ written: String) -> URL? {
        let trimmed = written.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let full = lowered.hasPrefix("http://") || lowered.hasPrefix("https://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: full), let host = url.host(), host.contains(".") else { return nil }
        return url
    }
}
