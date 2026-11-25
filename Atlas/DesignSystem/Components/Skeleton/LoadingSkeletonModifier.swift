//
//  LoadingSkeletonModifier.swift
//  Atlas
//

import SwiftUI

/// Makes a skeleton one VoiceOver element that reads "Loading <what>"
/// once, not once per grey block, and lets clicks through: nothing on a
/// skeleton can be pressed.
struct LoadingSkeletonModifier: ViewModifier {
    let label: String
    let identifier: String

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityIdentifier(identifier)
    }
}

extension View {
    /// The skeleton reads `message.spoken` to VoiceOver and is found by
    /// `identifier` in UI tests.
    func loadingSkeleton(_ message: LoadingMessage, identifier: String) -> some View {
        modifier(LoadingSkeletonModifier(label: message.spoken, identifier: identifier))
    }
}
