//
//  NominationsBanner.swift
//  Atlas
//

import SwiftUI

/// The screen's one banner, the most pressing first: a key without the
/// role (Change Key…), Apple's refusal of the open nomination (Details),
/// offline (Try Again), or a read that failed.
struct NominationsBanner: View {
    @Bindable var viewModel: NominationsViewModel
    /// The open nomination, for Apple's refusal; nil in the gallery.
    let nominationID: String?
    let actions: NominationsScreen.Actions

    var body: some View {
        if viewModel.problem == .keyRole {
            Banner(
                kind: .warning,
                title: String(localized: "This key can’t create nominations.", comment: "kind:banner"),
                message: String(localized: "Use an Admin or App Manager key.", comment: "kind:banner")
            ) {
                Button("Change Key…", action: actions.changeKey)
                    .accessibilityIdentifier("nominations.banner.changeKey")
            }
            .accessibilityIdentifier("nominations.banner.keyRole")
        } else if let nominationID, let refusal = viewModel.refusal(for: nominationID) {
            refusalBanner(refusal)
        } else if viewModel.problem == .offline {
            Banner(
                kind: .offline,
                title: String(localized: "You’re offline.", comment: "kind:banner"),
                message: String(localized: "Changes wait in Review & Push.", comment: "kind:banner")
            ) {
                Button("Try Again") { Task { await viewModel.load(force: true) } }
            }
            .accessibilityIdentifier("nominations.banner.offline")
        } else if case let .failed(copy) = viewModel.problem, viewModel.state.value != nil {
            Banner(kind: .apiError, title: copy.summary, message: copy.details, isInline: true, fixTopic: copy.fixTopic) {
                Button("Try Again") { Task { await viewModel.load(force: true) } }
            }
            .accessibilityIdentifier("nominations.banner.failed")
        }
    }

    private func refusalBanner(_ refusal: NominationRefusal) -> some View {
        let copy = AppleErrorCopy(
            summary: String(localized: "Apple refused this nomination.", comment: "kind:banner"),
            details: refusal.details
        )
        let message = refusal.mentionsLink
            ? String(localized: "It stays a draft. Remove the link from the description, then add it to Review & Push again.", comment: "kind:banner")
            : String(localized: "It stays a draft. Fix what Apple names under Details, then add it to Review & Push again.", comment: "kind:banner")
        return VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Banner(kind: .warning, title: copy.summary, message: message) {
                Button(viewModel.showsRefusalDetails ? "Hide Details" : "Details") {
                    viewModel.showsRefusalDetails.toggle()
                }
                .accessibilityIdentifier("nominations.banner.details")
            }
            if viewModel.showsRefusalDetails, let details = copy.details {
                Text(details)
                    .font(.footnote.monospaced())
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .accessibilityIdentifier("nominations.refusal.details")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nominations.banner.refused")
    }
}
