//
//  AutoReplyHistorySheet.swift
//  Atlas
//

import SwiftUI

/// Every reply that went out by itself (board 58 · 5), newest first, with
/// the rule that allowed it and Undo, which takes it off the App Store and
/// keeps the draft under the review.
struct AutoReplyHistorySheet: View {
    let entries: [AutoReplyHistoryEntry]
    let onUndo: (AutoReplyHistoryEntry) async -> String?
    @State private var undoing: Set<AutoReplyHistoryEntry.ID> = []
    @State private var errors: [AutoReplyHistoryEntry.ID: String] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sent Automatically")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(Spacing.large)
            List(entries) { entry in
                row(entry)
            }
            .listStyle(.inset)
            Divider()
            HStack {
                Text("Undo takes a reply off the App Store; its draft stays under the review.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Spacing.large)
        }
        .frame(width: 600, height: 520)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autoReply.history")
    }

    private func row(_ entry: AutoReplyHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("\(entry.rating)★ · \(entry.reviewer)")
                    .font(.callout.weight(.semibold))
                Text(entry.text)
                    .font(.callout)
                    .lineLimit(3)
                Text(caption(entry))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                if let error = errors[entry.id] {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Palette.warningMark)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if entry.undoneAt == nil {
                Button("Undo") {
                    undoing.insert(entry.id)
                    Task {
                        errors[entry.id] = await onUndo(entry)
                        undoing.remove(entry.id)
                    }
                }
                .disabled(undoing.contains(entry.id))
                .accessibilityIdentifier("autoReply.history.undo.\(entry.reviewID)")
            }
        }
        .padding(.vertical, Spacing.xxSmall)
    }

    /// "Sent automatically Nov 22, 10:14 · 4★ and 5★ … go out after 1
    /// hour", or that it was undone.
    private func caption(_ entry: AutoReplyHistoryEntry) -> String {
        if let undone = entry.undoneAt {
            return String(localized: "Undone \(undone.formatted(date: .abbreviated, time: .shortened)): it’s off the App Store")
        }
        return String(localized: "Sent automatically \(entry.sentAt.formatted(date: .abbreviated, time: .shortened)) · \(entry.rule)")
    }
}
