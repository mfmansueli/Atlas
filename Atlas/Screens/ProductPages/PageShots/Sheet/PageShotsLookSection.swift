//
//  PageShotsLookSection.swift
//  Atlas
//

import SwiftUI

/// Plan's Look (board 52): the same template as the default page, another
/// of Atlas's templates, or a new look from Claude Design, which adds a
/// stop where the person chooses between three.
struct PageShotsLookSection: View {
    @Bindable var flow: PageShotsFlow
    /// The default page's source, without the run's Look.
    let source: PageShotsSource

    @State private var lastStarter: TemplateStarter = .band

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Look").font(.body.weight(.semibold))
            option(
                isOn: look == .same, title: String(localized: "The same template as the default page"), detail: sameNote,
                id: "pages.shots.look.same"
            ) { await flow.choose(look: .same) }
            option(
                isOn: starter != nil, title: String(localized: "Another template…"),
                detail: String(localized: "Choose from Atlas’s \(TemplateStarter.allCases.count) templates."),
                id: "pages.shots.look.template"
            ) { await flow.choose(look: .starter(starter ?? lastStarter)) }
            if let starter {
                Picker("Template", selection: Binding(get: { starter }, set: { new in
                    lastStarter = new
                    Task { await flow.choose(look: .starter(new)) }
                })) {
                    ForEach(TemplateStarter.allCases) { starter in
                        Text(starter.title).tag(starter)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .padding(.leading, 26)
                .accessibilityIdentifier("pages.shots.look.templatePicker")
            }
            option(
                isOn: look.isClaudeDesign, title: String(localized: "A new look from Claude Design"),
                detail: String(localized: "Adds a stop where you choose between three looks."), id: "pages.shots.look.claudeDesign"
            ) { await flow.choose(look: .claudeDesign) }
            if look.isClaudeDesign {
                PageShotsLookCandidates(flow: flow, source: source)
                    .padding(.leading, 26)
            }
        }
    }

    private var look: PageShotsLook { flow.run?.look ?? .same }

    private var starter: TemplateStarter? {
        if case let .starter(starter) = look { return starter }
        return nil
    }

    private var sameNote: String {
        let name = flow.defaultTemplateName
        let app = flow.app.name
        return name.isEmpty
            ? String(localized: "The page looks like \(app), with a different story.")
            : String(localized: "\(name). The page looks like \(app), with a different story.")
    }

    private func option(isOn: Bool, title: String, detail: String, id: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(alignment: .top, spacing: Spacing.small) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isOn ? Palette.accent : Palette.label2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(flow.run?.stage == .making)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(id)
    }
}
