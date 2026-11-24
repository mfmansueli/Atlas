//
//  ScreenshotsBar.swift
//  Atlas
//

import SwiftUI

/// The bar under the Store Page's: Sets | Template | Captions | Captures
/// (with the overflowing captions' count), the display type, the locale
/// scope, the render status and S / M / L. When it doesn't fit on one line,
/// S / M / L moves to a second one, then the status with it; in a narrow
/// window the display type and the scope get a line of their own too, so
/// the bar never holds the window's content wider than the window.
struct ScreenshotsBar: View {
    @Bindable var viewModel: ScreenshotsViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) {
                controls
                Spacer(minLength: Spacing.medium)
                status
                sizes
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    controls
                    Spacer(minLength: Spacing.medium)
                    status
                }
                sizes
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                controls
                HStack(spacing: Spacing.small) {
                    sizes
                    Spacer(minLength: Spacing.medium)
                    status
                }
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                views
                pickers
                HStack(spacing: Spacing.small) {
                    sizes
                    Spacer(minLength: Spacing.medium)
                    status
                }
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.bar")
    }

    private var controls: some View {
        HStack(spacing: Spacing.small) {
            views
            pickers
        }
    }

    /// Back to the language page, and the views with the overflow count.
    private var views: some View {
        HStack(spacing: Spacing.small) {
            Button {
                viewModel.showsLanguagePage = true
            } label: {
                Label("Screenshots", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
            }
            .buttonBorderShape(.capsule)
            .help("Back to each language's screenshots, with their suggested captions")
            .accessibilityLabel(Text("Back to the language page"))
            .accessibilityIdentifier("screenshots.backToPage")
            HStack(spacing: Spacing.xxSmall) {
                FittingSegmentedPicker(
                    label: String(localized: "Screenshots views"),
                    options: ScreenshotsTab.allCases.map { ($0, $0.title) },
                    selection: $viewModel.tab
                )
                .fixedSize()
                .accessibilityIdentifier("screenshots.tabs")
                if viewModel.overflowingCaptions > 0 {
                    Pill(text: "\(viewModel.overflowingCaptions)", style: .danger)
                        .fixedSize()
                        .help(Text("Captions that don’t fit on \(viewModel.displayType.title)"))
                        .accessibilityLabel(Text("\(viewModel.overflowingCaptions) captions overflow"))
                        .accessibilityIdentifier("screenshots.overflowCount")
                }
            }
        }
    }

    /// The display type and the locales that get their own screenshots.
    private var pickers: some View {
        HStack(spacing: Spacing.small) {
            DisplayTypeMenu(viewModel: viewModel)
            Button {
                viewModel.openScope()
            } label: {
                Label(viewModel.scopeTitle, systemImage: "globe")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .fixedSize()
            .disabled(!viewModel.hasCaptures)
            .accessibilityHint(Text("Choose which locales get their own screenshots"))
            .accessibilityIdentifier("screenshots.scopeButton")
        }
    }

    private var status: some View {
        RenderStatusView(progress: viewModel.renderQueue.progress, status: viewModel.statusText)
    }

    @ViewBuilder
    private var sizes: some View {
        if viewModel.showsThumbnailSizes {
            ThumbnailSizePicker(selection: $viewModel.thumbnailSize)
        }
    }
}
