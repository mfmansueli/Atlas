//
//  ScreenshotAddSheet.swift
//  Atlas
//

import SwiftUI

/// Add Screenshots: the files dropped or chosen, each checked (wrong sizes
/// and those over 10 are skipped, never scaled), after the last screenshot
/// of this language or of every language with its own.
struct ScreenshotAddSheet: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    @State private var files: [ScreenshotHandChosenFile]
    @State private var scope: ScreenshotHandScope = .one
    @State private var isTargeted = false

    init(viewModel: ScreenshotsViewModel, locale: StoreLocale, initialFiles: [ScreenshotHandChosenFile]) {
        self.viewModel = viewModel
        self.locale = locale
        _files = State(initialValue: initialFiles)
    }

    private var display: ScreenshotDisplayType { viewModel.displayType }
    private var count: Int { viewModel.ownCount(locale: locale.code, displayType: display) }
    private var room: Int { max(0, ScreenshotHandSet.capacity - count) }
    private var ownCount: Int { viewModel.ownLocales(on: display).count }

    /// The files that go: the first ones that fit, as many as there's room.
    private var taken: [ScreenshotHandChosenFile.ID] {
        Array(files.filter { ScreenshotHandFileCheck($0, on: display).fits }.prefix(room).map(\.id))
    }

    var body: some View {
        let taken = taken
        ScreenshotHandSheetLayout(
            viewModel: viewModel,
            title: String(localized: "Add Screenshots"),
            subtitle: String(localized: "\(locale.name) · \(display.title) · \(count) of \(ScreenshotHandSet.capacity), room for \(room)"),
            okTitle: taken.isEmpty ? String(localized: "Add") : String(localized: "Add \(taken.count)"),
            isOKDisabled: taken.isEmpty
        ) {
            if files.isEmpty {
                dropZone
            } else {
                list(taken: Set(taken))
                ScreenshotHandScopeOptions(label: String(localized: "Add them to"), options: [
                    .init(scope: .one, title: String(localized: "Only \(locale.name)"), detail: String(localized: "After its last screenshot.")),
                    .init(scope: .every, title: String(localized: "Every language with its own screenshots (\(ownCount))"),
                          detail: String(localized: "The same images, after each language’s last screenshot."), isDisabled: ownCount < 1),
                ], selection: $scope)
                ScreenshotHandNote(text: count == 0
                    ? String(localized: "They become \(locale.name)’s own screenshots. Select one afterwards to move it.")
                    : String(localized: "They go after screenshot \(count). Select one afterwards to move it."))
            }
        } onOK: {
            let chosen = files.filter { taken.contains($0.id) }
            viewModel.handSheet = nil
            Task { await viewModel.addHand(chosen, scope: scope) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let dropped = ScreenshotHandDrop.files(from: urls)
            files += dropped
            return !dropped.isEmpty
        } isTargeted: { isTargeted = $0 }
        .accessibilityIdentifier("screenshots.hand.addSheet")
    }

    private var sizeHint: String {
        String(localized: "\(display.title) needs \(ScreenshotHandSizes.all(on: display)).")
    }

    private var dropZone: some View {
        Button(action: choose) {
            VStack(spacing: Spacing.xSmall) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2.weight(.semibold))
                Text("Drop PNG or JPEG files here")
                    .font(.body.weight(.semibold))
                Text("or click to choose them. \(sizeHint)")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(isTargeted ? Palette.accentTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.label3, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("screenshots.hand.add.drop")
    }

    private func list(taken: Set<ScreenshotHandChosenFile.ID>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(files) { file in
                Divider()
                HStack(spacing: Spacing.medium) {
                    ScreenshotHandChosenImage(file: file, width: 26, height: 48)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.fileName)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(file.pixelSize?.title ?? String(localized: "Not an image"))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Palette.label2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    let status = status(of: file, taken: taken)
                    Pill(text: status.title, style: status.isReady ? .accent : .danger)
                        .fixedSize()
                        .help(ScreenshotHandFileCheck(file, on: display).problem(fileName: file.fileName, on: display) ?? "")
                }
                .padding(.vertical, Spacing.xSmall)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("screenshots.hand.add.file")
            }
            Button("Add More Files…", action: choose)
                .controlSize(.regular)
                .padding(.top, Spacing.xSmall)
                .accessibilityIdentifier("screenshots.hand.add.more")
        }
    }

    private func status(of file: ScreenshotHandChosenFile, taken: Set<ScreenshotHandChosenFile.ID>) -> (title: String, isReady: Bool) {
        let check = ScreenshotHandFileCheck(file, on: display)
        guard check.fits else { return (check.shortTitle, false) }
        return taken.contains(file.id) ? (check.shortTitle, true) : (String(localized: "Over 10 · skipped"), false)
    }

    private func choose() {
        if let chosen = ScreenshotHandFilePanel.chooseFiles(display: display, language: locale.name, multiple: true) {
            files += chosen
        }
    }
}
