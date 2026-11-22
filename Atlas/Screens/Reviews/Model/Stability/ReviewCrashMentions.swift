//
//  ReviewCrashMentions.swift
//  Atlas
//

import Foundation

/// Whether a review talks about the app crashing or closing by itself, in
/// the languages reviews come in most. Words, not meaning: a review that
/// says "no crashes" counts too, so it's a pointer, not a verdict.
enum ReviewCrashMentions {
    static let words = [
        // English
        "crash", "keeps closing", "closes itself", "shuts down", "freezes", "force close",
        // Portuguese, Spanish, Italian
        "trava", "travando", "fecha sozinho", "fechando sozinho", "se cierra", "se bloquea", "si chiude", "si blocca", "crasha",
        // German, French, Dutch
        "stürzt ab", "absturz", "abgestürzt", "plante", "se ferme", "loopt vast", "sluit af",
        // Japanese, Korean, Chinese
        "落ちる", "落ちます", "クラッシュ", "강제 종료", "튕", "闪退", "崩溃", "閃退",
    ]

    static func mentionsCrash(_ review: AppReview) -> Bool {
        let text = (review.title + " " + review.body).lowercased()
        return words.contains { text.contains($0) }
    }
}
