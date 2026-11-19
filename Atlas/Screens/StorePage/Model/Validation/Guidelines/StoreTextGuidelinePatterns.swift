//
//  StoreTextGuidelinePatterns.swift
//  Atlas
//

import Foundation

/// What `StoreTextGuidelineCheck` looks for, per kind, in the App Store's
/// main languages: case ignored (TODO and TBD only in capitals), Latin
/// words whole. Words that are often something else are left out, so a
/// match is worth rewriting: "price" in a price tracker, "discount" in a
/// coupon app, "zoom" in a camera, "hands-free", "free up space", "feel
/// free", "free of ads", and PlayStation and Xbox controllers, which Apple
/// platforms support.
nonisolated enum StoreTextGuidelinePatterns {
    /// `allowingTrials`: trial lengths aren't pricing here (an in-app
    /// purchase's "7-day Trial").
    static func expressions(for kind: StoreTextGuidelineKind, allowingTrials: Bool = false) -> [NSRegularExpression] {
        switch kind {
        case .pricing: allowingTrials ? priceAndFree : pricing
        case .otherPlatform: otherPlatform
        case .unverifiableClaim: unverifiableClaim
        case .otherApp: otherApp
        case .prerelease: prerelease
        case .placeholder: placeholder
        case .comingSoon: comingSoon
        case .kidsTerms: kidsTerms
        case .emphasis: emphasis
        }
    }

    /// What a place looks for (`StoreTextGuidelinePlace`): an event may be
    /// free, a reply may say "free trial" answering a billing question, and
    /// claims there are the clear ones only ("share your best shot" is an
    /// event).
    static func expressions(for kind: StoreTextGuidelineKind, in place: StoreTextGuidelinePlace) -> [NSRegularExpression] {
        switch (place, kind) {
        case (.eventText, .pricing): prices
        case (.retentionMessage, .pricing): pricing
        case (.reviewReply, .pricing): prices + promoCodes
        case (_, .unverifiableClaim): clearClaims
        case (_, .placeholder): placeholder + namePlaceholders
        default: expressions(for: kind)
        }
    }

    // MARK: - Building

    private static func regex(_ pattern: String, caseSensitive: Bool = false) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }

    /// Alternatives as one expression, any run of spaces between words;
    /// whole words only unless the script has no spaces (Chinese,
    /// Japanese, Thai).
    private static func words(_ phrases: [String], wholeWords: Bool = true) -> NSRegularExpression? {
        let escaped = phrases
            .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: "\\s+") }
            .joined(separator: "|")
        return regex(wholeWords ? "(?<![\\p{L}\\p{N}])(?:\(escaped))(?![\\p{L}\\p{N}])" : "(?:\(escaped))")
    }

    /// Stems of words that take endings and prefixes in their language,
    /// with the whole word around them: "бесплатно", "بالمجان".
    private static func stems(_ stems: [String]) -> NSRegularExpression? {
        regex("[\\p{L}\\p{M}]*(?:\(stems.joined(separator: "|")))[\\p{L}\\p{M}]*")
    }

    // MARK: - Pricing (2.3.7)

    /// Nouns "free" follows when it means without: "ad free", "stress free".
    private static let withoutNouns = [
        "ad", "ads", "hands", "gluten", "sugar", "dairy", "fat", "nut", "stress", "hassle", "worry", "distraction", "clutter",
        "cruelty", "smoke", "alcohol", "caffeine", "lactose", "toll", "duty", "tax", "spam", "jargon", "bloat", "pain", "guilt",
        "crash", "lag", "bug", "noise", "tracking", "carbon", "plastic", "paper", "cash", "cookie", "wire", "cord", "cable",
        "scent", "fragrance", "latex", "meat",
    ]

    private static let pricing = priceAndFree + trials

    /// "free", prices and discounts: pricing without trial lengths, which
    /// an in-app purchase may name (3.1.1's "XX-day Trial").
    private static let priceAndFree = free + prices

    /// "free" as a price, in the App Store's main languages. Header and
    /// search artwork look for it too (`ArtworkForbiddenText`).
    static let free: [NSRegularExpression] = [
        // "free" as a price: "free to download", "Free includes", "free
        // for 7 days", "free-to-play", "free of charge". Not "hands-free",
        // "ad free", "feel free", "free-form", "free up", "free of ads".
        regex(
            "(?<![\\p{L}\\p{N}-])(?<!feel\\s)(?<!break\\s)(?<!(?:\(withoutNouns.joined(separator: "|")))\\s)free(?![\\p{L}\\p{N}])"
                + "(?!-(?:form|hand|flowing|floating|standing|range|style|spirited|wheeling|roaming)(?![\\p{L}]))"
                + "(?!\\s+(?:up|yourself|yourselves|your|you|them|time|space|from|of(?!\\s+charge))(?![\\p{L}]))"
        ),
        words([
            "no cost", "at no cost", "no charge", "without charge", "gratis", "grátis", "gratuit", "gratuite", "gratuits",
            "gratuites", "gratuitement", "gratuito", "gratuita", "gratuitos", "gratuitas", "gratuitamente", "gratuït", "gratuïta",
            "de graça", "sem custo", "sin costo", "sin coste", "sin cargo", "sans frais", "senza costi", "kostenlos", "kostenlose",
            "kostenlosen", "kostenloser", "kostenloses", "kostenfrei", "kostenfreie", "kostenfreien", "umsonst", "gebührenfrei",
            "ohne Kosten", "kosteloos", "kosteloze", "kostnadsfri", "kostnadsfritt", "kostnadsfria", "ilmainen", "ilmaiseksi",
            "ilmaisen", "ilmaiset", "maksuton", "maksutta", "darmowy", "darmowa", "darmowe", "darmowych", "za darmo", "bezpłatny",
            "bezpłatna", "bezpłatne", "bezpłatnie", "zdarma", "zadarmo", "bezplatný", "bezplatná", "bezplatné", "bezplatně",
            "ingyenes", "ingyen", "ingyenesen", "besplatno", "besplatan", "besplatna", "besplatne", "brezplačno", "brezplačen",
            "nemokamai", "nemokama", "ücretsiz", "bedava", "percuma", "miễn phí",
        ]),
        stems(["бесплатн", "безкоштовн", "безплатн", "δωρεάν", "δωρεαν", "חינם", "مجان", "मुफ़्त", "मुफ्त", "\u{092E}\u{0941}\u{095E}\u{094D}\u{0924}", "निःशुल्क"]),
        words(["無料", "免费", "免費", "무료", "공짜", "ฟรี"], wholeWords: false),
    ].compactMap(\.self)

    /// Prices and discounts: what In-App Event texts may not name, where
    /// "free" is allowed.
    private static let prices: [NSRegularExpression] = [
        // A price: "$4.99", "R$ 9,90", "4,99 €", "500円", "USD 5", "9 dollars".
        regex("(?<![\\p{L}])(?:US\\$|R\\$|A\\$|C\\$|NZ\\$|HK\\$|MX\\$|S\\$|[$€£¥₹₩₽₺₫₪฿₴₦₱])\\s?\\d+(?:[.,]\\d+)*"),
        regex("(?<![\\p{N}.,])\\d+(?:[.,]\\d+)*\\s?(?:[$€£¥₹₩₽₺₫₪฿₴₦₱]|円|元|원|zł|Kč|kr|lei|руб|грн)(?![\\p{L}])"),
        regex(
            "(?<![\\p{L}])(?:USD|EUR|GBP|BRL|JPY|CNY|RMB|INR|AUD|CAD|CHF|MXN|KRW|RUB|SEK|NOK|DKK|PLN|CZK|HUF)\\s?\\d+(?:[.,]\\d+)*"
                + "|(?<![\\p{N}.,])\\d+(?:[.,]\\d+)*\\s?(?:USD|EUR|GBP|BRL|JPY|CNY|RMB|INR|AUD|CAD|CHF|MXN|KRW|RUB|SEK|NOK|DKK|PLN"
                + "|CZK|HUF|dollars?|euros?|reais|pesos|yen)(?![\\p{L}])"
        ),
        // A discount: "50% off", "50 % günstiger", "−50 %", "%50 indirim",
        // "save 30%", "half price", "special offer".
        regex(
            "(?<![\\p{L}\\p{N}])\\d{1,3}(?:[.,]\\d+)?\\s?[%％]\\s?(?:off|de\\s+desconto|de\\s+descuento|de\\s+réduction|de\\s+remise"
                + "|di\\s+sconto|rabatt|korting|rabat|zniżki|indirim|скидка|günstiger|billiger|moins\\s+cher|más\\s+barato"
                + "|mais\\s+barato|taniej|オフ|할인|הנחה|छूट)(?![\\p{L}])"
        ),
        regex("(?<![\\p{L}\\p{N}])[−–-]\\s?\\d{1,3}(?:[.,]\\d+)?\\s?[%％]|(?<![\\p{L}\\p{N}])%\\d{1,3}\\s+indirim"),
        regex("(?<![\\p{L}])(?:save|économisez|ahorra|economize|spare)\\s+\\d{1,3}(?:[.,]\\d+)?\\s?%"),
        words([
            "half price", "half-price", "price drop", "special offer", "limited-time offer", "limited time offer", "introductory price",
            "introductory offer", "launch price", "launch discount", "money-back guarantee", "money back guarantee", "oferta especial",
            "oferta por tempo limitado", "oferta por tiempo limitado", "offre spéciale", "offre limitée", "Sonderangebot",
            "offerta speciale", "offerta limitata", "halben Preis", "halber Preis", "moitié prix", "mitad de precio", "metade do preço",
            "metà prezzo", "halve prijs", "halva priset", "pół ceny", "полцены", "yarı fiyat", "yarı fiyatına", "חצי מחיר", "आधी कीमत",
        ]),
        words(["期間限定", "限时优惠", "限時優惠", "기간 한정", "半額", "半价", "半價", "반값", "五折"], wholeWords: false),
    ].compactMap(\.self)

    /// Promo codes in a reply: marketing (5.6.1).
    private static let promoCodes: [NSRegularExpression] = [
        words([
            "promo code", "promo codes", "promotional code", "coupon", "coupon code", "discount code", "voucher code", "referral code",
            "código promocional", "cupom", "cupón", "code promo", "Gutscheincode", "Rabattcode", "codice promozionale",
        ]),
        regex("(?<![\\p{L}])use\\s+(?:the\\s+)?code\\s+\\S+"),
    ].compactMap(\.self)

    /// A trial: "7-day trial", "one-month free trial", "trial period".
    static let trials: [NSRegularExpression] = [
        regex("(?<![\\p{L}\\p{N}])\\d+[- ]?(?:day|week|month|year)s?[- ](?:free[- ])?trial(?![\\p{L}])"),
        regex("(?<![\\p{L}])(?:one|two|three|seven|fourteen|thirty)[- ](?:day|week|month|year)[- ](?:free[- ])?trial(?![\\p{L}])"),
        regex("(?<![\\p{L}])trial\\s+(?:period|subscription|offer)(?![\\p{L}])"),
        regex("(?<![\\p{L}\\p{N}])\\d+\\s+(?:dias\\s+de\\s+teste|días\\s+de\\s+prueba|jours\\s+d['’]essai|Tage\\s+testen|giorni\\s+di\\s+prova)(?![\\p{L}])"),
        words([
            "período de teste", "período de avaliação", "período de prueba", "periodo de prueba", "periodo di prova", "période d'essai",
            "période d’essai", "Testphase", "Testzeitraum", "Probezeitraum", "Probeabo", "Probemonat", "proefperiode", "provperiod",
            "prøveperiode", "kokeilujakso", "okres próbny", "deneme süresi",
        ]),
        words(["お試し期間", "無料トライアル", "免费试用", "免費試用", "试用期", "試用期", "무료 체험", "체험판"], wholeWords: false),
    ].compactMap(\.self)

    // MARK: - Other platforms (2.3.10)

    private static let otherPlatform: [NSRegularExpression] = [
        words([
            "android", "google play", "play store", "galaxy store", "amazon appstore", "appgallery", "wear os", "harmonyos",
            "windows phone", "blackberry", "setapp", "altstore", "f-droid", "aptoide", "apk",
        ]),
    ].compactMap(\.self)

    // MARK: - Unverifiable claims (2.3.7)

    private static let unverifiableClaim: [NSRegularExpression] = [
        regex("#\\s?1(?!\\d)|(?<![\\p{L}])(?:no|nr|nº|n\\.º|n°)\\.?\\s?1(?![\\p{L}\\p{N}])"),
        words([
            "best", "number one", "best-selling", "bestselling", "top-rated", "top rated", "highest rated", "highest-rated",
            "award-winning", "award winning", "most popular", "world's best", "world’s best", "world's first", "world’s first",
            "número 1", "numero 1", "numéro 1", "nummer 1", "melhor app", "mejor app", "beste App", "meilleure app", "migliore app",
        ]),
        words(["最高の", "最好的", "最佳", "最強", "최고의", "업계 1위"], wholeWords: false),
    ].compactMap(\.self)

    /// Claims no one reads as anything else, for event texts and retention
    /// messages, where "best" alone is often "your best shot": "the best
    /// app", "#1", "award-winning" and statistics like "92% of parents".
    private static let clearClaims: [NSRegularExpression] = [
        regex("#\\s?1(?!\\d)|(?<![\\p{L}])(?:no|nr|nº|n\\.º|n°)\\.?\\s?1(?![\\p{L}\\p{N}])"),
        words([
            "the best app", "the best game", "best app", "best apps", "best game", "number one", "best-selling", "bestselling",
            "top-rated", "top rated", "highest rated", "highest-rated", "award-winning", "award winning", "most popular",
            "world's best", "world’s best", "world's first", "world’s first", "número 1", "numero 1", "numéro 1", "nummer 1",
            "melhor app", "mejor app", "beste App", "meilleure app", "migliore app",
        ]),
        regex(
            "(?<![\\p{L}\\p{N}])\\d{1,3}(?:[.,]\\d+)?\\s?%\\s+of\\s+(?:all\\s+)?(?:users|people|parents|customers|subscribers|players"
                + "|members|students|teachers|families|kids|children|doctors|experts)(?![\\p{L}])"
        ),
        words(["업계 1위"], wholeWords: false),
    ].compactMap(\.self)

    // MARK: - Emphasis (In-App Events, retention messages)

    /// Three words or more in capitals ("DON'T MISS OUT"), two long ones
    /// ("HUGE EVENT"), or repeated "!" and "?". Acronyms ("AI", "VPN",
    /// "HDR") stay, one or two at a time.
    private static let emphasis: [NSRegularExpression] = [
        regex(
            "(?<![\\p{L}])\\p{Lu}[\\p{Lu}'’]+(?![\\p{L}])(?:[\\s,–-]+\\p{Lu}[\\p{Lu}'’]+(?![\\p{L}])){2,}"
                + "|(?<![\\p{L}])\\p{Lu}{4,}(?![\\p{L}])\\s+\\p{Lu}{4,}(?![\\p{L}])",
            caseSensitive: true
        ),
        regex("[!！][!?！？]+|[?？][!?！？]+"),
    ].compactMap(\.self)

    // MARK: - Other apps (2.3.7, 4.1(c))

    /// Popular apps and brands whose names aren't everyday words ("Zoom",
    /// "Notion", "Slack" and "Threads" are).
    private static let otherApp: [NSRegularExpression] = [
        words([
            "whatsapp", "instagram", "facebook", "tiktok", "youtube", "snapchat", "pinterest", "linkedin", "reddit", "twitter",
            "telegram", "discord", "netflix", "spotify", "shazam", "tinder", "grindr", "bumble", "duolingo", "canva", "capcut",
            "chatgpt", "openai", "gmail", "google", "waze", "uber", "lyft", "airbnb", "paypal", "venmo", "ebay", "amazon", "alexa",
            "minecraft", "roblox", "fortnite", "pokemon", "pokémon", "candy crush", "photoshop", "lightroom", "procreate", "vsco",
            "picsart", "faceapp", "truecaller", "strava", "fitbit", "myfitnesspal", "headspace", "evernote", "dropbox", "skype",
            "wechat", "kakaotalk", "viber", "twitch",
        ]),
    ].compactMap(\.self)

    // MARK: - Betas and demos (2.2)

    private static let prerelease: [NSRegularExpression] = [
        // Not "beta testers" or "beta testing", the people thanked in What's New.
        regex("(?<![\\p{L}\\p{N}])beta(?![\\p{L}\\p{N}])(?![- ]?test)"),
        words([
            "alpha version", "alpha release", "demo version", "trial version", "test version", "test build", "pre-release",
            "prerelease", "early access", "work in progress", "versão de teste", "versão demo", "versión de prueba", "versión demo",
            "Testversion", "Demoversion", "version d'essai", "version d’essai", "versione di prova", "versione demo",
        ]),
        words(["ベータ", "测试版", "測試版", "베타"], wholeWords: false),
    ].compactMap(\.self)

    // MARK: - Placeholders (2.1(a))

    /// A name left to fill in, as in a reply template: "Hi [name]",
    /// "Dear {customer}". Store text never names a person, so only the
    /// places check it.
    private static let namePlaceholders: [NSRegularExpression] = [
        regex("\\[(?:first\\s+)?(?:name|customer|reviewer|user|username|nome|nombre|nom)[^\\]]*\\]|\\{(?:first_?)?(?:name|customer|user)\\}"),
    ].compactMap(\.self)

    private static let placeholder: [NSRegularExpression] = [
        words(["lorem ipsum", "dolor sit amet", "placeholder"]),
        regex("\\{\\{[^}]*\\}\\}|\\[(?:insert|your|add|app name)[^\\]]*\\]|<(?:insert|your)[^>]*>"),
        // Capitals only: "todo" is Spanish and Portuguese for "all".
        regex("(?<![\\p{L}\\p{N}])(?:TODO|FIXME)\\s?:|(?<![\\p{L}\\p{N}])(?:TBD|TBA)(?![\\p{L}\\p{N}])", caseSensitive: true),
    ].compactMap(\.self)

    // MARK: - Coming soon (2.3)

    private static let comingSoon: [NSRegularExpression] = [
        words([
            "coming soon", "available soon", "soon available", "launching soon", "in a future update", "in an upcoming update",
            "in the next update", "in a future version", "em breve", "disponível em breve", "próximamente", "proximamente", "muy pronto",
            "disponible pronto", "bientôt disponible", "prochainement", "demnächst", "in Kürze", "bald verfügbar", "prossimamente",
            "presto disponibile", "binnenkort", "kommer snart", "wkrótce", "yakında",
        ]),
        words(["近日公開", "近日登場", "近日配信", "即将推出", "即將推出", "敬请期待", "敬請期待", "곧 출시", "출시 예정"], wholeWords: false),
    ].compactMap(\.self)

    // MARK: - For kids (2.3.8, 5.1.4(b))

    private static let kidsTerms: [NSRegularExpression] = [
        words([
            "for kids", "for children", "for toddlers", "for preschoolers", "for little ones", "para crianças", "para niños",
            "para niñas", "pour enfants", "pour les enfants", "für Kinder", "per bambini", "voor kinderen", "för barn", "for børn",
            "for barn", "dla dzieci", "çocuklar için", "для детей",
        ]),
        words(["子供向け", "子ども向け", "キッズ向け", "儿童版", "兒童版", "어린이용"], wholeWords: false),
    ].compactMap(\.self)
}
