//
//  WorkspaceToolbarTitle.swift
//  Atlas
//

import SwiftUI

/// The app's name over its version's status ("Version 1.4 · Not submitted
/// yet"), in the toolbar while the sidebar is hidden.
struct WorkspaceToolbarTitle: View {
    let name: String
    /// The version's line, or the bundle ID before it's known.
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
        .lineLimit(1)
        .frame(maxWidth: WorkspaceToolbarLayout.maxTitleWidth, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workspace.title")
    }
}

#Preview {
    WorkspaceToolbarTitle(name: "Lumen Journal", subtitle: "Version 1.4 · Not submitted yet")
        .padding()
}
