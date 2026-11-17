//
//  ReviewsViewModel+Translation.swift
//  Atlas
//

import Foundation

// Reviews read in the app's language: each review not written in it is
// translated on this Mac once and kept. Show Original and Show Translation
// switch one review against the header's switch.
extension ReviewsViewModel {
    func setTranslates(_ translates: Bool) {
        store.setTranslates(translates)
        translationOverrides = [:]
        if translates { Task { await translate() } }
    }

    /// Whether `review` shows translated right now.
    func showsTranslation(_ review: AppReview) -> Bool {
        guard !ReviewLanguage.isAppLanguage(review.languageCode), archive.translations[review.id] != nil else { return false }
        return translationOverrides[review.id] ?? translates
    }

    func toggleTranslation(_ review: AppReview) {
        translationOverrides[review.id] = !showsTranslation(review)
    }

    func displayText(for review: AppReview) -> ReviewDisplayText {
        let language = ReviewLanguage.name(of: review.languageCode)
        guard !ReviewLanguage.isAppLanguage(review.languageCode) else {
            return ReviewDisplayText(title: review.title, body: review.body, note: nil, toggleTitle: nil, isTranslated: false, isRightToLeft: false)
        }
        if showsTranslation(review), let translation = archive.translations[review.id] {
            return ReviewDisplayText(
                title: translation.title, body: translation.body, note: String(localized: "Translated from \(language)"),
                toggleTitle: String(localized: "Show Original"), isTranslated: true, isRightToLeft: false
            )
        }
        return ReviewDisplayText(
            title: review.title, body: review.body, note: String(localized: "Original, in \(language)"),
            toggleTitle: archive.translations[review.id] == nil ? nil : String(localized: "Show Translation"),
            isTranslated: false, isRightToLeft: ReviewLanguage.isRightToLeft(review.languageCode)
        )
    }

    /// Translates the reviews that have no translation yet, one language
    /// at a time. A language Apple Translation has to download first is
    /// listed for the header; one it doesn't know stays as written.
    func translate() async {
        guard translates, !isTranslating else { return }
        isTranslating = true
        defer { isTranslating = false }
        let target = ReviewLanguage.appLanguageCode
        let waiting = reviews.filter { !ReviewLanguage.isAppLanguage($0.languageCode) && archive.translations[$0.id] == nil }
        var needed: [String] = []
        for (language, batch) in Dictionary(grouping: waiting, by: \.languageCode).sorted(by: { $0.key < $1.key }) {
            switch await services.translator.availability(from: language, to: target) {
            case .ready:
                await translate(batch, from: language, to: target)
            case .needsDownload:
                needed.append(language)
            case .unsupported:
                break
            }
        }
        languagesToDownload = needed
    }

    private func translate(_ batch: [AppReview], from language: String, to target: String) async {
        var kept: [AppReview.ID: ReviewTranslation] = [:]
        for review in batch {
            guard let texts = try? await services.translator.translate([review.title, review.body], from: language, to: target), texts.count == 2 else {
                continue
            }
            kept[review.id] = ReviewTranslation(title: texts[0], body: texts[1])
        }
        store.keep(kept, for: app.id)
    }

    /// "Apple Translation needs to download German and Japanese first."
    var downloadText: String? {
        guard translates, !languagesToDownload.isEmpty else { return nil }
        let names = languagesToDownload.map(ReviewLanguage.name).formatted(.list(type: .and))
        return String(localized: "Apple Translation needs to download \(names) before those reviews can be translated.")
    }
}
