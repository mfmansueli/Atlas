//
//  NominationsEmptyState.swift
//  Atlas
//

import SwiftUI

/// No nominations yet: what one is, when it's worth it, what Apple says
/// back (nothing), New Nomination… and Ask Claude Code….
struct NominationsEmptyState: View {
    let canCreate: Bool
    let onNew: () -> Void
    let onAsk: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No nominations yet", systemImage: AppWorkspaceSection.nominations.systemImage)
        } description: {
            VStack(spacing: Spacing.small) {
                Text("A nomination tells Apple’s editors about a launch, big update or event, weeks ahead.")
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    line(String(localized: "Worth it for:", comment: "kind:field-label"),
                         String(localized: "a new app, a version with real new features, or an In-App Event.", comment: "kind:description"))
                    line(String(localized: "When:", comment: "kind:field-label"),
                         String(localized: "a few weeks before it starts; up to 3 months for a launch.", comment: "kind:description"))
                    line(String(localized: "What Apple tells you:", comment: "kind:field-label"),
                         String(localized: "nothing after you submit. Nominating is no promise of featuring.", comment: "kind:description"))
                }
                .font(.callout)
                .frame(maxWidth: 460, alignment: .leading)
            }
        } actions: {
            HStack(spacing: Spacing.small) {
                Button("New Nomination…", action: onNew)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate)
                    .accessibilityIdentifier("nominations.empty.new")
                Button(action: onAsk) {
                    Label("Ask Claude Code…", systemImage: "sparkles")
                        .foregroundStyle(Palette.ai)
                }
                .accessibilityIdentifier("nominations.empty.ask")
            }
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nominations.empty")
    }

    private func line(_ label: String, _ text: String) -> some View {
        Text("\(Text(label).fontWeight(.semibold)) \(text)")
            .foregroundStyle(Palette.label2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
