//
//  TranslationFieldKind.swift
//  Atlas
//

import Foundation

/// What kind of text a suggestion is, for what its card says about the
/// translation (board 77): sentences get MEANS and Sounds, keywords MEANS
/// only (they aren't sentences), URLs and picked answers nothing.
enum TranslationFieldKind: Hashable, Sendable {
    case text
    case keywords
    case url
    /// A picked value: a category, an Age Rating answer, yes or no.
    case choice
}
