//
//  EventArtworkBriefStep.swift
//  Atlas
//

import SwiftUI

/// The Brief: what the art should show (written from the event's texts),
/// what Claude gets, the options, the look to start from, and what
/// comes back.
struct EventArtworkBriefStep: View {
    @Bindable var flow: EventArtworkFlow

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xLarge) {
            VStack(alignment: .leading, spacing: Spacing.large) {
                briefBox
                gets
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: Spacing.large) {
                options
                looks
                result
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var run: EventArtworkRun { flow.run }

    private var briefBox: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("What it should show")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            TextEditor(text: Binding { flow.run.brief } set: { text in flow.edit { $0.brief = text } })
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.xSmall)
                .frame(height: 120)
                .background(Palette.content, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.separator))
                .accessibilityIdentifier("events.art.brief.text")
            Text("Written from the event’s name and descriptions. Change anything, or leave it.")
                .font(.caption)
                .foregroundStyle(Palette.label2)
        }
    }

    private var gets: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("What Claude gets")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            getsRow(isOn: true, title: String(localized: "The event"), detail: String(localized: "Name, both descriptions, the badge, dates"))
            if flow.hasDesignSystem {
                getsRow(
                    isOn: true, title: String(localized: "\(flow.app.name)’s design system"),
                    detail: String(localized: "Colors, type and motifs from the design project connected to \(flow.app.name)")
                )
            } else {
                getsRow(
                    isOn: true, title: String(localized: "\(flow.app.name)’s look"),
                    detail: String(localized: "No design project is connected, so Claude works from the colors and type Atlas knows.")
                )
            }
            Toggle(isOn: Binding { flow.run.usesCapture } set: { isOn in flow.edit { $0.usesCapture = isOn } }) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("A capture of \(flow.app.name)")
                        .font(.callout)
                    Text("Claude looks at \(flow.app.name)’s captures in Screenshots and takes the screen the event is about as reference.")
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityIdentifier("events.art.capture")
        }
    }

    private func getsRow(isOn: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: isOn ? "checkmark" : "minus")
                .font(.caption.weight(.bold))
                .foregroundStyle(isOn ? Palette.positive : Palette.label3)
                .frame(width: 14)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Options")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            option(
                title: String(localized: "Words in the art"),
                detail: EventArtworkBrief.wordsDetail(isOn: run.wordsInArt, languages: run.locales.count),
                isOn: Binding { flow.run.wordsInArt } set: { isOn in flow.edit { $0.wordsInArt = isOn } },
                identifier: "events.art.words"
            )
            .disabled(run.style == .extendCard)
            option(
                title: String(localized: "Also make a moving version"),
                detail: String(localized: "A seamless 20-second loop of each image, played muted and on repeat. The still is kept for where video can’t play."),
                isOn: Binding { flow.run.makesMotion } set: { isOn in flow.edit { $0.makesMotion = isOn } },
                identifier: "events.art.motion"
            )
        }
    }

    private func option(title: String, detail: String, isOn: Binding<Bool>, identifier: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).detail")
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityIdentifier(identifier)
    }

    private var looks: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Look")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(EventArtworkStyle.allCases, id: \.self) { style in
                RadioRow(
                    title: style.title, detail: style.detail(appName: flow.app.name), isSelected: run.style == style,
                    isDisabled: !flow.isOffered(style),
                    action: {
                        flow.edit { run in
                            run.style = style
                            if style == .extendCard { run.wordsInArt = false }
                        }
                    },
                    leading: { EmptyView() }
                )
                .overlay(alignment: .topTrailing) {
                    if style == .newLook, flow.isOffered(style) {
                        Pill(text: String(localized: "Recommended"), style: .accent)
                            .fixedSize()
                    }
                }
                .accessibilityIdentifier("events.art.look.\(style.rawValue)")
            }
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("What you’ll get")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .bottom, spacing: Spacing.medium) {
                tile(String(localized: "Event card"), size: "1920 × 1080", width: 96, height: 54, isKept: run.style == .extendCard)
                tile(String(localized: "Event details"), size: "1080 × 1920", width: 34, height: 60, isKept: false)
            }
            Text(EventArtworkBrief.result(style: run.style, wordsInArt: run.wordsInArt, makesMotion: run.makesMotion, languages: run.locales.count))
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("events.art.result")
        }
    }

    private func tile(_ title: String, size: String, width: CGFloat, height: CGFloat, isKept: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                .fill(isKept ? Palette.fill1 : Palette.accentTint)
                .overlay(RoundedRectangle(cornerRadius: Radius.badge, style: .continuous).strokeBorder(Palette.separator))
                .frame(width: width, height: height)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(isKept ? String(localized: "Kept") : size)
                .font(.caption2)
                .foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .combine)
    }
}
