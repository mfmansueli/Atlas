//
//  AssistantActivitySheet.swift
//  Atlas
//

import SwiftUI

/// Show Activity… in Settings → AI Assistants: every call an assistant
/// made, what it read, proposed or was refused, and why.
struct AssistantActivitySheet: View {
    @Environment(MCPServerController.self) private var server
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("What assistants asked for")
                    .font(.body.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !server.log.isEmpty {
                    Button("Clear", action: server.clearLog)
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("settings.ai.activity.done")
            }
            .padding(Spacing.large)
            Divider()
            if server.log.isEmpty {
                Text("Every call an assistant makes shows here: what it read, proposed, or was refused, and why.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .padding(Spacing.large)
                Spacer()
            } else {
                List(server.log) { entry in
                    AssistantLogRow(entry: entry)
                }
                .accessibilityIdentifier("settings.ai.log")
            }
        }
        .frame(width: 620, height: 460)
    }

    /// "2 calls were refused this week, each with its reason."
    static func summary(of log: [MCPLogEntry], now: Date = .now) -> String {
        let weekAgo = now.addingTimeInterval(-7 * 86400)
        let refused = log.filter { $0.outcome == .refused && $0.date > weekAgo }.count
        switch refused {
        case 0: return log.isEmpty ? String(localized: "Nothing yet.") : String(localized: "Nothing was refused this week.")
        case 1: return String(localized: "1 call was refused this week, with its reason.")
        default: return String(localized: "\(refused) calls were refused this week, each with its reason.")
        }
    }
}
