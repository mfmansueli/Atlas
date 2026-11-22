//
//  MCPToolbox.swift
//  Atlas
//

import Foundation

/// The tools the server offers. A section's tools join `standard` once the
/// section can read and validate what they need.
@MainActor
struct MCPToolbox {
    let tools: [any MCPTool]

    static var standard: MCPToolbox {
        MCPToolbox(tools: [
            ListAppsTool(),
            GetListingTool(),
            ListMissingTranslationsTool(),
            ProposeListingTextTool(),
            GetAppVersionsTool(),
            ProposeAppVersionTool(),
            GetInAppTextsTool(),
            ProposeInAppTextsTool(),
            GetInAppReviewNotesTool(),
            ProposeInAppReviewNoteTool(),
            GetPricesTool(),
            GetPricePointsTool(),
            ProposePricesTool(),
            GetSubscriptionsTool(),
            ProposeSubscriptionTool(),
            GetRetentionTool(),
            ProposeRetentionMessageTool(),
            ProposeRetentionOfferTool(),
            GetPrivacyQuestionnaireTool(),
            ProposePrivacyAnswersTool(),
            GetAgeRatingTool(),
            ProposeAgeRatingTool(),
            GetComplianceTool(),
            ProposeComplianceAnswersTool(),
            GetScreenshotContextTool(),
            ListCapturesTool(),
            MarkCapturesStaleTool(),
            GetCaptureTool(),
            GetTemplateTool(),
            GetCaptionsTool(),
            MeasureCaptionTool(),
            RenderPreviewTool(),
            ProposeTemplateTool(),
            ProposeCaptionsTool(),
            ProposeScreenshotFileTool(),
            ListProposalsTool(),
            GetStorePageTool(),
            GetAppInformationTool(),
            SuggestFieldsTool(),
            WithdrawSuggestionTool(),
            BeginSuggestionsTool(),
            EndSuggestionsTool(),
            GetCapturePlanTool(),
            UpdateCapturePlanTool(),
            ProposeScreensTool(),
            ReportCaptureTool(),
            ReportCaptureProblemTool(),
            ReportRecordingTool(),
            ListRecordingMomentsTool(),
            RerecordMomentTool(),
            RequestRecaptureTool(),
            ProposeArtworkVariantTool(),
            StartDisplayRecordingTool(),
            FinishDisplayRecordingTool(),
            NextStepTool(),
            GetDesignBriefTool(),
            RenderArtworkTool(),
            ProposeDirectionTool(),
            ReviseDirectionTool(),
            ProposeArtworkConceptTool(),
            ReviseArtworkConceptTool(),
            ReviseAppPreviewTool(),
            SetAppPreviewMusicTool(),
            ReportDesignSourceTool(),
            ReportAppSupportTool(),
            AnswerAppQuestionsTool(),
            GetAnalyticsFunnelTool(),
            GetAnalyticsBreakdownTool(),
            GetAnalyticsSubscriptionsTool(),
            AddFindingTool(),
            GetReviewsTool(),
            ProposeReviewRepliesTool(),
            ProposeReviewThemesTool(),
            GetInAppEventsTool(),
            ProposeInAppEventTool(),
            ProposeEventDetailsTool(),
            ReportDeepLinkCheckTool(),
            ProposeEventTextsTool(),
            WithdrawEventTextsTool(),
            RenderEventArtworkTool(),
            ProposeEventArtworkTool(),
            GetEventArtworkBriefTool(),
            ProposeEventArtworkConceptTool(),
            GetProductPagesTool(),
            ProposeProductPageTool(),
            ProposeProductPageTextsTool(),
            GetPageScreenshotsTool(),
            ProposePageScreenshotsTool(),
            ProposePageLookTool(),
            ReportPageCaptureTool(),
            RequestPageRecaptureTool(),
        ])
    }

    func tool(named name: String) -> (any MCPTool)? {
        tools.first { $0.definition.name == name }
    }

    var toolNames: Set<String> {
        Set(tools.map(\.definition.name))
    }

    /// The `tools/list` result.
    var listResult: JSONValue {
        ["tools": .array(tools.map(\.definition.json))]
    }
}
