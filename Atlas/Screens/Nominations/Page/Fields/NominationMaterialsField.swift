//
//  NominationMaterialsField.swift
//  Atlas
//

import SwiftUI

/// Materials: links only, since Apple takes no files. The links, each with
/// Remove; the ones Atlas already knows (App Store page, approved custom
/// product pages) with Add; and Add Link… for any other.
struct NominationMaterialsField: View {
    let links: [String]
    let known: [NominationContext.KnownLink]
    var isEditable = true
    let onChange: ([String]) -> Void

    @State private var isAdding = false
    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if links.isEmpty {
                Text("No links yet.").font(.callout).foregroundStyle(Palette.label2)
            }
            ForEach(links, id: \.self) { link in
                HStack(spacing: Spacing.small) {
                    Image(systemName: "link").foregroundStyle(Palette.label2)
                    VStack(alignment: .leading, spacing: Spacing.tiny) {
                        Text(title(of: link)).font(.body.weight(.medium))
                        Text(link).font(.subheadline).foregroundStyle(Palette.label2).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: Spacing.small)
                    if isEditable {
                        Button("Remove") { onChange(links.filter { $0 != link }) }
                            .controlSize(.small)
                            .accessibilityIdentifier("nominations.materials.remove")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("nominations.materials.link")
            }
            if isEditable {
                knownLinks
                adding
                Text("Apple takes links, not files. Host a video, deck or mockups somewhere, then add the link.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var knownLinks: some View {
        if !known.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Links Atlas already knows")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .textCase(.uppercase)
                ForEach(known, id: \.url) { link in
                    HStack(spacing: Spacing.small) {
                        VStack(alignment: .leading, spacing: Spacing.tiny) {
                            Text(link.title).font(.body)
                            Text(link.detail).font(.subheadline).foregroundStyle(Palette.label2)
                        }
                        Spacer(minLength: Spacing.small)
                        Button("Add") { onChange(links + [link.url]) }
                            .controlSize(.small)
                            .accessibilityIdentifier("nominations.materials.addKnown")
                    }
                }
            }
            .padding(Spacing.small)
            .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("nominations.materials.known")
        }
    }

    @ViewBuilder
    private var adding: some View {
        if isAdding {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.small) {
                    TextField("https://", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                        .onChange(of: draft) { error = nil }
                        .accessibilityIdentifier("nominations.materials.field")
                    Button("Cancel") {
                        isAdding = false
                        draft = ""
                        error = nil
                    }
                    Button("Add", action: add)
                        .accessibilityIdentifier("nominations.materials.confirm")
                }
                if let error {
                    InlineMessage.warning(error).font(.subheadline)
                }
            }
        } else {
            Button("Add Link…") { isAdding = true }
                .accessibilityIdentifier("nominations.materials.add")
        }
    }

    private func add() {
        let link = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else {
            error = String(localized: "Paste a link first.", comment: "kind:error")
            return
        }
        guard NominationLink.isValid(link) else {
            error = String(localized: "Use a full link that starts with https://", comment: "kind:error")
            return
        }
        if !links.contains(link) { onChange(links + [link]) }
        isAdding = false
        draft = ""
    }

    private func title(of link: String) -> String {
        known.first { $0.url == link }?.title ?? String(localized: "Link · \(NominationLink.host(of: link))", comment: "kind:field-label")
    }
}
