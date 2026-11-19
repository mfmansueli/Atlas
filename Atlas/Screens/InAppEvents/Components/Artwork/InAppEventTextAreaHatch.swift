//
//  InAppEventTextAreaHatch.swift
//  Atlas
//

import SwiftUI

/// Where the App Store writes over an event's art, hatched: the lower part
/// of the image (`InAppEventArtworkLook.lowerPart` down), labelled "The App
/// Store’s text".
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
            .overlay(alignment: .topLeading) {
                Text("The App Store’s text")
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(6)
            }
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.7)).frame(height: 1) }
            .frame(width: proxy.size.width, height: proxy.size.height - top)
            .offset(y: top)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("The App Store’s text"))
        .accessibilityIdentifier("events.art.textAreaShown")
    }
}
