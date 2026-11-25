//
//  AutopilotBarClosedField.swift
//  Atlas
//

import SwiftUI

/// The closed Autopilot bar's one line (board 80): the ✦ and “Ask or tell
/// Autopilot…”, which open the conversation (so does ⌘J), the section's
/// first two actions as buttons, More with the rest, and ⌘J. Where it's
/// narrow, the second button folds into More, then the first; the words
/// keep at least `Metrics.autopilotBarPlaceholderWidth`.
struct AutopilotBarClosedField<More: View>: View {
    let actions: AutopilotBarActions
    /// Where a request's spark lands (effect 1, Trail).
    let anchor: AskAnchor
    /// “Store Page”, for More's VoiceOver label.
    let sectionTitle: String
    let onOpen: () -> Void
    let onAction: (WorkspaceAutopilotItem) -> Void
    /// More's menu when `fitting` buttons show beside the field.
    @ViewBuilder let more: (_ fitting: Int) -> More

    var body: some View {
        HStack(spacing: Spacing.small) {
            Button(action: onOpen) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Palette.ai)
                    .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                    .background(AskAnchorView(anchor: anchor))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                row(fitting: 2)
                row(fitting: 1)
                row(fitting: 0)
            }
            Button(action: onOpen) {
                HStack(spacing: Spacing.xSmall) {
                    AssistantChatShortcutHint()
                    Image(systemName: "chevron.up")
                        .imageScale(.small)
                        .foregroundStyle(Palette.label2)
                        .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text("Open (⌘J)", comment: "kind:tooltip · opens the Autopilot bar"))
            .accessibilityHidden(true)
        }
        .padding(.leading, Spacing.medium)
        .padding(.trailing, Spacing.small)
        .frame(minHeight: Metrics.autopilotBarFieldHeight)
    }

    private func row(fitting room: Int) -> some View {
        HStack(spacing: Spacing.xSmall) {
            Button(action: onOpen) {
                Text("Ask or tell Autopilot…", comment: "kind:placeholder · the Autopilot bar's field")
                    .atlasTextStyle(.body)
                    .foregroundStyle(Palette.label3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(
                        minWidth: Metrics.autopilotBarPlaceholderWidth, idealWidth: Metrics.autopilotBarPlaceholderWidth,
                        maxWidth: .infinity, alignment: .leading
                    )
                    .frame(minHeight: Metrics.autopilotBarFieldHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Ask or tell Autopilot", comment: "kind:accessibility · the Autopilot bar's field"))
            .accessibilityHint(Text("Opens the conversation", comment: "kind:accessibility"))
            .accessibilityIdentifier("autopilotBar.field")
            ForEach(actions.buttons(fitting: room)) { item in
                AutopilotBarActionButton(item: item) { onAction(item) }
            }
            Menu {
                more(room)
            } label: {
                Text("More", comment: "kind:button · the Autopilot bar's other actions")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text("Everything Autopilot can do in \(sectionTitle)", comment: "kind:accessibility · the Autopilot bar's More"))
            .accessibilityIdentifier("autopilotBar.more")
        }
    }
}
