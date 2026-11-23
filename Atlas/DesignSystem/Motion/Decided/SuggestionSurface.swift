//
//  SuggestionSurface.swift
//  Atlas
//

import SwiftUI

/// The surface of a suggestion card (README — Design system §1 and §7): the
/// AI tint and its edge; landing while the person looks it arrives (effect
/// 3, `aiArrived`); decided it moves as effect 4 says (`aiDecided`):
/// accepted, the tint goes to the neutral card and a check draws. A
/// suggestion without a date (a built-in check, one read from disk) only
/// settles.
struct SuggestionSurface: ViewModifier {
    let isSettling: Bool
    /// What the card shows, so a new suggestion in its place arrives again.
    let arrivalKey: String
    let arrivedAt: Date?
    var cornerRadius: CGFloat = Radius.banner
    var checkAlignment: Alignment = .topTrailing

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(isSettling ? Palette.raised : Palette.aiSurface, in: shape)
            .overlay(shape.strokeBorder(edge, lineWidth: isSettling ? 0.5 : 1))
            .aiArrived(key: arrivalKey, arrivedAt: arrivedAt)
            .aiDecided(isSettling: isSettling, checkAlignment: checkAlignment)
    }

    private var edge: Color {
        isSettling ? Palette.separator : Palette.aiMark.opacity(contrast == .increased ? 0.8 : 0.35)
    }
}

extension View {
    /// A suggestion card's tint, edge, arrival and decision; see
    /// `SuggestionSurface`.
    func suggestionSurface(
        isSettling: Bool,
        arrivalKey: String,
        arrivedAt: Date?,
        cornerRadius: CGFloat = Radius.banner,
        checkAlignment: Alignment = .topTrailing
    ) -> some View {
        modifier(SuggestionSurface(
            isSettling: isSettling,
            arrivalKey: arrivalKey,
            arrivedAt: arrivedAt,
            cornerRadius: cornerRadius,
            checkAlignment: checkAlignment
        ))
    }
}
