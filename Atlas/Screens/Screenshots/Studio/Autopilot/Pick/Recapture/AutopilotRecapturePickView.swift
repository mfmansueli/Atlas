//
//  AutopilotRecapturePickView.swift
//  Atlas
//

import SwiftUI

/// Pick in a capture-only run: only the captures redone, each with the
/// one it had before and the new attempts. The new best is chosen; a click
/// keeps another, or the one before.
struct AutopilotRecapturePickView: View {
    @Bindable var studio: ScreenshotStudioModel
    let run: AutopilotRun

    static let thumbnailWidth: CGFloat = 92

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(run.recaptureTitle ?? String(localized: "Pick the captures"))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Only these captures change. The new ones are picked; click the one before to keep it.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: Spacing.medium, alignment: .topLeading)],
                    alignment: .leading, spacing: Spacing.medium
                ) {
                    ForEach(run.recapturePickTargets, id: \.key) { target in
                        card(target)
                    }
                }
            }
            .padding(Spacing.xLarge)
        }
        .accessibilityIdentifier("autopilot.recapturePick")
    }

    private func card(_ target: AutopilotCaptureTarget) -> some View {
        let chosen = run.finalCapture(for: target)?.id
        let previous = run.previousCapture(for: target)
        let new = run.captures(for: target).sorted { $0.score > $1.score }
        return VStack(alignment: .leading, spacing: Spacing.small) {
            Text(verbatim: "\(run.plan.screen(id: target.screenID)?.name ?? target.screenID) · \(target.locale) · \(target.displayType.shortTitle)")
                .font(.callout.weight(.medium))
                .lineLimit(1)
            HStack(alignment: .top, spacing: Spacing.small) {
                if let previous {
                    option(previous, label: String(localized: "Before"), isChosen: previous.id == chosen, target: target)
                }
                ForEach(new) { capture in
                    option(capture, label: String(localized: "New"), isChosen: capture.id == chosen, target: target)
                }
            }
        }
        .padding(Spacing.medium)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilot.recapturePick.\(target.key)")
    }

    private func option(_ capture: AutopilotCapture, label: String, isChosen: Bool, target: AutopilotCaptureTarget) -> some View {
        let width = Self.thumbnailWidth
        let height = width * CGFloat(capture.pixelSize.height) / CGFloat(max(capture.pixelSize.width, 1))
        return Button {
            studio.autopilot?.pickRecapture(capture.id, for: target, appID: studio.app.id)
        } label: {
            VStack(spacing: Spacing.xxSmall) {
                Group {
                    if let image = studio.image(for: capture, width: Int(width * 2)) {
                        Image(decorative: image, scale: 1).resizable().scaledToFill()
                    } else {
                        ImageLoadingTile(isLoading: true, systemImage: nil, fill: Palette.fill2, controlSize: .small)
                    }
                }
                .frame(width: width, height: min(height, width * 2.3))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(isChosen ? Palette.accent : Palette.separator, lineWidth: isChosen ? 2 : 0.5)
                }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(isChosen ? Palette.label : Palette.label3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
