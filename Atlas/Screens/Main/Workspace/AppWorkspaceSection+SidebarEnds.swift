//
//  AppWorkspaceSection+SidebarEnds.swift
//  Atlas
//

extension AppWorkspaceSection {
    /// The sidebar's first section, at the top of its first group.
    static var sidebarFirst: AppWorkspaceSection? {
        AppWorkspaceSectionGroup.allCases.first { !$0.sections.isEmpty }?.sections.first
    }

    /// The sidebar's last section, at the bottom of its last group.
    static var sidebarLast: AppWorkspaceSection? {
        AppWorkspaceSectionGroup.allCases.last { !$0.sections.isEmpty }?.sections.last
    }
}
