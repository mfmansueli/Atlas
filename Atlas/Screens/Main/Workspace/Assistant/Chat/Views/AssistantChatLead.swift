//
//  AssistantChatLead.swift
//  Atlas
//

import SwiftUI

/// The mark at the start of the closed chat's line: the purple ✦ to ask
/// or while the assistant waits for you, the ✦ breathing while the answer
/// is sent and worked on (effect 2), the ✦ blooming once when it arrives
/// (effect 3), the amber warning for a failure, the push symbol in blue
/// for a push (not AI), or the grey Draft tag.
struct AssistantChatLead: View {
    let lead: AssistantChatPillLine.Lead
    var arrival: AssistantChatPillLine.Arrival?

    var body: some View {
        switch lead {
        case .sparkles:
            mark { sparkles }
        case .breathing:
            mark { sparkles.aiBreathing(true) }
        case .arrived:
            mark { sparkles.aiSparkBloom(key: arrival.map { "\($0.key).bloom" }, arrivedAt: arrival?.arrivedAt) }
                .id(arrival?.key)
        case .failure:
            mark { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warnMark) }
        case .push:
            mark { Image(systemName: "arrow.up.circle").foregroundStyle(Palette.accent) }
        case .draft:
            Pill(text: String(localized: "Draft", comment: "kind:pill · the chat kept what you were writing"))
        }
    }

    private var sparkles: some View {
        Image(systemName: "sparkles").foregroundStyle(Palette.ai)
    }

    private func mark(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        AssistantChatLead(lead: .sparkles)
        AssistantChatLead(lead: .breathing)
        AssistantChatLead(lead: .arrived, arrival: .init(key: "preview", arrivedAt: .now))
        AssistantChatLead(lead: .failure)
        AssistantChatLead(lead: .push)
        AssistantChatLead(lead: .draft)
    }
    .padding()
}
