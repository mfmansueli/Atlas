//
//  ConnectKeyFields.swift
//  Atlas
//

import SwiftUI

/// "Then paste it here" on Connect (README-Welcome): the Issuer ID, the
/// Key ID and the key file, each with where to find it on App Store
/// Connect's page and a green check once it looks right; the file area
/// turns green once a key is dropped.
struct ConnectKeyFields: View {
    @Bindable var viewModel: ConnectViewModel
    let focusedField: FocusState<ConnectViewModel.Field?>.Binding
    var showsExplanation = true
    var showsHints = true
    var startsWithDropHover = false
    let onChooseFile: () -> Void
    let onDrop: (URL) -> Void

    var body: some View {
        Card(padding: showsExplanation ? Spacing.large : Spacing.medium) {
            VStack(alignment: .leading, spacing: showsExplanation ? Spacing.medium : Spacing.small) {
                ConnectCardHeading(
                    title: "Then paste it here",
                    subtitle: "Three things from the page where you made the key.",
                    showsSubtitle: showsExplanation
                )
                ConnectFormField(
                    title: "Issuer ID",
                    hint: "top of the page",
                    showsHint: showsHints,
                    text: $viewModel.issuerID,
                    prompt: "69a6de70-0000-0000-0000-000000000000",
                    looksRight: viewModel.issuerIDLooksRight,
                    issue: viewModel.issuerIDIssue,
                    identifier: "connect.issuerIDField"
                )
                .focused(focusedField, equals: .issuerID)
                ConnectFormField(
                    title: "Key ID",
                    hint: "next to your key",
                    showsHint: showsHints,
                    text: $viewModel.keyID,
                    prompt: "2X9R4HXF34",
                    looksRight: viewModel.keyIDLooksRight,
                    issue: viewModel.keyIDIssue,
                    identifier: "connect.keyIDField"
                )
                .focused(focusedField, equals: .keyID)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    ConnectFieldLabel(
                        title: "Private key",
                        hint: "the file you downloaded",
                        showsHint: showsHints,
                        looksRight: viewModel.keyFileLooksRight,
                        identifier: "connect.keyFile"
                    )
                    PrivateKeyDropZone(
                        key: viewModel.privateKey,
                        rejectedFileName: viewModel.rejectedFileName,
                        isTargeted: startsWithDropHover,
                        onChoose: onChooseFile,
                        onRemove: { viewModel.removeKey() },
                        onDrop: onDrop
                    )
                    if let message = viewModel.importErrorMessage {
                        InlineMessage.error(message)
                            .accessibilityIdentifier("connect.importError")
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
