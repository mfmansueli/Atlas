//
//  StoreArtworkPreviewAside.swift
//  Atlas
//

import SwiftUI

/// Beside a language's Screenshots page, as beside Store Page: its App
/// Store page with the header at the top and the "In search results" card,
/// changes waiting in Review & Push included, and the Now · Suggested
/// switch for the captions.
struct StoreArtworkPreviewAside: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    var body: some View {
        // One scroll view from the top of the page, so the toolbar's hard
        // edge spans this column too; the title and switch stay pinned.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.small, pinnedViews: .sectionHeaders) {
                Section {
                    page
                        .padding(Spacing.tiny)
                        .padding(.bottom, Spacing.large)
                } header: {
                    header
                }
            }
        }
        .contentMargins(.top, Spacing.large, for: .scrollContent)
        // The page's trailing margin inside the scroll view, so the
        // toolbar's edge reaches the window's right edge.
        .contentMargins(.trailing, Spacing.xLarge, for: .scrollContent)
        .scrollIndicators(.never)
        .frame(width: Metrics.storePreviewColumnWidth + Spacing.xLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.page.storePreview")
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            Text("On the App Store", comment: "kind:section-title")
                .atlasTextStyle(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Picker(String(localized: "Captions", comment: "kind:label"), selection: $viewModel.showsSuggestedCaptions) {
                Text("Now", comment: "kind:segment").tag(false)
                Text("Suggested", comment: "kind:segment").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            .accessibilityIdentifier("screenshots.page.mode")
        }
        .padding(.bottom, Spacing.small)
        .background(Palette.content)
    }

    @ViewBuilder
    private var page: some View {
        let services = viewModel.services
        let app = viewModel.app
        let localizations = viewModel.context.localizations
        let primary = viewModel.context.primaryLocale
        if let content = viewModel.storeContent {
            let model = AppStorePreviewModel(content: content, locale: locale)
            AppStorePreviewArtworkReader(
                services: services, app: app, localizations: localizations, locale: locale, primary: primary,
                knownDocument: viewModel.document
            ) { artwork in
                VStack(spacing: Spacing.medium) {
                    AppStorePagePreview(
                        model: model, appName: app.name, icon: app.icon, isCompact: true,
                        headerArt: .shown(artwork, services: services, app: app, onOpen: nil)
                    ) {
                        AppStorePreviewShots(
                            services: services, app: app, localizations: localizations, locale: locale, primary: primary,
                            showsSuggested: viewModel.showsSuggestedCaptions
                        )
                    }
                    AppStorePreviewSearchCard(services: services, app: app, model: model, artwork: artwork)
                }
            }
        } else {
            ImageLoadingTile(isLoading: true, systemImage: nil)
                .frame(height: Metrics.storePreviewSkeletonHeight)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        }
    }
}
