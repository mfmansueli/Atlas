//
//  StoreTextPayElsewherePatterns.swift
//  Atlas
//

import Foundation

/// Store text that sends people to pay outside the App Store (Guidelines
/// 3.1.1 and 3.1.3), in the App Store's main languages:
/// - links to pay elsewhere: Patreon, Ko-fi, Buy Me a Coffee, Gumroad,
///   PayPal.me, Stripe checkout, or a site's /pricing, /checkout,
///   /subscribe or /buy page;
/// - a sentence that names the app's website with buying, subscribing or
///   a better price there ("Subscribe on our website", "günstiger auf
///   unserer Website");
/// - PayPal, Stripe, Venmo or Cash App beside paying words: fine for
///   physical goods (3.1.3(e)), so `isClear` is false.
/// Since May 2025 the United States storefront allows such links.
nonisolated enum StoreTextPayElsewherePatterns {
    struct Match: Hashable, Sendable {
        /// The words as written: the link, or the sentence.
        var phrase: String
        /// Only paying elsewhere reads this way; false for a payment
        /// service that might be for goods.
        var isClear: Bool
    }

    static func matches(in text: String) -> [Match] {
        var matches: [Match] = []
        let range = NSRange(text.startIndex..., in: text)
        for expression in [paymentLinks, checkoutLinks, donationServices].compactMap(\.self) {
            for match in expression.matches(in: text, range: range) {
                guard let found = Range(match.range, in: text) else { continue }
                matches.append(Match(phrase: trimmed(String(text[found])), isClear: true))
            }
        }
        for sentence in sentences(in: text) {
            let folded = fold(sentence)
            let namesSite = contains(any: websiteWords, in: folded) || folded.range(of: payOnTheWeb, options: .regularExpression) != nil
            if namesSite, contains(any: payWords, in: folded), !contains(any: notPaying, in: folded) {
                matches.append(Match(phrase: trimmed(sentence), isClear: true))
            } else if folded.range(of: paymentServices, options: .regularExpression) != nil, contains(any: payWords + ["donate", "tip", "spende"], in: folded) {
                matches.append(Match(phrase: trimmed(sentence), isClear: false))
            }
        }
        var seen: Set<String> = []
        return matches.filter { seen.insert($0.phrase.lowercased()).inserted }
    }

    // MARK: - Links and names

    private static let paymentLinks = try? NSRegularExpression(
        pattern: "(?:https?://)?(?:www\\.)?(?:patreon\\.com|ko-fi\\.com|buymeacoffee\\.com|[\\w-]+\\.gumroad\\.com|gumroad\\.com|paypal\\.me"
            + "|paypal\\.com/(?:donate|paypalme|ncp)|(?:buy|checkout|donate)\\.stripe\\.com|[\\w-]+\\.lemonsqueezy\\.com|subscribestar\\.com"
            + "|liberapay\\.com|opencollective\\.com)[^\\s)\\]>\"”]*",
        options: [.caseInsensitive]
    )

    /// A site's pages to pay on: "https://example.com/pricing".
    private static let checkoutLinks = try? NSRegularExpression(
        pattern: "(?:https?://|www\\.)[^\\s/]+(?:/[^\\s/?#]*)*/(?:pricing|checkout|subscribe|purchase|buy|upgrade|donate|plans)(?![\\w-])[^\\s)\\]>\"”]*",
        options: [.caseInsensitive]
    )

    /// Services only for paying creators.
    private static let donationServices = try? NSRegularExpression(
        pattern: "(?<![\\p{L}])(?:Patreon|Ko-fi|Buy Me a Coffee|SubscribeStar|Liberapay|Open Collective)(?![\\p{L}])",
        options: [.caseInsensitive]
    )

    /// Folded: "subscribe on the web", "buy it on the web", "cheaper on the web".
    private static let payOnTheWeb = "(?<![\\p{L}])(?:subscribe|buy|purchase|pay|upgrade|cheaper)(?:\\s+\\p{L}+){0,3}\\s+on\\s+the\\s+web(?![\\p{L}])"

    /// Folded: payment services that also take money for goods.
    private static let paymentServices = "(?<![\\p{L}])(?:paypal|stripe|venmo|cash app)(?![\\p{L}])"

    // MARK: - Sentences

    /// Folded (case, accents): the app's own website or web store.
    private static let websiteWords = [
        "our website", "our web site", "our site", "our web store", "our online store", "our webshop",
        "unserer website", "unserer webseite", "unserer homepage", "unseren webshop", "unserem webshop",
        "notre site", "notre boutique en ligne", "nuestra web", "nuestro sitio", "nuestra pagina web",
        "nuestra tienda online", "nosso site", "nosso website", "nossa loja online", "nostro sito", "onze website", "onze webshop",
        "var webbplats", "var hemsida", "naszej stronie", "web sitemiz", "公式サイト", "ウェブサイト", "ホームページ", "官网", "官方网站",
        "我们的网站", "웹사이트", "홈페이지",
    ].map(StoreTextPayElsewherePatterns.fold)

    /// Folded: buying, subscribing, paying and a better price.
    private static let payWords = [
        "buy", "purchase", "subscribe", "pay", "upgrade", "cheaper", "lower price", "better price", "checkout",
        "kaufen", "abonnieren", "günstiger", "bezahlen", "bestellen", "acheter", "achetez", "abonnez", "abonner", "moins cher",
        "payer", "commander", "comprar", "compra", "suscríbete", "suscribirse", "más barato", "pagar", "compre", "assine", "assinar",
        "mais barato", "acquista", "acquistare", "abbonati", "più economico", "pagare", "kopen", "koop", "abonneer", "goedkoper",
        "betalen", "köp", "köpa", "prenumerera", "billigare", "kup", "kupić", "taniej", "satın al", "daha ucuz", "購入", "定期購読",
        "安く", "购买", "購買", "订阅", "訂閱", "更便宜", "구매", "구독", "저렴",
    ].map(StoreTextPayElsewherePatterns.fold)

    /// Folded: subscribing to news, not paying.
    private static let notPaying = ["newsletter", "mailing list", "news", "updates by email", "blog"].map(StoreTextPayElsewherePatterns.fold)

    /// Whole words for Latin ones; anywhere for scripts without spaces.
    private static func contains(any words: [String], in folded: String) -> Bool {
        words.contains { word in
            guard word.unicodeScalars.contains(where: { $0.isASCII && CharacterSet.letters.contains($0) }) else { return folded.contains(word) }
            let pattern = "(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: word).replacingOccurrences(of: " ", with: "\\s+") + "(?![\\p{L}])"
            return folded.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func sentences(in text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence { sentences += sentence.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
        }
        return sentences
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:")))
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
