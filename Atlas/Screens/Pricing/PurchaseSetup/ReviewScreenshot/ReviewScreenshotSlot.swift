//
//  ReviewScreenshotSlot.swift
//  Atlas
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The App Review screenshot of a subscription or in-app purchase: a drop
/// target with Choose File…, the chosen image's thumbnail, name and size,
/// and Remove. The file is kept in Atlas's folder until the push uploads it.
struct ReviewScreenshotSlot: View {
    let appID: StoreApp.ID
    @Binding var file: PurchaseReviewScreenshotFile?
    var folder: PurchaseReviewScreenshotFolder = .shared

    @State private var isImporterPresented = false
    @State private var isTargeted = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .center, spacing: Spacing.medium) {
                preview
                    .frame(width: 64, height: 96)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(file?.summary ?? String(localized: "Drop the paywall screenshot here"))
                        .font(.callout)
                        .foregroundStyle(file == nil ? Palette.label2 : Palette.label)
                        .lineLimit(2)
                    HStack(spacing: Spacing.small) {
                        Button(file == nil ? "Choose File…" : "Replace…") { isImporterPresented = true }
                            .accessibilityIdentifier("pricing.reviewScreenshot.choose")
                        if file != nil {
                            Button("Remove", role: .destructive) { file = nil }
                                .accessibilityIdentifier("pricing.reviewScreenshot.remove")
                        }
                    }
                    .controlSize(.regular)
                    .buttonBorderShape(.capsule)
                }
                Spacer(minLength: 0)
            }
            if let problem {
                Text(problem)
                    .font(.subheadline)
                    .foregroundStyle(Palette.err)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pricing.reviewScreenshot.problem")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            take(url)
            return true
        } isTargeted: { isTargeted = $0 }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.png, .jpeg]) { result in
            if case let .success(url) = result { take(url) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.reviewScreenshot")
    }

    @ViewBuilder
    private var preview: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
        if let file, let image = NSImage(contentsOf: folder.url(for: file, appID: appID)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(shape)
                .accessibilityLabel(Text("Review screenshot \(file.fileName)"))
        } else {
            shape
                .strokeBorder(isTargeted ? Palette.accent : Palette.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .overlay {
                    Image(systemName: "photo.badge.plus")
                        .foregroundStyle(Palette.label3)
                }
                .accessibilityHidden(true)
        }
    }

    private func take(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            file = try folder.save(data, fileName: url.lastPathComponent, appID: appID)
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }
}
