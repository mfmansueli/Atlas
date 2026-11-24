//
//  Banner.swift
//  Atlas
//

import SwiftUI

/// A full-width notice above a section's content, shown with
/// `.safeAreaInset(edge: .top)`: offline, rate limited, an API error with
/// Apple's detail, a partial push failure, a warning, or plain information.
/// Errors from Apple and being offline end with Fix a Problem, which opens
/// Help at their heading (the article's top when the kind of error isn't
/// known); other kinds only when given a `fixTopic`.
struct Banner<Actions: View>: View {
    let kind: BannerKind
    let title: String
    var message: String?
    /// The message runs on after the bold title, as one paragraph, e.g.
    /// "**2 renders fail their checks.** First: German, slot 3 · Overflow."
    var isInline = false
    /// Where Fix a Problem lands; by default the kind's heading.
    var fixTopic: HelpFixTopic?
    let showsFixProblem: Bool
    @ViewBuilder var actions: () -> Actions

    init(
        kind: BannerKind,
        title: String,
        message: String? = nil,
        isInline: Bool = false,
        fixTopic: HelpFixTopic? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.isInline = isInline
        self.fixTopic = fixTopic ?? HelpFixTopic(banner: kind)
        showsFixProblem = fixTopic != nil || kind == .apiError || kind == .offline
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(kind.tint)
                .accessibilityHidden(true)
            if isInline, let message {
                Text("\(Text(title).fontWeight(.semibold)) \(Text(message).foregroundStyle(Palette.label2))")
                    .font(.callout)
                    .textSelection(.enabled)
                    .layoutPriority(1)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    if let message {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(Palette.label2)
                            .textSelection(.enabled)
                    }
                }
                .layoutPriority(1)
            }
            Spacer(minLength: Spacing.medium)
            // The buttons keep their whole titles; a long message wraps
            // instead of squeezing them to a letter each.
            HStack(spacing: Spacing.small) {
                if showsFixProblem {
                    FixProblemLink(topic: fixTopic)
                }
                actions()
            }
            .controlSize(.regular)
            .fixedSize()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(kind.background, in: RoundedRectangle(cornerRadius: Radius.banner))
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
    }
}

extension Banner where Actions == EmptyView {
    init(kind: BannerKind, title: String, message: String? = nil, isInline: Bool = false, fixTopic: HelpFixTopic? = nil) {
        self.init(kind: kind, title: title, message: message, isInline: isInline, fixTopic: fixTopic) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 0) {
        Banner(kind: .offline, title: "You're offline", message: "Edits stay queued on this Mac.")
        Banner(kind: .rateLimited, title: "Rate limited", message: "Pushing resumes at 12:00; nothing is lost.")
        Banner(kind: .apiError, title: "App Store Connect returned an error (409)", message: "ENTITY_ERROR.ATTRIBUTE.INVALID") {
            Button("Try Again") {}
        }
        Banner(kind: .warning, title: "No version to push to.", message: "Create version 1.5 first.", isInline: true)
    }
    .frame(width: 700)
}
