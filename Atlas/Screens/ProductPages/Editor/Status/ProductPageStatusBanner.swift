//
//  ProductPageStatusBanner.swift
//  Atlas
//

import SwiftUI

/// Where the page stands with App Review, above its fields, with what can
/// be done from here: Cancel Submission, Edit… or Open in App Store
/// Connect.
struct ProductPageStatusBanner: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let note = viewModel.statusNote(of: page) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Image(systemName: symbol(note.tone))
                    .foregroundStyle(tint(note.tone))
                    .accessibilityHidden(true)
                Text("\(Text(note.title).fontWeight(.semibold)) \(note.message)")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("pages.status.text")
                if let action = note.action {
                    button(action)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, 10)
            .background(background(note.tone), in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pages.status")
        }
    }

    @ViewBuilder
    private func button(_ action: ProductPageStatusNote.Action) -> some View {
        switch action {
        case .cancelSubmission:
            HStack(spacing: Spacing.xSmall) {
                if viewModel.isCancellingSubmission { ProgressView().controlSize(.small) }
                Button("Cancel Submission") {
                    Task { await viewModel.cancelSubmission(of: page) }
                }
                .disabled(viewModel.isCancellingSubmission)
                .accessibilityIdentifier("pages.status.cancel")
            }
            .controlSize(.regular)
        case .edit:
            Button("Edit…") { viewModel.startNewVersion(of: page) }
                .controlSize(.regular)
                .accessibilityIdentifier("pages.status.edit")
        case .openAppStoreConnect:
            Button("Open in App Store Connect") { openURL(viewModel.appStoreConnectURL) }
                .controlSize(.regular)
                .accessibilityIdentifier("pages.status.openASC")
        }
    }

    private func symbol(_ tone: ProductPageStatusNote.Tone) -> String {
        switch tone {
        case .waiting: "clock"
        case .fine: "checkmark.circle.fill"
        case .problem: "exclamationmark.octagon.fill"
        }
    }

    private func tint(_ tone: ProductPageStatusNote.Tone) -> Color {
        switch tone {
        case .waiting: Palette.label2
        case .fine: Palette.decrease
        case .problem: Palette.err
        }
    }

    private func background(_ tone: ProductPageStatusNote.Tone) -> Color {
        switch tone {
        case .waiting: Palette.fill1
        case .fine: Palette.decreaseTint
        case .problem: Palette.errTint
        }
    }
}
