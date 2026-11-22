//
//  AssistantConnectFolderStep.swift
//  Atlas
//

import SwiftUI

/// Step 1, "Project folder" (`set-wiz-folder`, `-drag`, `-wrong`,
/// `-picked`): where the app's project is. Before a folder: the drop
/// area, what was wrong with the last one, and the folder Atlas found.
/// After: the folder with Change…, and Atlas's three checks.
struct AssistantConnectFolderStep: View {
    let model: AssistantConnectModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AssistantConnectStepTitle(title: String(localized: "Where is \(model.appName)’s project?"), detail: detail)
            if let verdict = model.verdict, verdict.isAccepted {
                accepted(verdict)
            } else {
                AssistantFolderDropArea(model: model)
                if let wrong = model.wrongFolderText {
                    Banner(kind: .warning, title: wrong.title, message: wrong.detail, isInline: true)
                        .padding(.horizontal, -Spacing.large)
                        .padding(.vertical, -Spacing.small)
                        .accessibilityIdentifier("settings.connect.wrongFolder")
                }
                if let suggestion = model.suggestion, !model.isDragOver {
                    AssistantFolderRow(
                        title: Text("\(Text(suggestion.folderName).fontWeight(.semibold)) · found on this Mac"),
                        path: suggestion.folder,
                        detail: suggestion.detail
                    ) {
                        Button("Use This Folder", action: model.useSuggestion)
                            .accessibilityIdentifier("settings.connect.useSuggestion")
                    }
                    .accessibilityIdentifier("settings.connect.suggestion")
                }
            }
            Text("Your other apps can get their folders later, in Settings → AI Assistants.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }

    private var detail: String {
        let name = model.assistant.title
        return model.assistant == .claudeCode
            ? String(localized: """
            The folder on this Mac with the app’s code, the one you open in Xcode. \(name) reads it so its suggestions match \
            what the app really does. It never changes your files.
            """)
            : String(localized: """
            The folder on this Mac with the app’s code, the one you open in Xcode. \(name) opens it so its suggestions match \
            what the app really does.
            """)
    }

    private func accepted(_ verdict: ProjectFolderVerdict) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            AssistantFolderRow(title: Text(verdict.folderName).fontWeight(.semibold), path: verdict.folder) {
                Button("Change…", action: model.changeFolder)
                    .accessibilityIdentifier("settings.connect.changeFolder")
            }
            .accessibilityIdentifier("settings.connect.folder")
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                ForEach(model.folderChecks, id: \.self) { check in
                    Label {
                        Text(check)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        ConnectStepMark(number: 0, state: .done, size: 16)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Spacing.xxSmall)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.connect.checks")
        }
    }
}
