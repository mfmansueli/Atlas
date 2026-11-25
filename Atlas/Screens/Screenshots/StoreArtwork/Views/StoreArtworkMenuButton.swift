//
//  StoreArtworkMenuButton.swift
//  Atlas
//

import SwiftUI

/// One button per artwork: Add ▾ (Add Header…, Make with Autopilot…) or
/// Edit ▾ (Replace…, Make a New One…, Delete…), each row saying what it
/// does. Autopilot's rows carry PRO on the Free plan and open the paywall
/// first.
struct StoreArtworkMenuButton: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let slot: StoreArtworkSlot
    let localeName: String

    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        Menu {
            ForEach(slot.menuItems) { item in
                if item.startsGroup { Divider() }
                Button(role: item.isDestructive ? .destructive : nil) {
                    perform(item)
                } label: {
                    Text(item.title)
                    Text(item.detail)
                }
                .badge(item.isPro && pro?.isFree == true ? Text(verbatim: "PRO") : nil)
                .accessibilityIdentifier("screenshots.artwork.\(slot.place.rawValue).menu.\(item.action)")
            }
        } label: {
            Text(slot.buttonTitle)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .fixedSize()
        .accessibilityLabel(Text("\(slot.buttonTitle) \(slot.place.title)", comment: "kind:label"))
        .accessibilityIdentifier("screenshots.artwork.\(slot.place.rawValue).menu")
    }

    private func perform(_ item: StoreArtworkMenuItem) {
        let action = { viewModel.perform(item.action, on: slot) }
        if item.isPro, let pro {
            pro.require(.autopilot, then: action)
        } else {
            action()
        }
    }
}
