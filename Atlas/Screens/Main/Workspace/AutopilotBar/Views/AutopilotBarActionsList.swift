//
//  AutopilotBarActionsList.swift
//  Atlas
//

import SwiftUI

/// What Autopilot can do here, at the top of the open bar (board 80):
/// “For Store Page”, every one of the section's actions, then Everything
/// for the app. Once there's a conversation it folds into one line with
/// Show N, so the conversation has the room.
struct AutopilotBarActionsList: View {
    let sectionTitle: String
    let actions: AutopilotBarActions
    @Binding var isFolded: Bool
    /// Fold it only once the person has something to read.
    let canFold: Bool
    let onAction: (WorkspaceAutopilotItem) -> Void
    let onEverything: () -> Void

    private var count: Int {
        actions.items.count + (actions.everythingTitle == nil ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack {
                Text("For \(sectionTitle)", comment: "kind:title · the open Autopilot bar's actions, over their list")
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.label2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if canFold {
                    Button(isFolded ? String(localized: "Show \(count)", comment: "kind:button · shows the Autopilot actions") : String(localized: "Hide", comment: "kind:button")) {
                        isFolded.toggle()
                    }
                    .plainButton()
                    .accessibilityIdentifier("autopilotBar.actions.fold")
                }
            }
            .padding(.horizontal, Spacing.small)
            if !(canFold && isFolded) {
                ForEach(actions.items) { item in
                    AutopilotBarActionRow(
                        systemImage: item.action.systemImage, title: item.title, subtitle: item.action.subtitle, note: item.note,
                        isPro: item.isPro, isEnabled: item.isEnabled
                    ) {
                        onAction(item)
                    }
                }
                if let everything = actions.everythingTitle {
                    AutopilotBarActionRow(
                        systemImage: "sparkles", title: everything,
                        subtitle: String(localized: "Suggest Everything, in every section", comment: "kind:description · an Autopilot action")
                    ) {
                        onEverything()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilotBar.actions")
    }
}
