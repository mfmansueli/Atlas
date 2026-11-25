//
//  ToastShownPreferenceKey.swift
//  Atlas
//

import SwiftUI

/// A section's own toast is on screen: the workspace lifts the chat in the
/// corner above it, as it does for its own toast. Set by `ActionToast` and
/// `AppInformationToast`.
struct ToastShownPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
