//
//  ScreenshotHandChosenImage.swift
//  Atlas
//

import AppKit
import SwiftUI

/// A file picked for a set, drawn small from its bytes.
struct ScreenshotHandChosenImage: View {
    let file: ScreenshotHandChosenFile
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let image = NSImage(data: file.data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Palette.fill2
                    Image(systemName: "questionmark")
                        .foregroundStyle(Palette.label3)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: min(8, width * 0.12), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: min(8, width * 0.12), style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}
