//
//  StatusSymbol.swift
//  Atlas
//

import SwiftUI

/// The five states every banner, check and row starts with (README —
/// Design system §13): the system's filled symbols in the state colours.
/// The values are `design-tokens.json → symbol.status`.
enum StatusSymbol: String, CaseIterable, Sendable {
    /// Done, passed, in use, sent.
    case done
    /// Needs an answer, a warning.
    case needsYou
    /// Failed, refused.
    case error
    /// Neutral information.
    case info
    /// No connection: edits wait on this Mac.
    case offline

    var symbol: String {
        switch self {
        case .done: "checkmark.circle.fill"
        case .needsYou: "exclamationmark.triangle.fill"
        case .error: "exclamationmark.circle.fill"
        case .info: "info.circle.fill"
        case .offline: "wifi.slash"
        }
    }

    var tint: SymbolTint {
        switch self {
        case .done: .systemGreen
        case .needsYou: .systemOrange
        case .error: .systemRed
        case .info: .systemGray
        case .offline: .secondary
        }
    }

    var color: Color { tint.color }

    /// The symbol in its colour.
    var image: some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
    }
}
