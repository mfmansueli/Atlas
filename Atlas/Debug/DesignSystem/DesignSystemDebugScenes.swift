//
//  DesignSystemDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of the design system:
///
/// - `ds-catalog`: the Design System Catalog (Debug → Design System
///   Catalog…, ⌥⌘D) as the main window.
enum DesignSystemDebugScenes {
    static let ids = ["ds-catalog"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "ds-catalog": AnyView(DesignSystemCatalogView())
        default: nil
        }
    }
}
#endif
