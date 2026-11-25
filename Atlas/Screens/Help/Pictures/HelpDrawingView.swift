//
//  HelpDrawingView.swift
//  Atlas
//

import SwiftUI

/// One of Help's drawings of App Store Connect: the page in a browser
/// window, under its step's text as in the design, scaled to the column.
/// It sits next to the step that says the same thing, so VoiceOver reads
/// one label naming what to click instead of every word drawn.
struct HelpDrawingView: View {
    let drawing: HelpDrawing

    var body: some View {
        HelpDrawingScaler {
            HelpBrowserFrame {
                page
            }
        }
        .padding(.leading, Spacing.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(drawing.accessibilityLabel))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("help.image")
    }

    @ViewBuilder private var page: some View {
        switch drawing {
        case .connectIntegrations: HelpIntegrationsPage()
        case .connectTeamKey: HelpTeamKeyPage()
        case .connectDownload: HelpDownloadPage()
        case .connectIDs: HelpIssuerAndKeyIDPage()
        }
    }
}
