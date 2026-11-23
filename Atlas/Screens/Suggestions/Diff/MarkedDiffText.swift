//
//  MarkedDiffText.swift
//  Atlas
//

import SwiftUI

/// One side of a revision with the changed words marked: Now with the
/// words it takes out struck through, Suggested with the ones it puts in
/// in the suggestion's purple, bold, on its tint.
struct MarkedDiffText: View {
    enum Side: Hashable {
        case now
        case suggested
    }

    let diff: TextWordDiff
    let side: Side

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for segment in diff.segments {
            switch (segment, side) {
            case let (.same(text), _):
                result += AttributedString(text)
            case let (.removed(text), .now):
                var part = AttributedString(text)
                part.strikethroughStyle = .single
                part.foregroundColor = Palette.err
                result += part
            case let (.added(text), .suggested):
                var part = AttributedString(text)
                part.foregroundColor = Palette.ai
                part.backgroundColor = Palette.aiMark.opacity(0.18)
                part.inlinePresentationIntent = .stronglyEmphasized
                result += part
            case (.removed, .suggested), (.added, .now):
                break
            }
        }
        return result
    }
}
