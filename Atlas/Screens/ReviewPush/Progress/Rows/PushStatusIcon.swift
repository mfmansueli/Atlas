//
//  PushStatusIcon.swift
//  Atlas
//

import SwiftUI

/// A push row's state at its start: waiting ○, sending (spinner), done ✓,
/// failed (red), changed in App Store Connect meanwhile (a warning), or
/// not sent.
struct PushStatusIcon: View {
    let state: PushProgressState
    /// A change App Store Connect has a different value for now.
    var isConflict = false

    var body: some View {
        Group {
            if isConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.warn)
            } else {
                switch state {
                case .waiting:
                    Image(systemName: "circle")
                        .foregroundStyle(Palette.label3)
                case .sending:
                    ProgressView()
                        .controlSize(.mini)
                case .done:
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.label2)
                case .failed:
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(Palette.err)
                case .notSent:
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Palette.label3)
                }
            }
        }
        .frame(width: 18)
        .accessibilityHidden(true)
    }
}
