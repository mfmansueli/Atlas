//
//  NewProductPageSheet.swift
//  Atlas
//

import SwiftUI

/// New Page… (board 51): the page's name, what it starts from (the default
/// page of the version, a copy of another page, or nothing), a note for the
/// assistant, and the languages with content of their own. It starts as a
/// draft in Atlas; nothing is in App Store Connect until it's pushed.
struct NewProductPageSheet: View {
    @Bindable var viewModel: ProductPagesViewModel
    @State var page: NewProductPage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("New Product Page")
                    .font(.title3.weight(.semibold))
                Text("A page of its own on the App Store, with its own link. It starts as a draft in Atlas.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            .padding(Spacing.xLarge)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    name
                    start
                    note
                    languages
                }
                .padding(Spacing.xLarge)
            }
            Divider()
            footer
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.medium)
        }
        .frame(width: 560)
        .frame(minHeight: 480, idealHeight: 640, maxHeight: 720)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.newSheet")
    }

    // MARK: - Fields

    private var name: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Name").font(.headline)
            TextField("Name", text: $page.name, prompt: Text("Private diary"))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("pages.new.name")
            Text("Only you see this. It names the page in App Store Connect and in Analytics.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Start from").font(.headline)
            RadioRow(
                title: viewModel.defaultPage.versionString.map { String(localized: "The default page of version \($0)") }
                    ?? String(localized: "The default page"),
                detail: String(localized: "Its screenshots, App Previews and promotional text, in every language."),
                isSelected: page.start == .defaultPage
            ) { page.start = .defaultPage }
                .accessibilityIdentifier("pages.new.start.default")
            RadioRow(
                title: String(localized: "A copy of another page"),
                detail: String(localized: "Everything that page has, except its keywords."),
                isSelected: isCopy,
                isDisabled: copyable.isEmpty
            ) {
                if let first = copyable.first, !isCopy { page.start = .copy(pageID: first.id, name: first.name) }
            }
            .accessibilityIdentifier("pages.new.start.copy")
            if isCopy {
                Picker("Page to copy", selection: copyBinding) {
                    ForEach(copyable) { other in
                        Text(other.name).tag(other.id)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .padding(.leading, 26)
                .accessibilityIdentifier("pages.new.copyFrom")
            }
            RadioRow(
                title: String(localized: "Empty"),
                detail: String(localized: "Shows the default page’s content until you add your own."),
                isSelected: page.start == .empty
            ) { page.start = .empty }
                .accessibilityIdentifier("pages.new.start.empty")
        }
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Who is it for, and what should it do?").font(.headline)
            TextField("Who is it for, and what should it do?", text: $page.note, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("pages.new.note")
            Text("A note for your assistant. It uses it to suggest keywords, text and screenshots. It isn’t sent to Apple.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languages: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text("Languages with their own content").font(.headline)
                Spacer(minLength: Spacing.small)
                Text("\(page.locales.count) of \(allLocales.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("pages.new.languages.count")
            }
            FlowLayout(spacing: Spacing.xSmall, lineSpacing: Spacing.xSmall) {
                ForEach(allLocales, id: \.self) { code in
                    ProductPageLanguageChip(
                        language: ProductPageLanguage(code: code, state: .same), isSelected: page.locales.contains(code)
                    ) {
                        toggle(code)
                    }
                    .accessibilityIdentifier("pages.new.language.\(code)")
                }
            }
            Text("""
            The page exists in all \(allLocales.count) languages. The ones you leave out show the default page’s content, and \
            you can add them later.
            """)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(summary) Nothing is in App Store Connect until you push.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                if let problem, !page.trimmedName.isEmpty {
                    Text(problem)
                        .font(.subheadline)
                        .foregroundStyle(Palette.danger)
                        .accessibilityIdentifier("pages.new.problem")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel") {
                viewModel.isNewPagePresented = false
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("pages.new.cancel")
            Button("Create Page") {
                viewModel.create(page)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(problem != nil)
            .accessibilityIdentifier("pages.new.create")
        }
    }

    // MARK: - Helpers

    private var problem: String? {
        page.problem(existingNames: viewModel.pages.map(\.name))
    }

    private var summary: String {
        page.start.summary(versionString: viewModel.defaultPage.versionString, languageCount: max(page.locales.count, 1))
    }

    private var allLocales: [String] {
        let known = viewModel.defaultPage.locales
        let all = known.isEmpty ? [viewModel.primaryLocale] : known
        guard let index = all.firstIndex(of: viewModel.primaryLocale), index > 0 else { return all }
        var ordered = all
        ordered.insert(ordered.remove(at: index), at: 0)
        return ordered
    }

    /// Pages in App Store Connect: a draft can't be copied yet.
    private var copyable: [ProductPage] {
        viewModel.pages.filter { !$0.isDraft }
    }

    private var isCopy: Bool {
        if case .copy = page.start { return true }
        return false
    }

    private var copyBinding: Binding<ProductPage.ID> {
        Binding {
            if case let .copy(pageID, _) = page.start { return pageID }
            return copyable.first?.id ?? ""
        } set: { id in
            if let other = copyable.first(where: { $0.id == id }) { page.start = .copy(pageID: other.id, name: other.name) }
        }
    }

    private func toggle(_ code: String) {
        if let index = page.locales.firstIndex(of: code) {
            page.locales.remove(at: index)
        } else {
            page.locales = allLocales.filter { page.locales.contains($0) || $0 == code }
        }
    }
}
