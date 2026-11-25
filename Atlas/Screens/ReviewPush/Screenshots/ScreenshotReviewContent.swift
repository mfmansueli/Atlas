//
//  ScreenshotReviewContent.swift
//  Atlas
//

import SwiftUI

/// The screenshot part of Review & Push, under the text changes: what a
/// restore queued, each app's sets, its Autopilot extras, then the notes.
struct ScreenshotReviewContent: View {
    let viewModel: ReviewPushViewModel
    let onShowInCaptions: (ScreenshotPlanExclusion) -> Void

    @Bindable private var extras: ExtrasPushController
    private let cleanup = AssetLibraryCleanupStore.shared

    init(viewModel: ReviewPushViewModel, onShowInCaptions: @escaping (ScreenshotPlanExclusion) -> Void) {
        self.viewModel = viewModel
        self.onShowInCaptions = onShowInCaptions
        extras = viewModel.extras
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let notice = viewModel.screenshots.notice {
                Banner(kind: .info, title: notice) {
                    Button {
                        viewModel.screenshots.notice = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Dismiss"))
                }
                .padding(.horizontal, -Spacing.large)
                .accessibilityIdentifier("review.shots.notice")
            }
            if let appID = viewModel.selectedAppID, let suggestion = cleanup.suggestion(for: appID) {
                AssetLibraryCleanupRow(
                    suggestion: suggestion,
                    appName: viewModel.selectedAppName ?? "",
                    onReview: { extras.library = viewModel.screenshots.assetLibraryModel(appID: appID) },
                    onDismiss: { cleanup.remove(for: appID) }
                )
            }
            ForEach(viewModel.screenshotPlans.filter { !$0.groups.isEmpty }, id: \.appID) { plan in
                ScreenshotReviewSection(plan: plan, viewModel: viewModel)
            }
            ForEach(viewModel.extrasPlans, id: \.appID) { plan in
                ExtrasReviewSection(plan: plan, viewModel: viewModel)
            }
            if viewModel.screenshots.isLoading, !viewModel.showsScreenshots {
                // The sets' rows to come: what's being checked over a
                // language's screenshots, static and grey.
                VStack(alignment: .leading, spacing: Spacing.small) {
                    if let line = LoadingCopy.pushScreenshots.line {
                        LoadingLine(text: line)
                    }
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: Spacing.small) {
                            SkeletonBlock(width: Metrics.skeletonFlagWidth, height: Metrics.skeletonFlagHeight, cornerRadius: Radius.flag)
                            SkeletonTiles(count: 5)
                        }
                    }
                }
                .padding(.horizontal, Spacing.small)
                .loadingSkeleton(LoadingCopy.pushScreenshots, identifier: "review.shots.loading")
            }
            ScreenshotReviewNotes(viewModel: viewModel, onShowInCaptions: onShowInCaptions)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.shots")
        .sheet(item: $extras.test) { model in
            ProductPageTestSheet(model: model, center: viewModel.screenshots.workspace?.screenshots.autopilot)
        }
        .sheet(item: $extras.library) { model in
            AssetLibrarySheet(model: model)
        }
    }

    /// Whether there's anything to show at all.
    static func hasContent(_ viewModel: ReviewPushViewModel) -> Bool {
        viewModel.showsScreenshots || viewModel.showsExtras || viewModel.screenshots.notice != nil
            || viewModel.selectedAppID.flatMap(AssetLibraryCleanupStore.shared.suggestion(for:)) != nil
            || !viewModel.screenshots.loadErrors.isEmpty || viewModel.screenshots.isLoading
    }
}
