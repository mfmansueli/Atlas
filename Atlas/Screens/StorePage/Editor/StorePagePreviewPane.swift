//
//  StorePagePreviewPane.swift
//  Atlas
//

import SwiftUI

/// Beside the editor: the language's App Store page, as it is now or with
/// the suggestions on top, with the real rating of that storefront and the
/// In-App Event live now. A click on the App Preview and screenshots opens
/// Screenshots; on the event, In-App Events.
struct StorePagePreviewPane: View {
    let viewModel: StorePageViewModel
    let locale: StoreLocale

    @Environment(AppSummaryStore.self) private var summaries
    /// Nil in previews without the window's.
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?
    @Environment(InAppEventsStore.self) private var events: InAppEventsStore?
    @State private var showsSuggested = true
    @State private var ratings = StoreRatings.unchecked

    private struct RatingKey: Hashable {
        var appID: String
        var country: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text("On the App Store")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("Preview", selection: $showsSuggested) {
                    Text("Now").tag(false)
                    Text("Suggested").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .accessibilityIdentifier("storePreview.mode")
            }
            ScrollView {
                let services = viewModel.services.screenshots
                let localizations = viewModel.content?.ids.versionLocalizations ?? [:]
                let primary = viewModel.listing?.primaryLocale ?? locale
                let model = model
                let openArtwork = links?.artwork.map { open in { open(locale.code) } }
                AppStorePreviewArtworkReader(
                    services: services, app: viewModel.app, localizations: localizations, locale: locale, primary: primary
                ) { artwork in
                    VStack(spacing: Spacing.medium) {
                        AppStorePagePreview(
                            model: model, appName: viewModel.app.name, icon: viewModel.app.icon, links: links,
                            headerArt: .shown(artwork, services: services, app: viewModel.app, onOpen: openArtwork)
                        ) {
                            AppStorePreviewShots(
                                services: services,
                                app: viewModel.app,
                                localizations: localizations,
                                locale: locale,
                                primary: primary,
                                showsSuggested: showsSuggested,
                                onPlay: links?.appPreview
                            )
                        }
                        AppStorePreviewSearchCard(services: services, app: viewModel.app, model: model, artwork: artwork, onOpen: openArtwork)
                    }
                }
                .padding(2)
                .padding(.bottom, 18)
            }
            .leavesChatRoom()
            .scrollIndicators(.never)
        }
        .frame(width: 290)
        .task(id: RatingKey(appID: viewModel.app.id, country: locale.regionCode)) {
            let loaded = await StoreRatingLookup().ratings(appID: viewModel.app.id, countries: [locale.regionCode])
            guard !Task.isCancelled else { return }
            ratings = loaded
        }
    }

    private var model: AppStorePreviewModel {
        var model = viewModel.previewModel(in: locale, showsSuggested: showsSuggested)
        model.ratings = ratings
        model.addFacts(appInformation: summaries.appInformation[viewModel.app.id]?.value, pricing: summaries.pricing[viewModel.app.id]?.value)
        model.liveEvent = AppStoreLiveEvent.happening(in: events?.lastRead(for: viewModel.app.id) ?? [], locale: locale, now: .now, appID: viewModel.app.id)
        return model
    }

    /// The parts the editor beside it doesn't cover: the screenshots, the
    /// App Preview and the event.
    private var links: AppStorePreviewLinks? {
        guard let navigator else { return nil }
        let screenshots = AppWorkspaceSection.screenshots
        return AppStorePreviewLinks(
            screenshots: AppStorePreviewLink(title: screenshots.title, count: 0) { navigator.open(screenshots) },
            inAppEvent: { navigator.open(.inAppEvents, intent: .showInAppEvents(eventID: $0)) },
            appPreview: { navigator.open(.screenshots, intent: .showScreenshotsLanguage($0, displayType: $1)) },
            artwork: { navigator.open(.screenshots, intent: .showScreenshotsLanguage($0, displayType: .iPhone)) }
        )
    }
}
