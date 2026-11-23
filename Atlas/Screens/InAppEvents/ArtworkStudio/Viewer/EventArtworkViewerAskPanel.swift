//
//  EventArtworkViewerAskPanel.swift
//  Atlas
//

import SwiftUI

/// Ask for Changes in the viewer (board 47), a floating panel rather than
/// a sheet: what should change in the concept, three starts, and Send to
/// Claude, which redraws only this pair in place.
struct EventArtworkViewerAskPanel: View {
    @Bindable var flow: EventArtworkFlow
    let name: String

    @FocusState private var isFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What should change in “\(name)”?")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: Binding { flow.viewer?.request ?? "" } set: { flow.viewer?.request = $0 })
                .font(.body)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .padding(6)
                .frame(height: 72)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .focused($isFocused)
                .accessibilityIdentifier("events.art.request")
            HStack(spacing: 6) {
                ForEach(EventArtworkFlow.changeChips, id: \.self) { chip in
                    Button {
                        flow.useChip(chip)
                    } label: {
                        Text(chip)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(.white.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Only this pair is redrawn. You can keep working while Claude draws it.")
                .font(.subheadline)
                .foregroundStyle(EventArtworkViewerStyle.secondary(contrast))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.small) {
                Spacer(minLength: 0)
                EventArtworkViewerButton(
                    title: String(localized: "Cancel"), label: String(localized: "Cancel"), help: String(localized: "Cancel  esc"),
                    identifier: "events.art.askCancel"
                ) {
                    flow.closeAsk()
                }
                EventArtworkViewerButton(
                    title: String(localized: "Send to Claude"), isProminent: true, label: String(localized: "Send to Claude"),
                    help: String(localized: "Claude redraws this pair the way you asked"), identifier: "events.art.send"
                ) {
                    Task { await flow.sendViewerChanges() }
                }
                .disabled((flow.viewer?.request ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(EventArtworkViewerStyle.panel, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.popover, style: .continuous).strokeBorder(EventArtworkViewerStyle.hairline(contrast), lineWidth: 0.5))
        .depth(.popover)
        .onAppear { isFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.askPanel")
    }
}
