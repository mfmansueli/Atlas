//
//  ConnectStepMark.swift
//  Atlas
//

import SwiftUI

/// A step's round mark in Connect's sheet: its number, filled in the
/// accent while it's the step now, and a green check once it's done.
struct ConnectStepMark: View {
    enum Phase: Hashable {
        case later
        case now
        case done
    }

    let number: Int
    let state: Phase
    var size: CGFloat = 18

    var body: some View {
        Group {
            if state == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Palette.done)
            } else {
                Text(verbatim: "\(number)")
                    .font(.system(size: size * 0.58, weight: .bold))
                    .foregroundStyle(state == .now ? Color.white : Palette.label2)
            }
        }
        .frame(width: size, height: size)
        .background(background, in: Circle())
        .accessibilityHidden(true)
    }

    private var background: Color {
        switch state {
        case .later: Palette.fill3
        case .now: Palette.accent
        case .done: Palette.positive.opacity(0.16)
        }
    }

    static func state(of index: Int, current: Int) -> Phase {
        index < current ? .done : index == current ? .now : .later
    }
}
