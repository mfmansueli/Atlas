//
//  AssetLibraryCleanupSuggestion.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to delete files from an app's App Asset
/// Library that no page shows (`propose_asset_library_cleanup`). The
/// Asset Library sheet opens with them picked; only the person deletes,
/// after its confirmation.
struct AssetLibraryCleanupSuggestion: Identifiable, Hashable, Sendable {
    var id = UUID()
    var appID: StoreApp.ID
    var fileIDs: [AssetLibraryFile.ID]
    /// Why, at most 110 characters.
    var why: String
    /// e.g. "Claude Code".
    var client: String
    /// How sure the assistant is, and details on demand.
    var layers: SuggestionLayers?
    var receivedAt = Date.now
}
