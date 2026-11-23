//
//  RetentionServerBox.swift
//  Atlas
//

import SwiftUI

/// Advanced, folded: real-time messages from the developer's server with
/// Apple's Retention Messaging API. Atlas explains it, links to
/// Apple's access request and hands the setup to Claude Code.
struct RetentionServerBox: View {
    let model: RetentionModel

    static let requestAccessURL = URL(string: "https://developer.apple.com/contact/request/retention-messaging-api/")

    var body: some View {
        @Bindable var model = model
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.snappy) { model.isAdvancedExpanded.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Real-time from your server")
                                .font(.body.weight(.medium))
                            Text("Advanced · not set up")
                                .font(.subheadline)
                                .foregroundStyle(Palette.label2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.label3)
                            .rotationEffect(.degrees(model.isAdvancedExpanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding(Spacing.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(model.isAdvancedExpanded ? Text("Expanded") : Text("Collapsed"))
                .accessibilityIdentifier("retention.server.toggle")
                if model.isAdvancedExpanded { details }
            }
        }
        .accessibilityIdentifier("retention.server")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("""
            Your server picks each subscriber’s message at Cancel, and can suggest another plan or sign a promotional offer. Past 700 ms, \
            Apple shows these messages.
            """)
            Text("Needs access from Apple and a sandbox performance test before going live. Uses the Retention Messaging API, not your App Store Connect key.")
            HStack(spacing: Spacing.small) {
                if let url = Self.requestAccessURL {
                    Link(destination: url) {
                        Text("Request Access \(Image(systemName: "arrow.up.right"))")
                    }
                    .accessibilityIdentifier("retention.server.requestAccess")
                }
            }
            RetentionServerSetupButton(app: model.app)
        }
        .font(.callout)
        .foregroundStyle(Palette.label2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.medium)
        .padding(.bottom, Spacing.medium)
    }
}
