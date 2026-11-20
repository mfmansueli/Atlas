//
//  PageShotsStepsView.swift
//  Atlas
//

import SwiftUI

/// Plan, Making, Result: done steps checked, the current one in bold.
struct PageShotsStepsView: View {
    let current: PageShotsStep

    var body: some View {
        HStack(spacing: Spacing.medium) {
            ForEach(PageShotsStep.allCases) { step in
                HStack(spacing: Spacing.xSmall) {
                    ZStack {
                        Circle().fill(step.rawValue > current.rawValue ? Palette.fill2 : Palette.accent)
                            .frame(width: 20, height: 20)
                        if step.rawValue < current.rawValue {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        } else {
                            Text("\(step.rawValue + 1)").font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(step.rawValue > current.rawValue ? Palette.label2 : Color.white)
                    .accessibilityHidden(true)
                    Text(step.title)
                        .font(.caption.weight(step == current ? .semibold : .regular))
                        .foregroundStyle(step.rawValue > current.rawValue ? Palette.label2 : Palette.label)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label(step)))
                .accessibilityAddTraits(step == current ? .isSelected : [])
                .accessibilityIdentifier("pages.shots.step.\(step.rawValue + 1)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Steps"))
    }

    private func label(_ step: PageShotsStep) -> String {
        let state = step.rawValue < current.rawValue
            ? String(localized: "done") : step == current ? String(localized: "current") : String(localized: "to come")
        return String(localized: "Step \(step.rawValue + 1), \(step.title), \(state)")
    }
}
