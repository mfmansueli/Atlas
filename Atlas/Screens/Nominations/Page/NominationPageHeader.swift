//
//  NominationPageHeader.swift
//  Atlas
//

import SwiftUI

/// The top of a nomination's page: ‹ Nominations, its name, its state and
/// "Not pushed", and its actions. A draft: Submit… and Add to Review &
/// Push (or Remove, Cancel Submit, Open Review & Push once queued). A
/// submitted one: Archive…. An assistant's nomination: Dismiss and
/// Accept.
struct NominationPageHeader: View {
    @Bindable var viewModel: NominationsViewModel
    let title: String
    var nomination: Nomination?
    var proposal: NominationProposal?
    let actions: NominationsScreen.Actions
    /// The small window: secondary buttons tucked away.
    var isCompact = false

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button {
                viewModel.back()
            } label: {
                HStack(spacing: Spacing.tiny) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Nominations")
                        .font(.body)
                }
                .foregroundStyle(Palette.accentText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back to all nominations"))
            .accessibilityIdentifier("nominations.page.back")
            Text(title.isEmpty ? String(localized: "New Nomination", comment: "kind:section-title") : title)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("nominations.page.title")
            if proposal != nil {
                Pill(text: String(localized: "Suggested", comment: "kind:pill"), style: .machineTranslated).fixedSize()
            } else if let nomination {
                NominationStatePill(nomination: nomination)
                if !viewModel.queued(nomination.id).isEmpty, nomination.state != .archived {
                    Pill(text: String(localized: "Not pushed", comment: "kind:pill"), style: .accent)
                        .fixedSize()
                        .accessibilityIdentifier("nominations.page.notPushed")
                }
            }
            Spacer(minLength: Spacing.small)
            HStack(spacing: Spacing.small) {
                if let proposal {
                    proposalActions(proposal)
                } else if let nomination {
                    nominationActions(nomination)
                }
            }
            .buttonBorderShape(.capsule)
            .fixedSize()
        }
        .frame(minHeight: 40)
    }

    // MARK: - Actions

    @ViewBuilder
    private func proposalActions(_ proposal: NominationProposal) -> some View {
        Button("Dismiss") { viewModel.dismissProposal(proposal.id) }
            .accessibilityIdentifier("nominations.page.dismiss")
        Button("Accept") { viewModel.acceptProposal(proposal.id) }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("nominations.page.accept")
    }

    @ViewBuilder
    private func nominationActions(_ nomination: Nomination) -> some View {
        let queued = viewModel.queued(nomination.id)
        let blocked = viewModel.blockingReason(nomination)
        switch nomination.state {
        case .draft:
            if queued[.submit] != nil {
                Button("Cancel Submit") { viewModel.removeFromReviewPush(nomination.id, kinds: [.submit]) }
                    .accessibilityIdentifier("nominations.page.cancelSubmit")
                openReviewPush
            } else if queued[.create] != nil || queued[.update] != nil || queued[.delete] != nil {
                if !isCompact {
                    Button("Remove") { viewModel.removeFromReviewPush(nomination.id) }
                        .help(String(localized: "Take it out of Review & Push", comment: "kind:tooltip"))
                        .accessibilityIdentifier("nominations.page.remove")
                }
                if queued[.delete] == nil { submitButton(nomination, blocked: blocked, prominent: false) }
                openReviewPush
            } else if viewModel.canAddToReviewPush(nomination) {
                submitButton(nomination, blocked: blocked, prominent: false)
                Button("Add to Review & Push") { viewModel.addToReviewPush(nomination.id) }
                    .buttonStyle(.borderedProminent)
                    .disabled(blocked != nil)
                    .help(blocked ?? String(localized: "Saves the draft in App Store Connect when you push", comment: "kind:tooltip"))
                    .accessibilityIdentifier("nominations.page.add")
            } else {
                submitButton(nomination, blocked: blocked, prominent: true)
            }
            moreMenu(nomination)
        case .submitted:
            if queued[.archive] != nil {
                Button("Cancel Archive") { viewModel.removeFromReviewPush(nomination.id, kinds: [.archive]) }
                    .accessibilityIdentifier("nominations.page.cancelArchive")
            } else {
                Button("Archive…") { viewModel.sheet = .archive(nomination.id) }
                    .disabled(viewModel.keyCannotWrite)
                    .help(viewModel.keyCannotWrite
                        ? String(localized: "This key can’t change nominations", comment: "kind:tooltip")
                        : String(localized: "Asks before anything is sent", comment: "kind:tooltip"))
                    .accessibilityIdentifier("nominations.page.archive")
            }
        case .archived:
            EmptyView()
        }
    }

    @ViewBuilder
    private func submitButton(_ nomination: Nomination, blocked: String?, prominent: Bool) -> some View {
        let button = Button("Submit…") { viewModel.sheet = .submit(nomination.id) }
            .disabled(blocked != nil)
            .help(blocked ?? String(localized: "Asks before anything is sent", comment: "kind:tooltip"))
            .accessibilityIdentifier("nominations.page.submit")
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button
        }
    }

    private var openReviewPush: some View {
        Button("Open Review & Push", action: actions.openReviewPush)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("nominations.page.openReview")
    }

    private func moreMenu(_ nomination: Nomination) -> some View {
        Menu {
            Button("Delete Draft", systemImage: "trash", role: .destructive) { viewModel.deleteDraft(nomination.id) }
                .disabled(nomination.isInAppStoreConnect && viewModel.keyCannotWrite)
                .accessibilityIdentifier("nominations.page.delete")
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text("More"))
        .accessibilityIdentifier("nominations.page.more")
    }
}
