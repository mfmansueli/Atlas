//
//  AutopilotRecordingTab.swift
//  Atlas
//

import SwiftUI

/// Pick's App Preview recording: the raw take per device and language, on
/// the left, and the moments Claude Code marked, on the right, to choose
/// which go in, with how long that makes the App Preview.
struct AutopilotRecordingTab: View {
    @Bindable var studio: ScreenshotStudioModel
    let run: AutopilotRun
    let isEditable: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: Spacing.small) {
                switches
                AutopilotRecordingPlayer(studio: studio, run: run, width: playerWidth)
                Button("View Larger") { studio.openRecording(run) }
                    .controlSize(.regular)
                    .accessibilityIdentifier("autopilot.recording.viewLarger")
            }
            .fixedSize()
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Spacing.small) {
                        AssistantChip(name: run.clientName(assistant: nil, startsSentence: true))
                        Text(studio.recordingTitle(run))
                            .font(.callout.weight(.semibold))
                            .accessibilityIdentifier("autopilot.recording.title")
                    }
                    Text(studio.recordingIntro(run))
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let moments = studio.pickMoments(run)
                VStack(spacing: 0) {
                    ForEach(Array(moments.enumerated()), id: \.element.screenID) { index, moment in
                        if index > 0 { Divider() }
                        AutopilotMomentRow(studio: studio, run: run, moment: moment, index: index, isEditable: isEditable)
                    }
                }
                .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
                summary
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Contain, so the identifiers inside stay theirs.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilot.pick.recording")
    }

    private var playerWidth: CGFloat {
        studio.currentPickRecording(run)?.displayType == .iPad ? 330 : 176
    }

    @ViewBuilder
    private var switches: some View {
        let devices = studio.pickRecordingDevices(run)
        let current = studio.currentPickRecording(run)
        HStack(spacing: 6) {
            if devices.count > 1, let current {
                FittingSegmentedPicker(
                    label: String(localized: "Device"),
                    options: devices.map { ($0, $0 == .iPad ? String(localized: "iPad") : String(localized: "iPhone")) },
                    selection: Binding(get: { current.displayType }, set: { display in
                        let locale = studio.pickRecordingLocales(run, display: display).contains(current.locale)
                            ? current.locale : studio.pickRecordingLocales(run, display: display).first ?? current.locale
                        studio.showRecording(AutopilotRecordingTarget(displayType: display, locale: locale))
                    })
                )
                .fixedSize()
                .accessibilityIdentifier("autopilot.recording.device")
            }
            // The one language picker (README-DS §12), compact.
            if let current,
               let model = LanguageBarModel.plain(codes: studio.pickRecordingLocales(run, display: current.displayType), current: current.locale)
            {
                LanguagePickerButton(model: model, style: .compact, identifier: "autopilot.recording.language") { locale in
                    studio.showRecording(AutopilotRecordingTarget(displayType: current.displayType, locale: locale.code))
                }
            }
        }
    }

    private var summary: some View {
        let fits = run.pickedPreviewFits
        return HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: fits ? "info.circle" : "exclamationmark.triangle.fill")
                .foregroundStyle(fits ? Palette.label2 : Palette.warnMark)
                .accessibilityHidden(true)
            Text(studio.momentsSummary(run))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(fits ? Palette.fill1 : Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("autopilot.recording.summary")
    }
}
