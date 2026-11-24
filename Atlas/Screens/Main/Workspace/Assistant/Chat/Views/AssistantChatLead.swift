//
//  AssistantChatLead.swift
//  Atlas
//

import SwiftUI

/// The mark at the start of the closed chat's line: purple sparkles to
/// ask, the spark while the assistant works (effect 2, which blooms when
/// it ends), a still purple dot for what arrived, amber for a failure
/// (effect 5's slide), blue for a push, or the grey Draft tag.
struct AssistantChatLead: View {
    let lead: AssistantChatPillLine.Lead

    var body: some View {
        switch lead {
        case .sparkles:
            mark { Image(systemName: "sparkles").foregroundStyle(Palette.ai) }
        case .dot(.working):
            mark { Color.clear }.aiWorking(true, alignment: .center)
        case .dot(.arrived):
            mark { AssistantWorkingDot() }
        case .dot(.failure):
            mark { dot(Palette.warnMark) }.aiFailureArrival(key: "chat.failure")
        case .dot(.push):
            mark { dot(Palette.accent) }
        case .draft:
            Pill(text: String(localized: "Draft", comment: "kind:pill · the chat kept what you were writing"))
        }
    }

    private func mark(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
            .accessibilityHidden(true)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: Spacing.small, height: Spacing.small)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        AssistantChatLead(lead: .sparkles)
        AssistantChatLead(lead: .dot(.working))
        AssistantChatLead(lead: .dot(.arrived))
        AssistantChatLead(lead: .dot(.failure))
        AssistantChatLead(lead: .dot(.push))
        AssistantChatLead(lead: .draft)
    }
    .padding()
}
