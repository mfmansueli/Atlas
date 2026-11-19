//
//  AssistantConnectedCard.swift
//  Atlas
//

import SwiftUI

/// The overview's line once an assistant is set up (which one, and what
/// is true for this app: connected in its project folder, in another
/// project, ready for Atlas to start, not connected, or refused for an old
/// token, with Reconnect… or Choose Folder… when that's what it needs) or
/// an API key is ready (its model and what it reads), with Suggest
/// Everything… (its waiting popover hangs from it) or, with a key, Generate
/// Store Page Suggestions…, and Details (the Assistant button's popover).
/// With a key, a line under the card says what needs an assistant that
/// reads the code.
struct AssistantConnectedCard<Popover: View>: View {
    let status: AssistantStatus
    /// "Claude Code is connected", "Anthropic API is ready".
    let title: String
    let detail: String
    var tone: AssistantConnection.Tone?
    var actions: [AssistantConnection.Action] = []
    /// Suggest Everything…, or Generate Store Page Suggestions… with a key.
    var showsPrimary = true
    @Binding var isPopoverPresented: Bool
    let onPrimary: () -> Void
    let onDetails: () -> Void
    var onAction: (AssistantConnection.Action) -> Void = { _ in }
    var onAddAssistant: () -> Void = {}
    @ViewBuilder let popover: () -> Popover

    init(
        connection: AssistantConnection,
        isPopoverPresented: Binding<Bool>,
        onSuggestEverything: @escaping () -> Void,
        onDetails: @escaping () -> Void,
        onAction: @escaping (AssistantConnection.Action) -> Void,
        @ViewBuilder popover: @escaping () -> Popover
    ) {
        status = .connected(client: connection.clientName)
        title = connection.title
        detail = connection.detail()
        tone = connection.tone
        actions = connection.actions
        showsPrimary = connection.canSuggestEverything
        _isPopoverPresented = isPopoverPresented
        onPrimary = onSuggestEverything
        self.onDetails = onDetails
        self.onAction = onAction
        self.popover = popover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Card(padding: Spacing.medium + 2) {
                HStack(spacing: Spacing.medium) {
                    AssistantStatusDot(status: status, tone: tone)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.headline)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(title), \(detail)"))
                    .accessibilityIdentifier("overview.assistantConnected.summary")
                    if actions.contains(.reconnect) {
                        Button("Reconnect…") { onAction(.reconnect) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("overview.assistantConnected.reconnect")
                    }
                    if showsPrimary {
                        primaryButton
                    }
                    if actions.contains(.chooseFolder) {
                        Button("Choose Folder…") { onAction(.chooseFolder) }
                            .accessibilityIdentifier("overview.assistantConnected.chooseFolder")
                    }
                    Button("Details", action: onDetails)
                        .accessibilityIdentifier("overview.assistantConnected.details")
                }
                .controlSize(.small)
            }
            .accessibilityIdentifier("overview.assistantConnected")
            if status.isReady {
                HStack(spacing: Spacing.xSmall) {
                    Text("Age Rating, Accessibility, App Review and categories need an assistant that reads the code.")
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                    Button("Add One…", action: onAddAssistant)
                        .buttonStyle(.link)
                        .font(.caption)
                        .accessibilityIdentifier("overview.assistantConnected.addOne")
                }
                .padding(.horizontal, Spacing.medium)
                .accessibilityElement(children: .contain)
            }
        }
    }

    /// Prominent unless Reconnect… is what the card asks for first.
    @ViewBuilder
    private var primaryButton: some View {
        let title = status.isReady ? String(localized: "Generate Store Page Suggestions…") : String(localized: "Suggest Everything…")
        let button = Button(title, action: onPrimary)
        Group {
            if actions.contains(.reconnect) {
                button.buttonStyle(.bordered)
            } else {
                button.buttonStyle(.borderedProminent)
            }
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom, content: popover)
        .accessibilityIdentifier("overview.assistantConnected.ask")
    }
}

extension AssistantConnectedCard where Popover == EmptyView {
    /// With an API key: Generate Store Page Suggestions…, which opens on the
    /// Store Page.
    init(
        keyClient: String,
        summary: String,
        onGenerate: @escaping () -> Void,
        onDetails: @escaping () -> Void,
        onAddAssistant: @escaping () -> Void
    ) {
        status = .ready(client: keyClient)
        title = String(localized: "\(keyClient) is ready")
        detail = summary
        _isPopoverPresented = .constant(false)
        onPrimary = onGenerate
        self.onDetails = onDetails
        self.onAddAssistant = onAddAssistant
        popover = { EmptyView() }
    }
}
