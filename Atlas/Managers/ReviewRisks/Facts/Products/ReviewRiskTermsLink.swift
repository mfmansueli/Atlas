//
//  ReviewRiskTermsLink.swift
//  Atlas
//

import Foundation

/// Finds a Terms of Use (EULA) link in a store text, as 3.1.2(c) asks of
/// an app with auto-renewable subscriptions: Apple's standard EULA URL, a
/// URL whose address names terms, or a URL near words that do ("Terms of
/// Use: https://…", "Nutzungsbedingungen", "利用規約"). Words without a
/// URL don't count: App Review wants a link that opens.
enum ReviewRiskTermsLink {
    /// Apple's standard license agreement, which an app may link to
    /// instead of its own.
    static let standardEULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    /// Words that name terms of use, lowercased, in the store's languages.
    static let words = [
        "terms of use", "terms of service", "terms & conditions", "terms and conditions", "terms", "eula", "license agreement",
        "licence agreement", "nutzungsbedingungen", "agb", "allgemeine geschäftsbedingungen", "termos de uso", "termos de serviço",
        "termos e condições", "conditions d'utilisation", "conditions générales", "cgu", "términos de uso", "términos y condiciones",
        "términos del servicio", "condiciones de uso", "termini di utilizzo", "termini d'uso", "condizioni d'uso", "termini e condizioni",
        "gebruiksvoorwaarden", "algemene voorwaarden", "användarvillkor", "villkor", "brugsbetingelser", "vilkår", "käyttöehdot",
        "warunki korzystania", "regulamin", "podmínky použití", "условия использования", "пользовательское соглашение",
        "kullanım koşulları", "όροι χρήσης", "תנאי שימוש", "شروط الاستخدام", "利用規約", "使用条款", "服务条款", "使用條款", "服務條款",
        "이용약관", "ข้อกำหนดการใช้งาน", "điều khoản sử dụng", "syarat penggunaan", "ketentuan penggunaan", "syarat-syarat penggunaan",
    ]

    /// Parts of an address that name terms: "/terms", "/eula", "/tos".
    static let addressWords = [
        "terms", "eula", "/tos", "/legal", "/agb", "nutzungsbedingungen", "conditions", "termos", "terminos", "condizioni", "voorwaarden",
    ]

    /// Parts of an address that name a privacy policy: such a URL near
    /// "terms" is the policy's, not the terms' (subscription texts often
    /// say "subscription terms" just before the privacy link).
    static let privacyWords = ["privacy", "datenschutz", "privacidad", "privacidade", "confidentialite", "riservatezza", "privacybeleid"]

    /// How far before a URL its words may be ("Terms of Use: https://…"),
    /// and how far after ("https://… (Terms of Use)"), in characters.
    static let nearbyBefore = 120
    static let nearbyAfter = 40

    /// The URLs in `text` that work as its Terms of Use link.
    static func urls(in text: String) -> [String] {
        let found = links(in: text)
        guard !found.isEmpty else { return [] }
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        let wordRanges = words.flatMap { ranges(of: $0, in: lowered) }
        return found.compactMap { link -> String? in
            let address = link.url.lowercased()
            if address.contains("apple.com/legal/internet-services/itunes") { return link.url }
            if addressWords.contains(where: { address.contains($0) }) { return link.url }
            if privacyWords.contains(where: { address.contains($0) }) { return nil }
            let start = link.offset
            let end = link.offset + link.length
            let isNear = wordRanges.contains { word in
                if word.upperBound <= start { return start - word.upperBound <= nearbyBefore }
                if word.lowerBound >= end { return word.lowerBound - end <= nearbyAfter }
                return false
            }
            return isNear ? link.url : nil
        }
    }

    /// Whether `text` has a Terms of Use link.
    static func has(in text: String) -> Bool {
        !urls(in: text).isEmpty
    }

    /// Every web address in `text`, as written, with where it starts
    /// (in characters).
    static func links(in text: String) -> [(url: String, offset: Int, length: Int)] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match -> (url: String, offset: Int, length: Int)? in
            guard let found = Range(match.range, in: text) else { return nil }
            let written = String(text[found])
            let scheme = match.url?.scheme?.lowercased()
            guard scheme == "http" || scheme == "https" || scheme == nil || written.lowercased().hasPrefix("www.") else { return nil }
            let offset = text.distance(from: text.startIndex, to: found.lowerBound)
            return (url: written, offset: offset, length: written.count)
        }
    }

    /// Where `word` shows in `text`, in characters. A short Latin word
    /// ("agb", "tos", "cgu", "terms") must stand alone.
    private static func ranges(of word: String, in text: String) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var searchStart = text.startIndex
        let needsBoundary = word.count <= 5 && word.unicodeScalars.allSatisfy(\.isASCII)
        while let found = text.range(of: word, range: searchStart..<text.endIndex) {
            searchStart = found.upperBound
            if needsBoundary {
                let before = found.lowerBound > text.startIndex ? text[text.index(before: found.lowerBound)] : " "
                let after = found.upperBound < text.endIndex ? text[found.upperBound] : " "
                if before.isLetter || after.isLetter { continue }
            }
            let lower = text.distance(from: text.startIndex, to: found.lowerBound)
            result.append(lower..<lower + word.count)
        }
        return result
    }
}
