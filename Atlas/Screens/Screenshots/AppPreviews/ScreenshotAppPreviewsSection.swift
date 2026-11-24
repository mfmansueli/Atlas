//
//  ScreenshotAppPreviewsSection.swift
//  Atlas
//

import SwiftUI

/// The language page's App Previews on iPhone and iPad (README-Manual): the
/// set as it ends after the push, each to replace, move or delete, and
/// Choose App Previews… to add videos the person already has. Checked
/// before queueing; every problem is said at once with its fix. Nothing
/// reaches the App Store until Review & Push. README-Manual draws no App
/// Preview row: this follows the screenshot set's pattern above it.
struct ScreenshotAppPreviewsSection: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    @Environment(ChangeQueue.self) private var queue
    @State private var isReading = false

    private var display: ScreenshotDisplayType { viewModel.displayType }

    var body: some View {
        if let content = viewModel.appPreviewSet(locale: locale.code, displayType: display, queue: queue) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                header(content)
                if content.slots.isEmpty {
                    Text("No App Previews in \(locale.name) on \(display.title).", comment: "kind:empty")
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                } else {
                    tiles(content)
                }
                if let deleted = deletedLine(content) {
                    Text(deleted)
                        .atlasTextStyle(.footnote)
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("screenshots.appPreviews.deleted")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screenshots.appPreviews")
            .alert(
                Text("These App Previews can’t go in the set", comment: "kind:title"),
                isPresented: Binding(get: { !viewModel.appPreviewProblems.isEmpty }, set: { if !$0 { viewModel.appPreviewProblems = [] } })
            ) {
                Button(String(localized: "OK", comment: "kind:button")) { viewModel.appPreviewProblems = [] }
            } message: {
                Text(viewModel.appPreviewProblems.joined(separator: "\n"))
            }
        }
    }

    private func header(_ content: AppPreviewSetPush.Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                titles(content)
                Spacer(minLength: Spacing.small)
                chooseButton(content)
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                titles(content)
                chooseButton(content)
            }
        }
    }

    private func titles(_ content: AppPreviewSetPush.Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("App Previews", comment: "kind:section")
                .atlasTextStyle(.headline)
            Text(viewModel.appPreviewLine(content))
                .atlasTextStyle(.footnote)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("screenshots.appPreviews.line")
        }
    }

    private func chooseButton(_ content: AppPreviewSetPush.Content) -> some View {
        Button {
            choose(room: AppPreviewSetPush.Content.capacity - content.slots.count, replacing: nil)
        } label: {
            if isReading {
                HStack(spacing: Spacing.xSmall) {
                    ProgressView().controlSize(.mini)
                    Text("Reading App Previews…", comment: "kind:status")
                }
            } else {
                Text("Choose App Previews…", comment: "kind:button")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isReading || !content.hasRoom)
        .help(Text("Adds videos you have after the last App Preview. A set takes up to 3.", comment: "kind:tooltip"))
        .accessibilityIdentifier("screenshots.appPreviews.choose")
    }

    private func tiles(_ content: AppPreviewSetPush.Content) -> some View {
        FlowLayout(spacing: Spacing.small) {
            ForEach(Array(content.slots.enumerated()), id: \.offset) { index, slot in
                ScreenshotAppPreviewTile(
                    slot: slot, position: index, count: content.slots.count, displayType: display,
                    onReplace: { choose(room: 1, replacing: index) },
                    onMove: { offset in viewModel.moveAppPreview(at: index, by: offset, locale: locale.code, displayType: display, queue: queue) },
                    onDelete: { viewModel.deleteAppPreview(at: index, locale: locale.code, displayType: display, queue: queue) }
                )
            }
        }
    }

    /// "1 live App Preview will be deleted when you push."
    private func deletedLine(_ content: AppPreviewSetPush.Content) -> String? {
        let replaced = Set(content.slots.compactMap { $0.file == nil ? nil : $0.replacesID })
        let deleted = content.deletedIDs.count { !replaced.contains($0) }
        guard deleted > 0 else { return nil }
        return deleted == 1
            ? String(localized: "1 live App Preview will be deleted when you push.", comment: "kind:caption")
            : String(localized: "\(deleted) live App Previews will be deleted when you push.", comment: "kind:caption")
    }

    private func choose(room: Int, replacing: Int?) {
        guard let urls = ProductPageVideoFilePanel.choose(language: locale.name, displayType: display, room: room, replacing: replacing) else { return }
        isReading = true
        Task {
            await viewModel.chooseAppPreviews(urls, replacing: replacing, locale: locale.code, displayType: display, queue: queue)
            isReading = false
        }
    }
}
