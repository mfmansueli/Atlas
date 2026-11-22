//
//  PairedClientRow.swift
//  Atlas
//

import SwiftUI

/// An assistant paired by hand (Advanced): its chip, whether it's
/// connected (with a dot that isn't the only cue: the text says it too),
/// the folder it works in, and Disconnect…, asked in place.
struct PairedClientRow: View {
    let client: MCPPairedClient
    let status: MCPPairedClientStatus
    let onDisconnect: () -> Void
    @State private var isAsking = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                AssistantChip(name: client.name, monogram: client.monogram)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xSmall) {
                        Circle()
                            .fill(status.isConnected ? Palette.positive : Palette.label3)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(status.text)
                            .font(.callout)
                    }
                    if let directory = client.workingDirectory {
                        Text(directory)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(Palette.label2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                Button("Disconnect…") { isAsking = true }
                    .controlSize(.small)
                    .disabled(isAsking)
                    .accessibilityLabel(Text("Disconnect \(client.name)…"))
                    .accessibilityIdentifier("settings.ai.revoke.\(client.kind.rawValue)")
            }
            if isAsking { ask }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.ai.client.\(client.kind.rawValue)")
    }

    private var ask: some View {
        HStack(spacing: Spacing.medium) {
            Text("\(client.name) stops suggesting and its token stops working. What it already suggested stays in Atlas.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel") { isAsking = false }
                .controlSize(.small)
            Button("Disconnect", role: .destructive) {
                isAsking = false
                onDisconnect()
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(Palette.dangerMark)
            .accessibilityIdentifier("settings.ai.revoke.\(client.kind.rawValue).confirm")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.dangerTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
    }
}
