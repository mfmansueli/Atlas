//
//  InAppEventTextAreaHatch.swift
//  Atlas
//

import SwiftUI

/// Where the App Store writes over an event's art, hatched and outlined:
/// the lower part of the image (`InAppEventArtworkLook.lowerPart` down),
/// labelled "The App Store’s text" on a dark chip just above it at the
/// trailing edge, clear of the badge and name the App Store writes there.
struct InAppEventTextAreaHatch: View {
    var labelSize: CGFloat = 11

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.size.height * InAppEventArtworkLook.lowerPart
            Canvas { context, size in
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 9
                }
                context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
            }
            .background(Color.black.opacity(0.28))
            .overlay { Rectangle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5) }
            .overlay(alignment: .topTrailing) {
                Text("The App Store’s text")
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, labelSize * 0.6)
                    .padding(.vertical, labelSize * 0.15)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: labelSize * 0.6, style: .continuous))
                    .alignmentGuide(.top) { $0[.bottom] + labelSize * 0.4 }
                    .padding(.trailing, labelSize * 0.8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height - top)
            .offset(y: top)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("The App Store’s text"))
        .accessibilityIdentifier("events.art.textAreaShown")
    }
}
