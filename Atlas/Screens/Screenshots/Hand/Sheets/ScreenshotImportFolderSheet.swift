//
//  ScreenshotImportFolderSheet.swift
//  Atlas
//

import SwiftUI

/// Import a Folder: screenshots for several languages and devices at once,
/// from folders named by language as fastlane does. A table shows what each
/// folder does before anything changes; unknown languages and wrong sizes
/// are skipped with the reason.
struct ScreenshotImportFolderSheet: View {
    @Bindable var viewModel: ScreenshotsViewModel

    @State private var rows: [ScreenshotFolderImportRow]?
    @State private var mode: ScreenshotFolderImportMode = .replace
    @State private var isReading = false
    @State private var isTargeted = false

    private var ready: [ScreenshotFolderImportRow] { (rows ?? []).filter(\.isReady) }

    var body: some View {
        let total = ready.reduce(0) { $0 + fileCount($1) }
        ScreenshotHandSheetLayout(
            viewModel: viewModel,
            title: String(localized: "Import a Folder"),
            subtitle: String(localized: "Screenshots for several languages and devices at once"),
            okTitle: rows == nil ? String(localized: "Import") : String(localized: "Import \(total) Screenshots"),
            isOKDisabled: total == 0
        ) {
            if let rows {
                table(rows)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text("For each language in the folder")
                        .font(.body.weight(.semibold))
                    RadioRow(
                        title: String(localized: "Replace its screenshots"), detail: String(localized: "Its current ones are deleted when you push."),
                        isSelected: mode == .replace
                    ) { mode = .replace }
                        .accessibilityIdentifier("screenshots.hand.import.replace")
                    RadioRow(
                        title: String(localized: "Add them after its screenshots"), detail: String(localized: "Up to 10 in each language and device."),
                        isSelected: mode == .add
                    ) { mode = .add }
                        .accessibilityIdentifier("screenshots.hand.import.add")
                }
                ScreenshotHandNote(text: String(localized: "Languages and devices that aren’t in the folder stay as they are."))
                Button("Choose Another Folder…", action: choose)
                    .controlSize(.regular)
            } else {
                explanation
            }
        } onOK: {
            let chosen = ready
            let mode = mode
            viewModel.handSheet = nil
            Task { await viewModel.importHandFolder(chosen, mode: mode) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let folder = urls.first(where: \.hasDirectoryPath) else { return false }
            read(folder)
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityIdentifier("screenshots.hand.importSheet")
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Name folders by language, as fastlane does. Put the device in the folder or file name.")
                .font(.callout)
            Text("""
            \(viewModel.app.name) screenshots/
              de-DE/iphone-6.9/01.png … 05.png
              ja/iphone-6.9/01.png … 05.png
              fr-FR/ipad-13/01.png … 03.png
            """)
            .font(.system(.caption, design: .monospaced))
            .padding(Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isTargeted ? Palette.accentTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field))
            HStack(spacing: Spacing.small) {
                Button("Choose Folder…", action: choose)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("screenshots.hand.import.choose")
                if isReading {
                    ProgressView().controlSize(.small)
                    Text("Reading the folder…")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
        }
    }

    private func table(_ rows: [ScreenshotFolderImportRow]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xSmall) {
            GridRow {
                Text("LANGUAGE")
                Text("DEVICE")
                Text("FILES")
                Text("WHAT HAPPENS")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.label2)
            ForEach(rows) { row in
                Divider()
                GridRow {
                    Text(row.languageName)
                        .fontWeight(.semibold)
                    Text(row.displayType?.title ?? "—")
                    Text(fileCount(row), format: .number)
                        .monospacedDigit()
                    Text(whatHappens(row))
                        .foregroundStyle(row.isReady ? Palette.label : Palette.err)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("screenshots.hand.import.row")
            }
        }
    }

    private func fileCount(_ row: ScreenshotFolderImportRow) -> Int {
        guard row.isReady, let code = row.localeCode, let display = row.displayType, mode == .add else { return row.files.count }
        let room = ScreenshotHandSet.capacity - viewModel.ownCount(locale: code, displayType: display)
        return max(0, min(row.files.count, room))
    }

    private func whatHappens(_ row: ScreenshotFolderImportRow) -> String {
        guard row.isReady, let code = row.localeCode, let display = row.displayType else { return row.problem ?? "" }
        let current = viewModel.ownCount(locale: code, displayType: display)
        let count = row.files.count
        var text: String
        switch mode {
        case .replace:
            text = current == 0
                ? String(localized: "Adds these \(count)")
                : String(localized: "Replaces its \(current) with these \(count)")
        case .add:
            let room = max(0, ScreenshotHandSet.capacity - current)
            text = room == 0
                ? String(localized: "Skipped: it already has 10")
                : String(localized: "Adds \(min(count, room)) after its last one")
            if room > 0, count > room { text += " " + String(localized: "(\(count - room) over 10 skipped)") }
        }
        if !row.skippedFiles.isEmpty {
            text += " · " + String(localized: "\(row.skippedFiles.count) skipped: \(row.skippedFiles.joined(separator: ", "))")
        }
        return text
    }

    private func choose() {
        guard let folder = ScreenshotHandFilePanel.chooseFolder() else { return }
        read(folder)
    }

    private func read(_ folder: URL) {
        isReading = true
        let importer = ScreenshotFolderImporter(pageLocales: viewModel.pageLocales, appName: viewModel.app.name)
        Task {
            let found = await Task.detached(priority: .userInitiated) { importer.rows(in: folder) }.value
            rows = found
            isReading = false
        }
    }
}
