//
//  HelpPictureView.swift
//  Atlas
//

import SwiftUI

/// A picture in a Help article: a drawing of App Store Connect, or the
/// bundled image of that name. An image the bundle doesn't have takes no
/// room.
struct HelpPictureView: View {
    let name: String
    let caption: String

    var body: some View {
        switch HelpPictureSource(name: name) {
        case let .drawing(drawing):
            HelpDrawingView(drawing: drawing)
        case let .asset(name):
            if let image = Bundle.main.image(forResource: name) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(Palette.separator, lineWidth: 0.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text(caption))
                    .accessibilityIdentifier("help.image")
            }
        }
    }
}
