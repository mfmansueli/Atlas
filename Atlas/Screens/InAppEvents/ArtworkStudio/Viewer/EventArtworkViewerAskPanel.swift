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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: Binding { flow.viewer?.request ?? "" } set: { flow.viewer?.request = $0 })
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .padding(6)
                .frame(height: 72)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .focused($isFocused)
                .accessibilityIdentifier("events.art.request")
            HStack(spacing: 6) {
                ForEach(EventArtworkFlow.changeChips, id: \.self) { chip in
                    Button {
                        flow.useChip(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 12))
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
                .font(.system(size: 11))
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
        .background(EventArtworkViewerStyle.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(EventArtworkViewerStyle.hairline(contrast), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        .onAppear { isFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.askPanel")
    }
}
