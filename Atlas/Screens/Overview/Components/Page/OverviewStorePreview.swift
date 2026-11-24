//
//  OverviewStorePreview.swift
//  Atlas
//

import SwiftUI

/// The Overview's right column: the App Store page as people see it, in one
/// of the app's languages, smaller; a click on a part opens the section
/// editing it.
struct OverviewStorePreview: View {
    let app: StoreApp
    let content: StorePageContent
    let screenshots: any ScreenshotsServices
    let links: AppStorePreviewLinks

    @Environment(AppSummaryStore.self) private var summaries
    @Environment(FieldSuggestionStore.self) private var suggestions
    @State private var selected: StoreLocale?
    @State private var ratings = StoreRatings.unchecked

    private struct RatingKey: Hashable {
        var appID: String
        var country: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // The picker goes under the title when both don't fit the column.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.small) {
                    title
                    Spacer(minLength: 0)
                    languagePicker
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    title
                    languagePicker
                }
            }
            AppStorePagePreview(model: model, appName: app.name, icon: app.icon, links: links, isCompact: true) {
                AppStorePreviewShots(
                    services: screenshots,
                    app: app,
                    localizations: content.ids.versionLocalizations,
                    locale: locale,
                    primary: content.primaryLocale,
                    width: 84
                )
            }
            Text("Click a part to edit it.")
                .font(.callout)
                .padding(.horizontal, Spacing.xxSmall)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 300)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.storePreview")
        .task(id: RatingKey(appID: app.id, country: locale.regionCode)) {
            let loaded = await StoreRatingLookup().ratings(appID: app.id, countries: [locale.regionCode])
            guard !Task.isCancelled else { return }
            ratings = loaded
        }
    }

    private var title: some View {
        Text("On the App Store")
            .font(.headline)
            .lineLimit(1)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    private var locale: StoreLocale {
        selected.flatMap { content.locales.contains($0) ? $0 : nil } ?? content.primaryLocale
    }

    /// The one language picker (README-DS §12), compact: the card is too
    /// narrow for the whole bar, and tabs don't scale. The menu counts each
    /// language's Store Page suggestions, as the Store Page does.
    @ViewBuilder
    private var languagePicker: some View {
        if content.locales.count > 1 {
            LanguagePickerButton(model: languageModel, style: .compact, identifier: "overview.storePreview.language") { locale in
                selected = locale
            }
        }
    }

    private var languageModel: LanguageBarModel {
        var counts: [String: Int] = [:]
        for suggestion in suggestions.toReview(for: app.id, area: .storePage) {
            if case let .storePage(code) = suggestion.target.scope { counts[code, default: 0] += 1 }
        }
        return .storePreview(locales: content.locales, primary: content.primaryLocale, current: locale, counts: counts)
    }

    private var model: AppStorePreviewModel {
        var model = AppStorePreviewModel(content: content, locale: locale)
        model.ratings = ratings
        model.addFacts(appInformation: summaries.appInformation[app.id]?.value, pricing: summaries.pricing[app.id]?.value)
        return model
    }
}
