//
//  ConnectDesignProjectSheet.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// Connect a Design Project: Claude Design (recommended), a Figma file, a
/// brand folder, or Atlas's starters; the system or project, what
/// was found, and how it connects.
struct ConnectDesignProjectSheet: View {
    @Bindable var studio: ScreenshotStudioModel
    @State private var kind: DesignProjectKind = .claudeDesign
    @State private var link = ""
    @State private var createsInClaudeDesign = true
    @State private var summary: DesignSourceSummary?
    @State private var findMessage: String?
    @State private var isPickingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Text("Connect a Design Project").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text("Makes \(studio.app.name)’s screenshot template in your brand, as an Atlas template you can edit here.")
                            .font(.callout)
                            .foregroundStyle(Palette.label2)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.small), GridItem(.flexible())], spacing: Spacing.small) {
                        ForEach(DesignProjectKind.allCases) { option in
                            DesignKindCard(kind: option, isSelected: kind == option) {
                                select(option)
                            }
                        }
                    }
                    if kind != .none { source }
                    if kind == .claudeDesign {
                        Toggle("Also add the directions to Claude Design", isOn: $createsInClaudeDesign)
                            .toggleStyle(.checkbox)
                            .accessibilityIdentifier("designProject.createInClaudeDesign")
                    }
                    Label {
                        Text(howItConnects).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                    .accessibilityIdentifier("designProject.howItConnects")
                }
                .padding(Spacing.xLarge)
            }
            Divider()
            HStack {
                Button("Cancel") { studio.isDesignProjectPresented = false }
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(kind == .none ? String(localized: "Use Starters") : String(localized: "Connect")) { connect() }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut(.defaultAction)
                    .disabled(kind != .none && link.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("designProject.connect")
            }
            .padding(Spacing.large)
        }
        .frame(width: 700, height: 640)
        .onAppear(perform: restore)
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            guard case let .success(url) = result else { return }
            read(folder: url)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("designProject.sheet")
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(sourceTitle).font(.body.weight(.semibold))
            HStack(spacing: Spacing.small) {
                TextField(sourcePrompt, text: $link)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("designProject.link")
                Button(kind == .folder ? String(localized: "Choose…") : String(localized: "Find")) { find() }
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("designProject.find")
            }
            if let summary {
                DesignSourceSummaryView(summary: summary)
            } else if let findMessage {
                Text(findMessage)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("designProject.findMessage")
            }
        }
    }

    private var sourceTitle: String {
        switch kind {
        case .claudeDesign: String(localized: "Design system or project")
        case .figma: String(localized: "Figma file")
        case .folder: String(localized: "Folder")
        case .none: ""
        }
    }

    private var sourcePrompt: String {
        switch kind {
        case .claudeDesign: String(localized: "Name or link, e.g. Northpier Brand")
        case .figma: "https://www.figma.com/design/…"
        case .folder: String(localized: "A folder with tokens.json, fonts and an SVG logo")
        case .none: ""
        }
    }

    private var howItConnects: String {
        switch kind {
        case .claudeDesign, .figma:
            String(localized: "Claude gets the brief over MCP (captures, captions, sizes, safe areas) and returns templates designed with your \(kind == .figma ? String(localized: "Figma file") : String(localized: "design system")). Nothing is sent to App Store Connect.")
        case .folder:
            String(localized: "Atlas sends the folder’s colors, fonts and logo to the assistant. Directions come back as Atlas templates.")
        case .none:
            String(localized: "Three directions from Atlas’s starters, in the icon’s colors. Connect a design project any time.")
        }
    }

    private func select(_ option: DesignProjectKind) {
        guard option != kind else { return }
        kind = option
        link = ""
        summary = nil
        findMessage = nil
        if let project = studio.designProject, project.kind == option {
            link = project.link
            summary = project.summary
        }
    }

    private func restore() {
        guard let project = studio.designProject else { return }
        kind = project.kind
        link = project.link
        createsInClaudeDesign = project.createsInClaudeDesign
        summary = project.summary
    }

    private func find() {
        if kind == .folder {
            isPickingFolder = true
            return
        }
        summary = studio.designProject?.link == link ? studio.designProject?.summary : nil
        if summary == nil {
            findMessage = String(localized: "Atlas can’t open \(kind.title). Claude reads “\(link)” during design; what it finds shows here.")
        }
    }

    private func read(folder: URL) {
        let didAccess = folder.startAccessingSecurityScopedResource()
        defer { if didAccess { folder.stopAccessingSecurityScopedResource() } }
        link = folder.path(percentEncoded: false)
        do {
            summary = try BrandFolderReader.summary(of: folder)
            findMessage = nil
        } catch let error as AutopilotError {
            summary = nil
            findMessage = error.localizedDescription
        } catch {
            summary = nil
            findMessage = AppleErrorCopy(String(localized: "The folder couldn’t be read.", comment: "kind:error"), error: error).text
        }
    }

    private func connect() {
        let project = kind == .none ? nil : DesignProject(
            kind: kind, link: link.trimmingCharacters(in: .whitespaces), createsInClaudeDesign: kind == .claudeDesign && createsInClaudeDesign,
            summary: summary
        )
        studio.autopilot?.setDesignProject(project, for: studio.app.id)
        studio.isDesignProjectPresented = false
    }
}
