//
//  BackgroundDestination.swift
//  Atlas
//

import Foundation

/// Where a "Needs you" line in the menu bar's menu opens Atlas.
enum BackgroundDestination: Hashable, Sendable {
    /// A section of one app's workspace.
    case section(AppWorkspaceSection, appID: StoreApp.ID)
    /// The app's version card on its Overview (approved, release it).
    case version(appID: StoreApp.ID)
    /// A section of the app the main window shows (Atlas Help's Show Me,
    /// Settings' Open in Analytics).
    case currentSection(AppWorkspaceSection)
    /// Review & Push, for every app.
    case reviewPush
    /// An In-App Event's artwork sheet, where its run is.
    case eventArtwork(appID: StoreApp.ID, eventID: InAppEvent.ID)
}
