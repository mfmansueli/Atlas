//
//  AssistantsDesignSection.swift
//  Atlas
//

import SwiftUI

/// Settings → AI Assistants → Claude: each app's design project,
/// which Claude draws screenshots, headers and event artwork from.
/// Change… and Connect… open the app's Screenshots, where it's connected.
struct AssistantsDesignSection: View {
    @Environment(BackgroundWork.self) private var background: BackgroundWork?
    var autopilot = AutopilotCenter.shared

    var body: some View {
        if let apps = background?.library, !apps.isEmpty {
            Section {
                ForEach(apps) { app in
                    row(app)
                }
            } header: {
                Text("Claude")
            } footer: {
                Text("Claude draws screenshots, headers and event artwork in each app’s own brand.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
        }
    }

    private func row(_ app: StoreApp) -> some View {
        let project = autopilot.designProject(for: app.id)
        return LabeledContent {
            Button(project == nil ? "Connect…" : "Change…") {
                AtlasLifecycle.shared.open(.section(.screenshots, appID: app.id))
            }
            .accessibilityIdentifier("settings.ai.design.\(app.id)")
        } label: {
            SettingsRowLabel(
                title: LocalizedStringKey(app.name),
                caption: project.map { String(localized: "Design project “\($0.displayName)”") }
                    ?? String(localized: "Not connected. Artwork uses Atlas’s templates.")
            )
        }
    }
}
