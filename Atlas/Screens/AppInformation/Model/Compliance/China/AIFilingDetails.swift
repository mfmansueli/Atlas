//
//  AIFilingDetails.swift
//  Atlas
//

import Foundation

/// What App Store Connect asks when an app offers AI generation or
/// synthetic content in China mainland: the approved filing number and
/// registered name of its large language model or algorithm, and, when
/// the model is another company's, who authorized the person to use it.
struct AIFilingDetails: Hashable, Codable, Sendable {
    var kind: AIFilingKind = .largeLanguageModel
    var number = ""
    var name = ""
    /// The model or algorithm is another company's, so App Store Connect
    /// also takes their authorization or usage agreement.
    var usesAnotherCompanysModel = false
    /// The company that owns it, as in the CAC's approval registry.
    var technologyOwner = ""

    init(
        kind: AIFilingKind = .largeLanguageModel,
        number: String = "",
        name: String = "",
        usesAnotherCompanysModel: Bool = false,
        technologyOwner: String = ""
    ) {
        self.kind = kind
        self.number = number
        self.name = name
        self.usesAnotherCompanysModel = usesAnotherCompanysModel
        self.technologyOwner = technologyOwner
    }

    /// Every field is optional when decoding, so answers saved before a
    /// field existed still load.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(AIFilingKind.self, forKey: .kind) ?? .largeLanguageModel
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        usesAnotherCompanysModel = try container.decodeIfPresent(Bool.self, forKey: .usesAnotherCompanysModel) ?? false
        technologyOwner = try container.decodeIfPresent(String.self, forKey: .technologyOwner) ?? ""
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The number and name are there, and the owner when it's another
    /// company's model.
    var isComplete: Bool {
        !Self.trimmed(number).isEmpty && !Self.trimmed(name).isEmpty
            && (!usesAnotherCompanysModel || !Self.trimmed(technologyOwner).isEmpty)
    }

    /// The same details with every field trimmed.
    var trimmed: AIFilingDetails {
        AIFilingDetails(
            kind: kind,
            number: Self.trimmed(number),
            name: Self.trimmed(name),
            usesAnotherCompanysModel: usesAnotherCompanysModel,
            technologyOwner: usesAnotherCompanysModel ? Self.trimmed(technologyOwner) : ""
        )
    }
}
