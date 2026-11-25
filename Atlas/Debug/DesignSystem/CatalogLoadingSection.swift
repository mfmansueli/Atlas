//
//  CatalogLoadingSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Loading (README-DS: loading data that isn't AI is a grey skeleton):
/// the shared skeletons, static in every mode, the line that says what
/// loads, and the image tile. AI work uses the AI effects instead; a
/// failure is amber.
struct CatalogLoadingSection: View {
    var body: some View {
        CatalogSection(
            title: "Loading",
            note: """
            A static grey skeleton shaped like what arrives: no shimmer, no spinner. \
            One line says what loads, at most six words. VoiceOver reads “Loading …” once per skeleton.
            """
        ) {
            VStack(alignment: .leading, spacing: Spacing.large) {
                specimen("SkeletonRows · sidebar, app menu, files") {
                    SkeletonRows(count: 3)
                        .frame(width: 280)
                        .loadingSkeleton(LoadingCopy.apps, identifier: "designSystem.catalog.rows")
                }
                specimen("SkeletonCard · Overview, Accessibility, reviews") {
                    HStack(alignment: .top, spacing: Spacing.medium) {
                        SkeletonCard()
                        SkeletonCard(height: Metrics.skeletonRowCardHeight, lines: 2)
                    }
                    .frame(maxWidth: 600)
                    .loadingSkeleton(LoadingCopy.accessibility, identifier: "designSystem.catalog.cards")
                }
                specimen("SkeletonTableRows · tables while they load or refresh (⌘R)") {
                    SkeletonTableRows(count: 4, showsDividers: true)
                        .frame(maxWidth: 600, maxHeight: 4 * (Metrics.tableRowHeight + 1))
                        .loadingSkeleton(LoadingCopy.storePage, identifier: "designSystem.catalog.table")
                }
                specimen("SkeletonTiles · a set's screenshots") {
                    SkeletonTiles()
                        .loadingSkeleton(LoadingCopy.screenshots, identifier: "designSystem.catalog.tiles")
                }
                specimen("LoadingLine · what loads") {
                    LoadingLine(text: LoadingCopy.productPages(appName: "Lumen").line ?? "")
                }
                specimen("ImageLoadingTile · an image on its way") {
                    HStack(spacing: Spacing.small) {
                        ImageLoadingTile()
                            .frame(width: Metrics.skeletonTileWidth * 2, height: Metrics.skeletonTileWidth * 2 * Metrics.skeletonTileAspect)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
                        ImageLoadingTile(isLoading: false)
                            .frame(width: Metrics.skeletonTileWidth * 2, height: Metrics.skeletonTileWidth * 2 * Metrics.skeletonTileAspect)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("designSystem.catalog.loading")
    }

    private func specimen(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
            content()
        }
    }
}
#endif
