//
//  EventArtworkPanel.swift
//  Atlas
//

import SwiftUI

/// "Artwork" on the event's page (boards 40 and 47): what the event's art
/// is at (Claude drawing, concepts to choose from, the one used, an
/// image missing), the concepts as rows that preview on the card, or the
/// event's pair, and its buttons: Make the Artwork…, Choose Files…, Stop,
/// View Full Size, Change…, Keep Current, Use This Artwork.
struct EventArtworkPanel: View {
    let state: EventArtworkPanelState
    let event: InAppEvent
    let card: InAppEventArtSource
    let details: InAppEventArtSource
    /// The language the concepts' thumbnails are shown in.
    var locale: String?
    var isFree = false
    var isWorking = false
    var problem: String?
    var copiedPrompt: String?
    var onCopyAgain: () -> Void = {}
    let actions: EventArtworkPanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            heading
            VStack(alignment: .leading, spacing: 2) {
                Text(state.line)
                    .font(.callout.weight(state.tone == .normal ? .regular : .semibold))
                    .foregroundStyle(lineColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.art.line")
                Text(state.detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.art.detail")
            }
            if state.isDrawing {
                // Drawn rather than a ProgressView, so it stays purple in a
                // window that isn't key.
                Capsule()
                    .fill(Palette.fill2)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Palette.ai)
                                .frame(width: proxy.size.width * min(max(state.progress, 0), 1))
                        }
                    }
                    .frame(height: 4)
                    .animation(.easeOut(duration: 0.3), value: state.progress)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Concepts ready"))
                    .accessibilityValue(Text(state.progress, format: .percent.precision(.fractionLength(0))))
                    .accessibilityIdentifier("events.art.progress")
            }
            if state.isRows {
                VStack(spacing: 5) {
                    ForEach(state.rows) { row in
                        EventArtworkConceptRow(row: row, locale: locale) {
                            if let id = row.concept?.id { actions.preview(id) }
                        } onView: {
                            actions.view(row.concept?.id, nil)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Concepts"))
                .accessibilityIdentifier("events.art.rows")
            } else {
                EventArtworkPanelPair(card: card, details: details, event: event) { kind in actions.view(nil, kind) }
            }
            if let copiedPrompt, !copiedPrompt.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    InlineMessage(
                        text: String(localized: """
                        Atlas couldn’t start Claude Code here, so its prompt is copied. Paste it into Claude Code: \
                        the concepts arrive here.
                        """),
                        systemImage: "doc.on.clipboard", tint: Palette.label2
                    )
                    .font(.subheadline)
                    Button("Copy Again", action: onCopyAgain)
                        .controlSize(.regular)
                        .accessibilityIdentifier("events.art.copyPrompt")
                }
                .accessibilityIdentifier("events.art.copied")
            }
            if let problem {
                InlineMessage.error(problem)
                    .font(.subheadline)
                    .accessibilityIdentifier("events.art.problem")
            }
            Spacer(minLength: 0)
            buttons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.panel.\(state.id)")
    }

    private var heading: some View {
        HStack(spacing: Spacing.small) {
            Text("Artwork")
                .font(.body.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if state.isByClaudeDesign {
                AssistantChip(name: DesignProjectKind.claude, monogram: "C")
                    .fixedSize()
                    .accessibilityIdentifier("events.art.cd")
            }
            Spacer(minLength: 0)
        }
    }

    private var lineColor: Color {
        switch state.tone {
        case .normal: Palette.label
        case .suggestion: Palette.ai
        case .warning: Palette.warn
        }
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            FlowLayout(spacing: 6) {
                if state.showsMake {
                    Button(action: actions.make) {
                        HStack(spacing: Spacing.xxSmall) {
                            AIStartLabel(String(localized: "Make the Artwork…"))
                            if isFree { ProChip() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("events.art.make")
                }
                if state.showsChooseFiles {
                    Button("Choose Files…", action: actions.chooseFiles)
                        .accessibilityIdentifier("events.art.files")
                }
                if state.showsStop {
                    Button("Stop", action: actions.stop)
                        .accessibilityIdentifier("events.art.stop")
                }
                if state.showsAddMotion {
                    Button("Make Them Move", action: actions.addMotion)
                        .help("Adds a 20-second loop to the card and details page")
                        .accessibilityIdentifier("events.art.addMotion")
                }
                if state.showsView {
                    Button("⤢ View Full Size") { actions.view(nil, nil) }
                        .accessibilityIdentifier("events.art.view")
                }
                if state.showsChange {
                    Button("Change…", action: actions.change)
                        .accessibilityIdentifier("events.art.change")
                }
                if state.showsReplace {
                    Menu("Replace") {
                        Button("Make the Artwork…", action: actions.make)
                        Button("Choose Files…", action: actions.chooseFiles)
                    }
                    .menuStyle(.button)
                    .fixedSize()
                    .accessibilityIdentifier("events.art.replace")
                }
                if state.showsKeepCurrent {
                    Button("Keep Current", action: actions.keepCurrent)
                        .help(Text("Keep “\(state.usedName ?? "")”"))
                        .accessibilityIdentifier("events.art.keep")
                }
                if state.showsUse {
                    if isWorking { ProgressView().controlSize(.small) }
                    Button("Use This Artwork", action: actions.use)
                        .buttonStyle(.borderedProminent)
                        .disabled(isWorking)
                        .accessibilityIdentifier("events.art.use")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonBorderShape(.capsule)
    }
}
