//
//  ProductPageEditorHeader.swift
//  Atlas
//

import SwiftUI

/// The editor's top line: ‹ Pages back to the list, the page's name and
/// status, how many of its changes aren't pushed, Discard…, Delete…, and
/// Push and Submit… (Submit for Review… once it's pushed). Under 900 points
/// Discard and Delete go into a ⋯ menu.
struct ProductPageEditorHeader: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let isCompact: Bool
    let onReviewPush: (ProductPage) -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button {
                viewModel.back()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Pages")
                        .font(.body)
                }
                .foregroundStyle(Palette.accentText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back to Custom Product Pages"))
            .accessibilityIdentifier("pages.editor.back")
            Text(page.name)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pages.editor.name")
            Pill(text: page.state.title, style: page.state.pillStyle)
                .fixedSize()
                .accessibilityIdentifier("pages.editor.status")
            if pending > 0 {
                Pill(text: String(localized: "\(pending) not pushed"), style: .accent)
                    .fixedSize()
                    .accessibilityIdentifier("pages.editor.pending")
            }
            Spacer(minLength: Spacing.small)
            HStack(spacing: Spacing.small) {
                if isCompact {
                    if canDiscard || canDelete { moreMenu }
                } else {
                    if canDiscard {
                        Button("Discard…") { viewModel.confirmation = .discard(pageID: page.id) }
                            .accessibilityIdentifier("pages.editor.discard")
                    }
                    if canDelete {
                        Button("Delete…") { viewModel.confirmation = .delete(pageID: page.id) }
                            .accessibilityIdentifier("pages.editor.delete")
                    }
                }
                if let title = viewModel.primaryActionTitle(of: page) {
                    Button(title) {
                        if viewModel.pushAndSubmit(page) { onReviewPush(page) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isOffline && !page.isDraft && viewModel.pendingCount(of: page) == 0)
                    .accessibilityIdentifier("pages.editor.submit")
                }
            }
            .buttonBorderShape(.capsule)
            .fixedSize()
        }
        .frame(minHeight: 40)
    }

    private var pending: Int {
        page.isDraft ? 0 : viewModel.pendingCount(of: page)
    }

    private var canDiscard: Bool {
        !page.isDraft && pending > 0 && !viewModel.isLocked(page)
    }

    private var canDelete: Bool {
        viewModel.canChange && !viewModel.isLocked(page)
    }

    private var moreMenu: some View {
        Menu {
            if canDiscard {
                Button("Discard Changes…") { viewModel.confirmation = .discard(pageID: page.id) }
            }
            if canDelete {
                Button("Delete…", role: .destructive) { viewModel.confirmation = .delete(pageID: page.id) }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(canDiscard ? "More: Discard Changes, Delete" : "More: Delete"))
        .accessibilityIdentifier("pages.editor.more")
    }
}
