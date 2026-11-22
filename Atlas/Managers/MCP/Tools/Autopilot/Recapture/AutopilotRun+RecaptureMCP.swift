//
//  AutopilotRun+RecaptureMCP.swift
//  Atlas
//

import Foundation

/// get_capture_plan's `recapture`: in a capture-only run, what's redone
/// (each capture with whether its new one is in) and why.
extension AutopilotRun {
    var recaptureJSON: JSONValue? {
        guard isRecapturing, let recapture else { return nil }
        var json: [String: JSONValue] = [
            "title": .string(recapture.title),
            "captures": .array(recapture.targets.map { target in
                var item: [String: JSONValue] = [
                    "screen": .string(target.screenID),
                    "name": .string(plan.screen(id: target.screenID)?.name ?? target.screenID),
                    "locale": .string(target.locale),
                    "displayType": .string(target.displayType.mcpValue),
                    "done": .bool(isSettled(target)),
                ]
                if let pose = target.duoPose { item["pose"] = .string(pose.rawValue) }
                // The size and way up of the capture it replaces: iPad's
                // landscape 2752 × 2064, iPhone Duo's cover display.
                if let previous = recapture.previousCaptures.first(where: { $0.target == target }) {
                    item["previousPixelSize"] = .string(previous.pixelSize.title)
                    item["orientation"] = .string(previous.pixelSize.isLandscape ? "landscape" : "portrait")
                }
                return .object(item)
            }),
            "note": .string(String(localized: """
            A capture-only run: capture only these (in their locale, on their device) and record only these moments. \
            The plan's other captures stay as they are; next_step asks for what's left.
            """)),
        ]
        if !recapture.momentIDs.isEmpty { json["moments"] = .array(recapture.momentIDs.map(JSONValue.string)) }
        if recapture.madeFromCaptures == true {
            json["fromCaptures"] = .string(String(localized: """
            No Autopilot run was saved: this run was made from the captures the set uses. Capture each one at its \
            previousPixelSize and orientation, in its pose on iPhone Duo; the set keeps its template and captions.
            """))
        }
        if let reason = recapture.reason { json["reason"] = .string(reason) }
        if let evidence = recapture.evidence { json["evidence"] = .string(evidence) }
        return .object(json)
    }
}
