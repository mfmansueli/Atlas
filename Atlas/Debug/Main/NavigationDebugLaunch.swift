//
//  NavigationDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a navigation DEBUG scene opens with: the app menu showing, the
/// sidebar hidden with the toolbar's section menu showing, or one of the
/// tour's tips.
enum NavigationDebugLaunch {
    @MainActor static var opensAppMenu = false
    @MainActor static var hidesSidebar = false
    @MainActor static var opensSectionMenu = false
    /// The tour's tip the window shows once it's up.
    @MainActor static var tourStep: TourStep?
    /// The tour starts as on a first run (in memory, never shown before).
    @MainActor static var startsTourOnFirstRun = false
}
#endif
