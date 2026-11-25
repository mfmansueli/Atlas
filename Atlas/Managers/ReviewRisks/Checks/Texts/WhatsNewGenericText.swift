//
//  WhatsNewGenericText.swift
//  Atlas
//

import Foundation

/// Tells a What's New that says only "Bug fixes and performance
/// improvements", in the App Store's main languages: once the generic
/// phrases and the small words around them are gone, nothing is left.
/// 2.3.12 lets an update that only fixes bugs say so; anything else should
/// name its changes.
enum WhatsNewGenericText {
    /// Generic, and short (at most `wordLimit` words). `appName`'s words
    /// count as small words ("Thanks for using Alba").
    static func isGeneric(_ text: String, appName: String = "") -> Bool {
        let folded = fold(text)
        guard words(in: folded).count <= wordLimit, let expression = phrases else { return false }
        let range = NSRange(folded.startIndex..., in: folded)
        guard expression.firstMatch(in: folded, range: range) != nil else { return false }
        let rest = expression.stringByReplacingMatches(in: folded, range: range, withTemplate: " ")
        let small = fillers.union(words(in: fold(appName)))
        return words(in: rest).allSatisfy { small.contains($0) }
    }

    static let wordLimit = 25

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private static func words(in text: String) -> [String] {
        var words: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { words.append(word) }
        }
        return words
    }

    /// Longest first, so "performance improvements" goes before
    /// "improvements". Latin phrases whole; the others anywhere.
    private static let phrases: NSRegularExpression? = {
        let latin = latinPhrases.map(WhatsNewGenericText.fold).sorted { $0.count > $1.count }
            .map { "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: "\\s+") + "(?![\\p{L}\\p{N}])" }
        let other = otherPhrases.map(WhatsNewGenericText.fold).sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }
        return try? NSRegularExpression(pattern: (latin + other).joined(separator: "|"))
    }()

    /// Written as in the language; folded like the text when built.
    private static let latinPhrases = [
        // English
        "bug fixes", "bug fix", "bugfixes", "bugfix", "fixed bugs", "fixed some bugs", "fixed a bug", "fixed minor bugs", "fixes",
        "fixed", "performance improvements", "performance improvement", "stability improvements", "improvements", "improvement",
        "enhancements", "optimizations", "optimisations", "tweaks", "under the hood", "minor changes", "small changes",
        // German
        "fehlerbehebungen", "fehlerbehebung", "fehler behoben", "verbesserungen", "leistungsverbesserungen",
        "stabilitatsverbesserungen", "optimierungen", "kleinere anderungen",
        // French
        "corrections de bugs", "correction de bugs", "corrections de bogues", "corrections", "ameliorations des performances",
        "ameliorations", "amelioration", "optimisations",
        // Spanish
        "correcciones de errores", "correccion de errores", "correcciones", "errores corregidos", "mejoras de rendimiento", "mejoras",
        "optimizaciones",
        // Portuguese
        "correcoes de bugs", "correcao de bugs", "correcoes de erros", "correcoes", "bugs corrigidos", "melhorias de desempenho",
        "melhorias", "otimizacoes",
        // Italian
        "correzioni di bug", "correzione di bug", "correzioni", "bug risolti", "miglioramenti delle prestazioni", "miglioramenti",
        "ottimizzazioni",
        // Dutch, Swedish, Polish, Turkish
        "verbeteringen", "prestatieverbeteringen", "oplossingen", "buggfixar", "buggrattningar", "forbattringar",
        "prestandaforbattringar", "poprawki bledow", "poprawki", "ulepszenia", "hata duzeltmeleri", "performans iyilestirmeleri",
        "iyilestirmeler",
        // Russian
        "исправления ошибок", "исправление ошибок", "улучшения производительности", "улучшения", "исправления",
    ]

    /// Scripts without spaces between words.
    private static let otherPhrases = [
        "軽微な不具合の修正", "不具合の修正", "不具合修正", "バグ修正", "パフォーマンスの改善", "パフォーマンス改善", "安定性の向上",
        "错误修复", "修复错误", "问题修复", "性能改进", "性能优化", "稳定性改进", "错误修正", "錯誤修正", "效能改進", "改进", "改進", "优化",
        "優化", "修复", "修復", "改善", "修正", "버그 수정", "성능 개선", "안정성 개선", "개선", "수정",
    ]

    /// The small words around the phrases, folded like the text (a set
    /// from an array: some words are in several languages).
    private static let fillers = Set(fillerWords.map(WhatsNewGenericText.fold))

    private static let fillerWords = [
        // English
        "and", "minor", "small", "tiny", "various", "general", "several", "some", "other", "many", "more", "overall", "the", "a", "an",
        "of", "for", "to", "in", "with", "this", "version", "release", "update", "app", "we", "have", "made", "our", "your", "you",
        "thanks", "thank", "using", "plus", "improved", "stability", "performance", "speed", "faster", "smoother", "stable",
        "reliability", "bugs", "bug", "issues", "issue", "crash", "crashes", "lots", "latest", "new", "includes", "contains", "and",
        "also", "all", "it", "is", "are",
        // German
        "und", "kleinere", "kleine", "diverse", "verschiedene", "allgemeine", "einige", "weitere", "der", "die", "das", "des", "fur",
        "mit", "dieser", "diese", "update", "wir", "haben", "leistung", "stabilitat", "fehler", "verbessert", "behoben", "sowie",
        // French
        "et", "de", "des", "du", "la", "le", "les", "mineures", "mineurs", "diverses", "divers", "generales", "plusieurs", "quelques",
        "autres", "bogues", "performances", "stabilite", "cette", "mise", "jour", "application", "nous", "avons", "amelioree",
        "ameliore", "corriges",
        // Spanish and Portuguese
        "y", "del", "el", "los", "las", "menores", "varias", "varios", "generales", "algunas", "otras", "errores", "rendimiento",
        "estabilidad", "esta", "actualizacion", "aplicacion", "hemos", "mejorado", "corregido", "e", "do", "da", "dos", "das", "o",
        "os", "as", "pequenas", "diversas", "gerais", "outras", "erros", "desempenho", "estabilidade", "versao", "atualizacao",
        "aplicativo", "corrigidos", "melhorado",
        // Italian
        "di", "della", "delle", "dei", "il", "minori", "varie", "vari", "generali", "alcuni", "altre", "errori", "prestazioni",
        "stabilita", "questa", "versione", "aggiornamento",
        // Dutch, Swedish, Polish, Turkish
        "en", "van", "het", "verschillende", "algemene", "enkele", "prestaties", "stabiliteit", "deze", "versie", "och", "av",
        "mindre", "olika", "allmanna", "buggar", "prestanda", "stabilitet", "denna", "uppdatering", "appen", "i", "oraz", "drobne",
        "rozne", "ogolne", "bledow", "wydajnosci", "stabilnosci", "ta", "wersja", "aktualizacja", "ve", "kucuk", "cesitli", "genel",
        "hata", "performans", "kararlilik", "bu", "surum", "guncelleme",
        // Russian
        "и", "мелкие", "различные", "общие", "некоторые", "ошибок", "производительности", "стабильности", "эта", "версия", "обновление",
        "приложения",
        // Japanese, Chinese, Korean
        "と", "の", "および", "及び", "和", "及", "与", "및", "와", "과", "その他", "其他", "기타", "軽微な", "各種", "一些", "등", "など", "等",
        "および", "いくつかの", "的",
    ]
}
