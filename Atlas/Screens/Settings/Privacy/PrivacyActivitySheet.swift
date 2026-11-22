//
//  PrivacyActivitySheet.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings → Privacy & Data → Activity → Show…: every push and every
/// call an assistant made, newest first, with Export… as JSON.
struct PrivacyActivitySheet: View {
    @Environment(PushHistory.self) private var history
    @Environment(MCPServerController.self) private var server
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false

    var body: some View {
        let lines = ActivityLine.lines(pushes: history.records, calls: server.log)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Activity")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Export…") { isExporting = true }
                    .disabled(lines.isEmpty)
                    .accessibilityIdentifier("settings.privacy.export")
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("settings.privacy.activity.done")
            }
            .padding(Spacing.large)
            Divider()
            if lines.isEmpty {
                Text("Nothing yet. Pushes and assistants’ calls show here.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .padding(Spacing.large)
                Spacer()
            } else {
                List(lines) { line in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Image(systemName: line.kind == .push ? "arrow.up.circle" : "sparkles")
                            .foregroundStyle(Palette.label2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                            Text(line.detail)
                                .font(.subheadline)
                                .foregroundStyle(Palette.label2)
                        }
                        Spacer()
                        Text(line.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityIdentifier("settings.privacy.activity")
            }
        }
        .frame(width: 640, height: 480)
        .fileExporter(
            isPresented: $isExporting,
            document: ActivityDocument(data: (try? ActivityLine.exportData(lines)) ?? Data()),
            contentType: .json,
            defaultFilename: String(localized: "Atlas Activity")
        ) { _ in }
    }
}
