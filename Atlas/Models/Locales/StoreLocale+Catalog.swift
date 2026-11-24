//
//  StoreLocale+Catalog.swift
//  Atlas
//

import Foundation

// The 39 App Store locales, named as App Store Connect names them.
//
// Flag regions that aren't in the code: Catalan → Andorra (its only
// official language, and it avoids picking Spain over Catalonia);
// Chinese (Traditional) → Hong Kong (renders everywhere, unlike the Taiwan
// flag on Macs set to mainland China); Arabic → Saudi Arabia, as in `ar-SA`.
//
// Translation identifiers: Norwegian is `nb` (Bokmål, what App Store
// Connect's `no` means); Spanish (Mexico) stays `es-MX` so providers can
// pick Latin American Spanish.
extension StoreLocale {
    static let arabic = StoreLocale("ar-SA", String(localized: "Arabic", comment: "kind:section-title"), region: "SA", language: "ar", isRTL: true)
    static let catalan = StoreLocale("ca", String(localized: "Catalan", comment: "kind:section-title"), region: "AD", language: "ca")
    static let chineseSimplified = StoreLocale(
        "zh-Hans", String(localized: "Chinese (Simplified)", comment: "kind:section-title"), region: "CN", language: "zh-Hans"
    )
    static let chineseTraditional = StoreLocale(
        "zh-Hant", String(localized: "Chinese (Traditional)", comment: "kind:section-title"), region: "HK", language: "zh-Hant"
    )
    static let croatian = StoreLocale("hr", String(localized: "Croatian", comment: "kind:section-title"), region: "HR", language: "hr")
    static let czech = StoreLocale("cs", String(localized: "Czech", comment: "kind:section-title"), region: "CZ", language: "cs")
    static let danish = StoreLocale("da", String(localized: "Danish", comment: "kind:section-title"), region: "DK", language: "da")
    static let dutch = StoreLocale("nl-NL", String(localized: "Dutch", comment: "kind:section-title"), region: "NL", language: "nl")
    static let englishAustralia = StoreLocale("en-AU", String(localized: "English (Australia)", comment: "kind:section-title"), region: "AU", language: "en-AU")
    static let englishCanada = StoreLocale("en-CA", String(localized: "English (Canada)", comment: "kind:section-title"), region: "CA", language: "en-CA")
    static let englishUK = StoreLocale("en-GB", String(localized: "English (U.K.)", comment: "kind:section-title"), region: "GB", language: "en-GB")
    static let englishUS = StoreLocale("en-US", String(localized: "English (U.S.)", comment: "kind:section-title"), region: "US", language: "en-US")
    static let finnish = StoreLocale("fi", String(localized: "Finnish", comment: "kind:section-title"), region: "FI", language: "fi")
    static let french = StoreLocale("fr-FR", String(localized: "French", comment: "kind:section-title"), region: "FR", language: "fr")
    static let frenchCanada = StoreLocale("fr-CA", String(localized: "French (Canada)", comment: "kind:section-title"), region: "CA", language: "fr-CA")
    static let german = StoreLocale("de-DE", String(localized: "German", comment: "kind:section-title"), region: "DE", language: "de")
    static let greek = StoreLocale("el", String(localized: "Greek", comment: "kind:section-title"), region: "GR", language: "el")
    static let hebrew = StoreLocale("he", String(localized: "Hebrew", comment: "kind:section-title"), region: "IL", language: "he", isRTL: true)
    static let hindi = StoreLocale("hi", String(localized: "Hindi", comment: "kind:section-title"), region: "IN", language: "hi")
    static let hungarian = StoreLocale("hu", String(localized: "Hungarian", comment: "kind:section-title"), region: "HU", language: "hu")
    static let indonesian = StoreLocale("id", String(localized: "Indonesian", comment: "kind:section-title"), region: "ID", language: "id")
    static let italian = StoreLocale("it", String(localized: "Italian", comment: "kind:section-title"), region: "IT", language: "it")
    static let japanese = StoreLocale("ja", String(localized: "Japanese", comment: "kind:section-title"), region: "JP", language: "ja")
    static let korean = StoreLocale("ko", String(localized: "Korean", comment: "kind:section-title"), region: "KR", language: "ko")
    static let malay = StoreLocale("ms", String(localized: "Malay", comment: "kind:section-title"), region: "MY", language: "ms")
    static let norwegian = StoreLocale("no", String(localized: "Norwegian", comment: "kind:section-title"), region: "NO", language: "nb")
    static let polish = StoreLocale("pl", String(localized: "Polish", comment: "kind:section-title"), region: "PL", language: "pl")
    static let portugueseBrazil = StoreLocale("pt-BR", String(localized: "Portuguese (Brazil)", comment: "kind:section-title"), region: "BR", language: "pt-BR")
    static let portuguesePortugal = StoreLocale(
        "pt-PT", String(localized: "Portuguese (Portugal)", comment: "kind:section-title"), region: "PT", language: "pt-PT"
    )
    static let romanian = StoreLocale("ro", String(localized: "Romanian", comment: "kind:section-title"), region: "RO", language: "ro")
    static let russian = StoreLocale("ru", String(localized: "Russian", comment: "kind:section-title"), region: "RU", language: "ru")
    static let slovak = StoreLocale("sk", String(localized: "Slovak", comment: "kind:section-title"), region: "SK", language: "sk")
    static let spanishMexico = StoreLocale("es-MX", String(localized: "Spanish (Mexico)", comment: "kind:section-title"), region: "MX", language: "es-MX")
    static let spanishSpain = StoreLocale("es-ES", String(localized: "Spanish (Spain)", comment: "kind:section-title"), region: "ES", language: "es-ES")
    static let swedish = StoreLocale("sv", String(localized: "Swedish", comment: "kind:section-title"), region: "SE", language: "sv")
    static let thai = StoreLocale("th", String(localized: "Thai", comment: "kind:section-title"), region: "TH", language: "th")
    static let turkish = StoreLocale("tr", String(localized: "Turkish", comment: "kind:section-title"), region: "TR", language: "tr")
    static let ukrainian = StoreLocale("uk", String(localized: "Ukrainian", comment: "kind:section-title"), region: "UA", language: "uk")
    static let vietnamese = StoreLocale("vi", String(localized: "Vietnamese", comment: "kind:section-title"), region: "VN", language: "vi")
}
