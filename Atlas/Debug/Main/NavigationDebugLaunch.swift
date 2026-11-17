//
//  NavigationDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a navigation DEBUG scene opens with: the app menu showing, or the
/// sidebar hidden with the toolbar's section menu showing.
enum NavigationDebugLaunch {
    @MainActor static var opensAppMenu = false
    @MainActor static var hidesSidebar = false
    @MainActor static var opensSectionMenu = false
}
#endif
