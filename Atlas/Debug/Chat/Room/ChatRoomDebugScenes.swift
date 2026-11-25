//
//  ChatRoomDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Every section in the main window with the chat's pill in the corner
/// (board 69), to check that each page's last content, or its bar, scrolls
/// up above the pill: `room-<section>`, e.g. `room-storePage`,
/// `room-appInformation`. Analytics, Reviews and In-App Events open as
/// their navigation scenes do (`nav-an`, `nav-rv`, `nav-ev`), with
/// their sample data. Scroll to the bottom, or make the window short.
enum ChatRoomDebugScenes {
    static let ids = AppWorkspaceSection.allCases.map { "room-\($0.rawValue)" }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard id.hasPrefix("room-"), let section = AppWorkspaceSection(rawValue: String(id.dropFirst("room-".count))) else { return nil }
        switch section {
        case .analytics: return NavigationDebugScenes.view(for: "nav-an")
        case .reviews: return NavigationDebugScenes.view(for: "nav-rv")
        case .inAppEvents: return NavigationDebugScenes.view(for: "nav-ev")
        default: return AnyView(DebugMainScene(section: section))
        }
    }
}
#endif
