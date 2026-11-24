//
//  NominationAssistantCard.swift
//  Atlas
//

import SwiftUI

/// An assistant's suggestion on a nomination's page, in purple: its new
/// nomination under review ("Every field below is suggested"), changes to
/// a draft, or a request to submit or archive. Accept on a request opens
/// the same confirmation as the person's own button; the assistant never
/// sends anything.
struct NominationAssistantCard: View {
    let title: String
    var message: String?
    let evidence: AssistantEvidence
    let receivedAt: Date
    let acceptTitle: String
    let identifier: String
    let onDismiss: () -> Void
    let onAccept: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Pill(text: String(localized: "Suggested", comment: "kind:pill"), style: .machineTranslated)
                    .fixedSize()
                SuggestionSourceTag(source: .assistant(client: evidence.client))
                Spacer(minLength: 0)
                if let confidence = evidence.layers?.confidence { HowSureMeter(confidence: confidence) }
            }
            Text(title)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            if !evidence.why.isEmpty {
                SuggestedText(evidence.why, arrivalKey: arrivalKey, arrivedAt: receivedAt)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let gloss = evidence.layers?.gloss { GlossLine(gloss: gloss) }
            HStack(spacing: Spacing.small) {
                Spacer(minLength: 0)
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss) }
                    .accessibilityIdentifier("\(identifier).dismiss")
                Button(acceptTitle, action: onAccept)
                    .rowActionButton()
                    .accessibilityIdentifier("\(identifier).accept")
            }
            .buttonBorderShape(.capsule)
            if let details = evidence.layers?.details { SuggestionDetailsDisclosure(details: details) }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .suggestionSurface(isSettling: false, arrivalKey: arrivalKey, arrivedAt: receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var arrivalKey: String { "\(identifier)|\(receivedAt.timeIntervalSinceReferenceDate)" }
}
