//
//  DebugPaywallImage.swift
//  Atlas
//

#if DEBUG
import AppKit
import SwiftUI

/// DEBUG-only: a made-up iPhone paywall (“Lumen Plus”, three plans with
/// their prices, one selected) as a 1206 × 2622 PNG, for the review
/// screenshot scenes' captures and suggestions.
@MainActor
enum DebugPaywallImage {
    static let plans: [(name: String, price: String)] = [("Monthly", "$4.99"), ("Annual", "$29.99"), ("Lifetime", "$59.99")]

    /// The PNG with `selected` highlighted.
    static func png(selected: String) -> Data? {
        let renderer = ImageRenderer(content: page(selected: selected))
        renderer.scale = 3
        guard let image = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// Writes it to `url`, once.
    @discardableResult
    static func write(selected: String, to url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), let data = png(selected: selected) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        return url
    }

    private static func page(selected: String) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("9:41").font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "battery.100")
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            Spacer().frame(height: 40)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Lumen Plus")
                .font(.system(size: 34, weight: .bold))
            Text("Unlimited journals, themes and iCloud sync.")
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            VStack(spacing: 12) {
                ForEach(plans, id: \.name) { plan in
                    HStack {
                        Image(systemName: plan.name == selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(plan.name == selected ? .indigo : .secondary)
                        Text(plan.name).font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Text(plan.price).font(.system(size: 18))
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(plan.name == selected ? Color.indigo : Color.gray.opacity(0.3), lineWidth: plan.name == selected ? 2.5 : 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            Spacer()
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            Text("Restore Purchases · Terms · Privacy")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 30)
        }
        .frame(width: 402, height: 874)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
#endif
