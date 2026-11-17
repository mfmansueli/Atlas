//
//  SectionMenuButton.swift
//  Atlas
//

import SwiftUI

/// The toolbar's section button while the sidebar is hidden: the current
/// section's tile and name, opening the same groups and counts as the
/// sidebar.
struct SectionMenuButton: View {
    let counts: SectionBadgeCounts
    @Binding var selection: AppWorkspaceSection
    /// Opens the menu right away (a DEBUG scene).
    var startsOpen = false

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 7) {
                SectionIconTile(section: selection, size: 20)
                Text(selection.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.label2)
            }
            .padding(.horizontal, 2)
        }
        .help("Sections")
        .accessibilityLabel(Text("Section: \(selection.title)"))
        .accessibilityIdentifier("workspace.sectionMenu")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) { menu }
        .task {
            if startsOpen { isPresented = true }
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(AppWorkspaceSectionGroup.allCases) { group in
                if let title = group.title {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.label2)
                        .padding(.horizontal, Spacing.small)
                        .padding(.top, Spacing.small)
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(group.sections) { section in
                    Button {
                        selection = section
                        isPresented = false
                    } label: {
                        SidebarSectionRow(section: section, counts: counts, isSelected: section == selection)
                            .padding(.horizontal, Spacing.xSmall)
                            .frame(height: 30)
                            .background(section == selection ? Palette.fill3 : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workspace.sectionMenu.item.\(section.rawValue)")
                }
            }
        }
        .padding(Spacing.small)
        .frame(width: 250)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.sectionMenu.list")
    }
}
