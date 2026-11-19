//
//  StorePageSheet.swift
//  Atlas
//

import Foundation

/// The sheets the Store Page opens over its content.
enum StorePageSheet: String, Identifiable, Hashable, Sendable {
    /// "Translate missing fields".
    case translate
    /// "Find and replace across locales" (⌥⌘F).
    case findReplace
    /// "Import translations": the diff of a chosen file.
    case importPreview
    /// "Languages in the app, not on the App Store".
    case newLanguages
    /// "Accept Store Page suggestions in every language".
    case acceptAll
    /// "New Version": a version to create in App Store Connect.
    case newVersion

    var id: String { rawValue }
}
