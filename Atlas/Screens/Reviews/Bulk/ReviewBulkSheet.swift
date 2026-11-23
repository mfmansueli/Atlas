//
//  ReviewBulkSheet.swift
//  Atlas
//

import SwiftUI

/// Reply to All: one message per language, each going under its own
/// review. Reviews already replied to are left out.
struct ReviewBulkSheet: View {
    @Bindable var viewModel: ReviewsViewModel
    let plan: ReviewBulkPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    ForEach(plan.rows) { row in
                        ReviewBulkRowView(row: row, isOn: viewModel.bulkSelection.contains(row.languageCode)) {
                            viewModel.toggleBulk(row)
                        }
                    }
                    if let error = viewModel.errorMessage {
                        InlineMessage.error(error)
                            .font(.callout)
                            .accessibilityIdentifier("reviews.bulk.error")
                    }
                }
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.medium)
            }
            Divider()
            footer
        }
        .frame(width: 640)
        .frame(minHeight: 320, idealHeight: 560, maxHeight: 620)
        .disabled(viewModel.isSendingBulk)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.bulk")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(plan.title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reviews.bulk.title")
            Text("One message, in each language. Each reply goes under its own review only.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .lineLimit(3)
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.xLarge)
        .padding(.bottom, Spacing.small)
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            SuggestionSourceTag(source: .assistant(client: plan.theme.source))
            Text(leftOutText)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let progress = viewModel.bulkProgress {
                ProgressView(value: Double(progress.sent), total: Double(max(progress.total, 1)))
                    .frame(width: 80)
                Text("\(progress.sent) of \(progress.total)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Palette.label2)
            } else {
                Text(ReviewText.replies(viewModel.bulkReplyCount))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("reviews.bulk.count")
            }
            Button("Cancel") { viewModel.bulkPlan = nil }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("reviews.bulk.cancel")
            Button(viewModel.bulkSendTitle) {
                Task { await viewModel.sendBulk() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.bulkReplyCount == 0)
            .accessibilityIdentifier("reviews.bulk.send")
        }
        .buttonBorderShape(.capsule)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }

    /// "Reviews you already replied to are left out."
    private var leftOutText: String {
        let replied = String(localized: "Reviews you already replied to are left out.")
        switch plan.leftOutCount {
        case 0: return replied
        case 1: return replied + " " + String(localized: "So is 1 in a language without a message.")
        default: return replied + " " + String(localized: "So are \(plan.leftOutCount) in languages without a message.")
        }
    }
}
