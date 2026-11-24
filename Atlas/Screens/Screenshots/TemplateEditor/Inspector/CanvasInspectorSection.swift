//
//  CanvasInspectorSection.swift
//  Atlas
//

import SwiftUI

/// Display type, orientation, and the output size and API display type.
struct CanvasInspectorSection: View {
    let model: TemplateEditorViewModel
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        TemplateInspectorSection(title: String(localized: "Canvas")) {
            TemplateInspectorPicker(
                String(localized: "Display type"), selection: Binding { model.screenshots.displayType } set: { display in
                    // Free's templates lay out iPhone and iPad; the others open the paywall.
                    if pro.mayShow(display) {
                        model.screenshots.displayType = display
                    } else {
                        pro.require(.templateDevice(display.title)) { model.screenshots.displayType = display }
                    }
                },
                identifier: "screenshots.template.displayType"
            ) {
                ForEach(model.screenshots.renderedDisplays) { display in
                    Text(verbatim: pro.mayShow(display) ? display.title : "\(display.title) · \(DisplayTypeMenu.proNote)").tag(display)
                }
            }
            TemplateInspectorPicker(
                String(localized: "Orientation"), selection: Binding { model.orientation } set: { model.setOrientation($0) },
                identifier: "screenshots.template.orientation"
            ) {
                ForEach(ScreenshotOrientation.allCases, id: \.self) { orientation in
                    Text(orientation.title).tag(orientation)
                }
            }
            // Mac's screenshots are always landscape.
            .disabled(model.screenshots.displayType.isAlwaysLandscape)
            Text(model.outputText)
                .font(.subheadline.monospaced())
                .foregroundStyle(Palette.label2)
                .textSelection(.enabled)
        }
        .controlSize(.small)
    }
}
