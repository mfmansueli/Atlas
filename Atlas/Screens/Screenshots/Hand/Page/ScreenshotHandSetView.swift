//
//  ScreenshotHandSetView.swift
//  Atlas
//

import SwiftUI

/// One language's set on one device, to change by hand: the size it needs
/// and how many there are (or the selected screenshot's bar), the banner of
/// a language that uses the primary one's, the screenshots in order and the
/// Add Screenshots tile. Files dropped anywhere on the set are added.
struct ScreenshotHandSetView: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale
    let width: CGFloat

    @State private var isTargeted = false

    private var display: ScreenshotDisplayType { viewModel.displayType }

    var body: some View {
        let items = viewModel.handPageItems(locale: locale.code, displayType: display)
        let kept = items.count { !$0.isDeleted }
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let selected = items.first(where: \.isSelected) {
                ScreenshotHandSelectionBar(viewModel: viewModel, item: selected, count: items.count)
            } else {
                Text(viewModel.handDeviceLine(locale: locale.code, displayType: display))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .frame(minHeight: 20)
                    .accessibilityIdentifier("screenshots.hand.deviceLine")
            }
            if let banner = viewModel.handFallbackBanner(locale: locale, displayType: display) {
                ScreenshotHandFallbackBanner(
                    title: banner.title, detail: banner.detail, primaryName: viewModel.primaryLocaleName,
                    canCopy: viewModel.ownCount(locale: viewModel.context.primaryLocale.code, displayType: display) > 0
                ) {
                    Task { await viewModel.startHandFromPrimary() }
                } onAdd: {
                    viewModel.handSheet = .add([])
                }
            }
            if items.isEmpty, viewModel.isLoading {
                // Not "no screenshots yet" while the live ones are still read:
                // Alba's six live screenshots showed as none for seconds.
                HStack(spacing: Spacing.small) {
                    ProgressView().controlSize(.small)
                    Text("Reading App Store screenshots…")
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                }
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("screenshots.page.loading")
            } else {
                if items.isEmpty, locale.code == viewModel.context.primaryLocale.code {
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("No \(display.title) screenshots in \(locale.name) yet.")
                            .font(.callout)
                        Text("Add your own, or Start Autopilot… makes them from the app.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("screenshots.page.empty")
                }
                shots(items, kept: kept)
            }
        }
        .padding(isTargeted ? Spacing.xSmall : 0)
        .background {
            if isTargeted {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.accentTint)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let files = ScreenshotHandDrop.files(from: urls)
            guard !files.isEmpty else { return false }
            viewModel.handSheet = .add(files)
            return true
        } isTargeted: { isTargeted = $0 }
        .onChange(of: locale.code) { viewModel.handSelection = nil }
        .onChange(of: viewModel.displayType) { viewModel.handSelection = nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.hand.set")
    }

    private func shots(_ items: [ScreenshotHandPageItem], kept: Int) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                ForEach(items) { item in
                    LanguagePageThumbnail(viewModel: viewModel, item: item, localeName: locale.name, width: width)
                }
                if kept < ScreenshotHandSet.capacity {
                    ScreenshotHandAddTile(room: ScreenshotHandSet.capacity - kept, height: height) {
                        viewModel.handSheet = .add([])
                    } onDrop: { files in
                        viewModel.handSheet = .add(files)
                    }
                }
            }
            .padding(.vertical, Spacing.xxSmall)
            .environment(\.layoutDirection, locale.isRTL ? .rightToLeft : .leftToRight)
        }
        .scrollIndicators(.automatic)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.page.shots")
    }

    private var height: CGFloat {
        let size = viewModel.pixelSize(for: display)
        return (width * CGFloat(size.height) / CGFloat(max(1, size.width))).rounded()
    }
}
