//
//  AssistantFolderDropArea.swift
//  Atlas
//

import SwiftUI

/// Step 1's large area: a folder from Finder, or the project from the
/// title of Xcode's window, dropped on it; clicking it (or Choose Folder…)
/// opens the Open panel. While something is dragged over, the whole area
/// lights up and says what dropping does (`set-wiz-drag`).
struct AssistantFolderDropArea: View {
    let model: AssistantConnectModel

    var body: some View {
        VStack(spacing: Spacing.xxSmall) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 22))
                .foregroundStyle(Palette.accentText)
                .frame(width: 44, height: 44)
                .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, Spacing.xxSmall)
                .accessibilityHidden(true)
            Text(model.isDragOver ? "Drop to use this folder" : "Drag the project folder here")
                .font(.callout.weight(.semibold))
            if !model.isDragOver {
                Text("from Finder, or from the title of the Xcode window")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Button("Choose Folder…", action: model.chooseFolder)
                    .controlSize(.small)
                    .padding(.top, Spacing.xxSmall)
                    .accessibilityIdentifier("settings.connect.chooseFolder")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(Spacing.large)
        .background(model.isDragOver ? Palette.accentTint : Palette.fill1, in: shape)
        .overlay {
            shape.strokeBorder(
                model.isDragOver ? Palette.accent : Palette.separator2,
                style: StrokeStyle(lineWidth: 1.5, dash: model.isDragOver ? [] : [5, 4])
            )
        }
        .contentShape(shape)
        .onTapGesture(perform: model.chooseFolder)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: \.isFileURL) else { return false }
            model.use(url)
            return true
        } isTargeted: { isTargeted in
            model.isDragOver = isTargeted
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Drop the project folder here, or choose it"))
        .accessibilityIdentifier(model.isDragOver ? "settings.connect.drop.over" : "settings.connect.drop")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }
}
