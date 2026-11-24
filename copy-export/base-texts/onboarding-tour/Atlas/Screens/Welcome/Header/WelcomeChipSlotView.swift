//
//  WelcomeChipSlotView.swift
//  Atlas
//

import SwiftUI

/// One place round the globe at `time`: the chip that's showing there,
/// rising in or lifting away. Still, it's the place's first chip.
struct WelcomeChipSlotView: View {
    let slot: WelcomeChipSlot
    let time: TimeInterval
    var pace: Double = 1
    var isStill = false

    var body: some View {
        ZStack {
            ForEach(Array(slot.chips.enumerated()), id: \.offset) { index, chip in
                chipView(chip, appearance: appearance(of: chip, index: index))
            }
        }
    }

    private func appearance(of chip: WelcomeChip, index: Int) -> WelcomeChip.Appearance {
        guard !isStill else { return WelcomeChip.Appearance(opacity: index == 0 ? 1 : 0, offset: 0, scale: 1) }
        return chip.appearance(at: time, pace: pace)
    }

    @ViewBuilder
    private func chipView(_ chip: WelcomeChip, appearance: WelcomeChip.Appearance) -> some View {
        if appearance.opacity > 0 {
            WelcomeChipView(chip: chip)
                .scaleEffect(appearance.scale)
                .offset(y: appearance.offset)
                .opacity(appearance.opacity)
        }
    }
}
