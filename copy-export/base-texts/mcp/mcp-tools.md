# Atlas MCP tools (117)

Extracted from the Swift sources at this commit. `{expr}` marks text interpolated at runtime.

## add_finding

**Title:** Add an Analytics finding  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/AddFindingTool.swift:15`

Adds a finding to an app's Analytics → What to Try, marked as yours: one thing the numbers say is worth changing. Give `title` (what you saw, one sentence, ≤140 characters), `why` (the likely cause and why the fix helps, ≤400), `area` (storePage, screenshots, pricing, retention, inAppTexts, productPages, stability or billing: the section where the fix is made), `howSure` (the counts and range behind it, from the get_analytics_ tools; say when a number is small), `read` (what you read for it: the tools, reports or files, shown under the finding) and up to three `numbers` ({label, value, note}). Optional `locale` or `territory` (alpha-2) opens that section on the right language or country, and `page` a custom product page by name. Only say what the numbers support, and don't repeat a finding get_analytics_funnel already lists. `id` replaces a finding you added before. A finding changes nothing on the App Store: send the fix itself with the propose_ and suggest_ tools.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): What you saw, in one sentence.
- `(nested)` (string): The likely cause, and why the fix should help.
- `(nested)` (string): storePage, screenshots, pricing, retention, inAppTexts, productPages, stability or billing.
- `type` (string): A custom product page's name, for productPages.
- `(nested)` (string): The counts and the range behind it.
- `(nested)` (string): sure, fairlySure or rough. Leave it out for fairlySure.
- `type` (string): A store page locale code such as de-DE, for storePage and screenshots.
- `(nested)` (string): A territory's alpha-2 code such as BR, for pricing.
- `(nested)` (string): The id of a finding you added before, to replace it.
- `showsIn`: title has {title.count} characters; it needs 1 to {Self.titleLimit}.

## answer_app_questions

**Title:** Answer Atlas's questions about the app  
**Source:** `Atlas/Managers/MCP/Tools/AppSupport/AnswerAppQuestionsTool.swift:13`

Tells Atlas what it asked about the app (next_step says answer_app_questions, and get_store_page lists appQuestions): the App Preview's story, what moves in the app, how it should sound, what sets it apart, its voice and what's off limits. Answer from the project, in the app's own words; leave the answer out when the project doesn't say. With music_track and music_reason, also the library track that fits the app: it becomes the App Preview's music unless the person chose one. Atlas keeps the answers for every later run and asks again once they're old.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The question's id.
- `(nested)` (string): The answer; left out when the project doesn't say.
- `(nested)` (string): The library track that fits the app, from musicLibrary.
- `(nested)` (string): Why it fits, in one sentence the person reads.

## begin_suggestions

**Title:** Begin suggesting everything  
**Source:** `Atlas/Managers/MCP/Tools/Suggestions/BeginSuggestionsTool.swift:15`

Starts a Suggest Everything run in Atlas: after reading get_store_page and get_app_information, list every field you'll suggest for the app. Plan entries are {area, locale | page, device, field}, named as in suggest_fields. Returns run, the id to pass to every suggest_fields call; accepted, the total Atlas shows; and skipped, the entries it left out with a code: changed_by_you (the person changed it and hasn't pushed), locked, in_another_request (an Ask for one page is still suggesting it), already_suggested (your suggestion still waits for the person), unknown_field, unknown_locale, not_permitted or invalid_value. Don't send the skipped ones. Suggestions sent with the run outside the plan are added to the total. Call end_suggestions when you're done; the run also ends at the plan's last item. App Compliance and Export Compliance are part of the plan too: {area: info, page: appCompliance, field: <rule>} per regulation get_compliance lists as proposable, and {area: info, page: exportCompliance, field: encryption}; propose_compliance_answers and propose_export_compliance with the run settle them.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The version string, e.g. 1.4, to check it's the one being prepared.
- `items` (string): store or info.
- `(nested)` (string): For store: an App Store Connect locale code, e.g. en-US.
- `(nested)` (string): For info: general, ageRating, accessibility, review, appCompliance or exportCompliance.
- `(nested)` (string): For accessibility: iphone, ipad, watch, vision, mac or tv.
- `(nested)` (string): The field, question or feature, e.g. whatsNew, notes, wellness or voiceOver.

## end_suggestions

**Title:** End suggesting everything  
**Source:** `Atlas/Managers/MCP/Tools/Suggestions/EndSuggestionsTool.swift:13`

Ends a Suggest Everything run once you've sent every suggestion you will. What arrived stays in Atlas for the person to review. Returns the run's status (finished, or stopped when the person stopped receiving) and how many of its fields arrived.

- `run` (string): The run begin_suggestions returned.

## finish_display_recording

**Title:** Get iPhone Duo’s screenshots from the recording  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/FinishDisplayRecordingTool.swift:20`

After start_display_recording and the UI test: stops recording and gives, for each screenshot the test attached (by the name it gave it), iPhone Duo's inner display as it was just before, at full size, as an upload ID, with a small image of each after the JSON, in the same order. Look at each: when it shows its screen, report it with report_capture (upload, screen, displayType iphone_duo, locale, attempt, score, notes).

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The absolute path of the .xcresult you passed to -resultBundlePath.
- `test` (string): {file.pixelSize.width} × {file.pixelSize.height}

## get_age_rating

**Title:** Read the age rating questionnaire  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/GetAgeRatingTool.swift:13`

Returns the age rating questionnaire of an app: each question's id, text, group and the answers it takes (none, infrequent or frequent; or no and yes), the current answer (App Store Connect's, with changes waiting in Atlas on top), and the rating they add up to. Propose answers with propose_age_rating.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.

## get_analytics_after_download

**Title:** Get what people do after the download  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/Reports/GetAnalyticsAfterDownloadTool.swift:12`

Reads Apple's Installations and Deletions, App Sessions and Home Screen Widget Installs reports (a sample: people who share analytics with developers) for the last 7, 28 (default) or 90 days: installs, deletions, the share deleted within 30 days of the download, sessions a week per active device and devices that added a widget, for the whole app and by product page, source, campaign and app version. Rates matter more than counts here. Read-only.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId
- `numbers`: A sample: only people who share analytics with developers.

## get_analytics_breakdown

**Title:** Break the funnel down  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/GetAnalyticsBreakdownTool.swift:12`

Splits an app's funnel by `by`: territory (default), language (the territories whose App Store shows that page), source (App Store Search, Browse, App Referrer, Web Referrer…), device or productPage, for the last 7, 28 (default) or 90 days. Each row has its counts and three rates (viewRate = page views per impression, downloadRate = downloads per page view, startRate = subscription starts per download) with `againstAverage` better/worse/same, said only when the rate's whole 90% range is above or below the app's average. Territory rows also say which language's page they see, whether that page is machine-translated or missing, and the price against purchasing power when known. Apple doesn't link subscriptions to a source or a product page: those are null there. Rows are sorted by impressions; `limit` (default 40) keeps the largest. Read-only.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): territory, language, source, device, productPage, referrer (the app or website people came from) 
- `(nested)` (string): or campaign (a campaign link's ct token). Leave it out for territory.
- `description` (string): appId

## get_analytics_crashes

**Title:** Get crashes by version  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/Reports/GetAnalyticsCrashesTool.swift:12`

Reads Apple's App Crashes and App Sessions reports (a sample: people who share analytics with developers; days complete up to 5 days later): crashes per 1,000 sessions of the newest version against the one before on the same days, whether the newest is clearly worse (`againstPrevious`), by device, and by day. Use it to find what to fix in the code; say it's a sample. Read-only: pausing a phased release is the person's decision, in Atlas.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `previous` (array): day

## get_analytics_funnel

**Title:** Get the App Store funnel  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/GetAnalyticsFunnelTool.swift:12`

Reads an app's funnel from the reports Atlas downloaded from Apple: impressions → product page views → first-time downloads → trial starts → paid starts, for the last 7, 28 (default) or 90 days and the same number of days before. Each step has its count and its rate from the step before with a 90% range; `status: tooFewToTell` means the numbers are too small for a rate, so don't quote one. `againstPrevious` says whether the rate moved for sure (higherSure, lowerFairlySure, aboutTheSame…). Also returns the open findings and `notes` on what's missing: tell the person those. Read-only; it answers from this Mac and never asks Apple. Follow with get_analytics_breakdown to find where a step is weak, then propose the fix with the propose_ and suggest_ tools, and add_finding to say why.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId
- `(nested)` (string): {report.callout.title}. {report.callout.text}

## get_analytics_retention

**Title:** Get retention analytics  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/Reports/GetAnalyticsRetentionTool.swift:12`

Reads what happens when people tap Cancel Subscription, from Apple's Retention Messaging report (every subscriber, not a sample), over the last 7, 28 (default) or 90 complete days: how many opened the cancel screen, stayed and canceled, the save rate (1 − cancels ÷ opened), each retention message's save rate against No Message (Apple's plain screen, the reference), by subscription, and how people stayed (redeemed the offer, switched plan, tapped Don't Cancel). Apple completes a day up to 4 days later: `through` is the last complete day. Use it before propose_retention_message and propose_retention_offer, and never quote a rate marked tooFewToTell. Read-only.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId
- `type` (array): isNoMessage
- `subscriptions` (array): offer
- `stayed` (array): redeemedOffer
- `switchedPlan` (array): saveRate

## get_analytics_subscribers

**Title:** Get subscribers by page, campaign and offer  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/Reports/GetAnalyticsSubscribersTool.swift:12`

Reads Apple's App Store Subscription Event and State reports (every subscriber, not a sample) for the last 7, 28 (default) or 90 days: trials, paid subscribers and trial → paid by product page, campaign and source (where each subscriber downloaded the app from); each offer by name with how many paid the regular price afterwards against the average of every offer (`firstRenewal` when too young to tell); subscribers Apple couldn't charge, recovered and lost to billing; Billing Grace Period on or off; plan changes and cancellation reasons; and, from the newest state day, how many are in a grace period or billing retry. Complements get_analytics_subscriptions (Sales and Trends). Read-only: Billing Grace Period is turned on only by the person, in Atlas.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId
- `subscribers` (array): name
- `started` (array): paidAfterwards
- `rate` (array): firstRenewal

## get_analytics_subscriptions

**Title:** Get subscription analytics  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/GetAnalyticsSubscriptionsTool.swift:12`

Reads an app's subscriptions from Sales and Trends, for the last 7, 28 (default) or 90 days: active subscribers, trial → paid (of the trials that ended in the period), proceeds in US dollars after Apple's commission and taxes, refunds, renewal rates by renewal (1st, 2nd, 3rd and later), cancellations by Apple's reason and how many came before the first renewal, and trial → paid per subscription and per territory. Rates carry a 90% range and `status: tooFewToTell` when they're too small to quote. Use it before propose_prices, propose_retention_message and propose_in_app_texts. Read-only; needs the vendor number and a key that can read sales, and says so when it can't.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId
- `renewed` (array): due
- `count` (array): name
- `active` (array): trialToPaid

## get_analytics_web_preview

**Title:** Get the app's page on the web  
**Source:** `Atlas/Managers/MCP/Tools/Analytics/Reports/GetAnalyticsWebPreviewTool.swift:12`

Reads Apple's App Store Web Preview report for the last 7, 28 (default) or 90 days: how many saw the app's page on apps.apple.com in a browser, and what they tapped there (reviews, privacy details, the developer's website…). Read-only.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId

## get_app_information

**Title:** Get App Information for suggestions  
**Source:** `Atlas/Managers/MCP/Tools/Suggestions/GetAppInformationTool.swift:19`

Reads an app's App Information in Atlas for suggestions, for the newest editable version (else the live one): page general (copyright, primaryCategory, secondaryCategory, gamesSubcategories, secondaryGamesSubcategories, contentRights, release), page ageRating (one entry per question, with its answers), page accessibility (per device, one entry per feature with Apple's meaning, answered Yes or No, and the app's accessibilityUrl in `url`), page appPrivacy (the User Privacy Choices URL, privacyChoicesUrl, per language in `locales`) and page review (contactFirstName, contactLastName, contactPhone, contactEmail, demoAccountRequired, demoAccountName, notes). Each field has its current value, App Store Connect's (`live`) where it differs, its limit, and whether it's locked (the version is in review or live); an unanswered question or feature has value null. Categories, both Games subcategory fields, contentRights and release are picked from `choices`, by id. gamesSubcategories (up to two, comma-separated, e.g. "GAMES_PUZZLE,GAMES_WORD"; "" clears them) can be suggested only while the primary category is GAMES, and secondaryGamesSubcategories (the same, from choices.gamesSubcategories) only while the secondary category is GAMES (`available`). demoAccountRequired is App Review's "Sign-in required", yes or no; demoAccountName is the demo account's user name. The demo account's password is never read or suggested: the person types it in Atlas. accessibilityUrl is one for the whole app (every device), and privacyChoicesUrl is set per language: suggest it with page appPrivacy and that locale. Both are optional full https:// URLs. contentRights is Apple's "{ContentRights.appleQuestion}" (its `question`), for the whole app: third-party content is anything the developer doesn't own, such as fonts, images, sounds or music bundled under a license, or content from other services or other people that the app shows or reaches. Suggest USES_THIRD_PARTY_CONTENT (Apple's "Yes, … and I have the necessary rights") when the project has any and it's licensed or permitted, saying in the reason what it is; the person then confirms the rights in Atlas (`rightsConfirmed`). Suggest DOES_NOT_USE_THIRD_PARTY_CONTENT only when everything the app shows is the developer's own. `suggestions` lists the ones already open with their source. App Store Connect won't create review details without a contact email: when the review contact is empty, suggest it from what the project shows (a support or contact email in the app or its docs, or the git author's name and email), and never make up a phone number. Send suggestions with suggest_fields. Pass `version` with a new version queued with propose_app_version to read it before it's in App Store Connect: its copyright, release and App Review fields start from the version before it and aren't locked, and what suggest_fields sends for them with the same `version` waits with it in Review & Push, as do its categories, both Games subcategories and User Privacy Choices URLs (App Store Connect makes a new app info with the version). contentRights and accessibilityUrl belong to the app, not to a version: they're never locked, and with `version` they're suggested for the app as without, not queued with the new version.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A version, e.g. 1.2: the one being prepared (when left out), or a new one queued with propose_app_version.

## get_app_price_and_availability

**Title:** Get app price and availability  
**Source:** `Atlas/Managers/MCP/Tools/AppPriceAvailability/GetAppPriceAndAvailabilityTool.swift:14`

Reads what an app itself costs to download and where it's sold, as App Store Connect's Pricing and Availability page has them. price.state is "notSet" for an app that has never had a price (it can't be sold until it has one) or "set" with the base territory, today's price there (0 is Free), Apple's proceeds and anything a new price would replace. availability.state is "notSet" for an app without an availability, else the counts, the territories it isn't sold in and whether new territories get it. queuedPrice and queuedAvailability are what waits in Review & Push. Pass territory (and near, a price) to list Apple's price points there: only those can be proposed with propose_app_price. Subscription and in-app purchase prices are get_prices.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): Lists Apple's price points in this territory, e.g. USA or US.
- `description` (string): appId

## get_app_versions

**Title:** Read the app's versions  
**Source:** `Atlas/Managers/MCP/Tools/Versions/GetAppVersionsTool.swift:13`

Returns an app's App Store versions per platform (IOS, MAC_OS, VISION_OS, TV_OS): each version's number and state, the latest number, whether a new version can be created (App Store Connect has one version in progress per platform: not until the current one is released), the number Atlas suggests next, and a new version already waiting in Review & Push. Each version has its `builds` uploaded for that number and platform, newest first (id, buildNumber, processingState PROCESSING/VALID/FAILED/INVALID, uploaded, expired, attached, usesNonExemptEncryption), and `attachedBuild`, the one App Store Connect has attached to it (null when none); `buildsError` when they couldn't be read. An attached build's encryption answer is get_export_compliance's and propose_export_compliance's. Propose a version with propose_app_version; attaching a build and submitting are the person's. A version in `queued` counts as the one being prepared: pass its number as `version` to get_listing, get_app_information, propose_listing_text and suggest_fields to write its texts before the person pushes it.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.

## get_captions

**Title:** Get captions  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/GetCaptionsTool.swift:12`

Reads an app's screenshot captions per locale and slot (from 1): headline, subhead, state (written, edited, reviewed, machine-translated, proposed, or missing) and the headline's fit on iPhone with the current template: fits, size in u, lines, fill and a label such as "1 line too many at 80 u". A missing caption shows the primary locale's.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `type` (string): appId

## get_capture

**Title:** Get capture  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/GetCaptureTool.swift:15`

Returns one capture (a real screenshot of the app, from list_captures) as a PNG image, so you can see the screen a caption describes. Captions should name what the screen shows.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A captureId from list_captures.

## get_capture_plan

**Title:** Get the screenshot capture plan  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/GetCapturePlanTool.swift:13`

Reads the Screenshot Autopilot run the person started in Atlas and picks it up: the screens (id, name, the steps to reach each and the caption it goes with), the devices with their simulator (simulatorName; simulator is ready, making: Atlas is making it, as only the simulator was missing, so don't report it, or needsRuntime: this Mac lacks its runtime, so report it once with report_capture_problem and affectsDevice: true, or couldntMake: Atlas reported why already) and pixel size, the locales with their launch arguments, the simulator setup commands, and the upload URL for captures. A device with simulatorId is captured on that simulator (boot it and pass its id in place of booted), the one Plan showed the person. thisMac says how many simulators this Mac can run at once: go device by device and shut each simulator down when its captures are in, never all of them up front. Build the app, boot the simulator you're on, run the setup, launch the app in each locale (with its sample data in that language when simulatorSetup has sampleDataLanguage) and capture each screen (XCUIScreen or xcrun simctl io booted screenshot). UI tests that capture take the locale's testArguments (xcodebuild test … -testLanguage de -testRegion DE), and any switch they need from their scheme or test plan, never from VAR=value in front of xcodebuild. Upload each PNG with curl to the upload URL and call report_capture; act on any check it returns. Before capturing, go through preflight's checks in the project; next_step gives the rehearsal first (every screen in the primary language and rehearsal.locale), so what breaks in other languages breaks once. When chooseScreens is true, first decide from the project which screens show the app best and send them with update_capture_plan replace: true, the strongest first: the first three are the ones App Store search results show. Otherwise, if the screens have no steps, write them from the project's UI tests, deep links or launch arguments and send them with update_capture_plan first. When appLook's status isn't known, read the app's look and design language in the project first and send it with report_app_support's look, as appLook says: every design in the run starts from it. Pass xcode and simulators so the person sees what you use. simulatorSetup.commands ends with addedByFixes, the commands fixes added; simulatorSetup.notes are instructions fixes left, never run as they are. queuedForNextPlan lists what you or another assistant sent for the next plan that still waits for the person (kind recapture: a request_recapture waiting for Accept): don't send it again. In a capture-only run (recapture), capture only what it lists: the rest of the set stays. When the app's screens changed, don't tell the person to run Autopilot again: ask for just those captures with request_recapture, which works even when no Autopilot run was saved (the run is made from the set's captures). In such a run, each capture's previousPixelSize is the size to match.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID, if you have it.
- `(nested)` (string): The Xcode version you build with, e.g. 26.1.
- `description` (array): displayType

## get_compliance

**Title:** Read App Compliance  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/Compliance/GetComplianceTool.swift:14`

Returns an app's App Compliance page: each regulation (traderStatus for the EU's Digital Services Act, icpFilingNumber, securityAssessment and aiGeneratedContent for China mainland (asked of every app, sold there or not: one not sold there, or stopping sales there, answers No, marked assumed), vietnamGameLicense, medicalDevice), its state (needsAnswer, toEnter, notPushed, passes), what Apple asks, the person's current answer, the answers you may propose with propose_compliance_answers (empty when it takes none, with why), an open suggestion if there is one, and the trader details Atlas prepared from the team's name and App Review's contact. Apple's API takes none of these answers: the person enters them in App Store Connect, except stopping sales in China mainland, which is pushed. Each regulation's pushedAnswers lists the answers that become a change in Review & Push once accepted (stopSelling); every other answer is kept in Atlas until the person enters it in App Store Connect and marks it as declared. Export compliance (encryption) is get_export_compliance.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `name`: Every answer you propose waits on its card until the person accepts it; Accept All never takes them. Accepting stopSelling queues a change in Review & Push; the person enters every other answer in App Store Connect. Never make up an address, a phone number or an ICP Filing Number.
- `answer` (string): regulated
- `answer` (string): needsAssessment

## get_design_brief

**Title:** Get the screenshot design brief  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/GetDesignBriefTool.swift:16`

The brief for designing the Autopilot run's screenshot set: the picked capture of each screen (images attached), every caption in every language with its length, the longest caption per slot, canvas sizes and safe areas per device, right-to-left languages, the design project to use, the starters you can base a direction on, the template fields you can set, and aboutTheApp: its subtitle, categories, description, keywords per language, icon colors and the look the project scan reported (what it does, who it's for, its personality, motifs, what it avoids, theme colors and fonts; lookMissing says to read it first), so each direction is about what this app does and looks like its brand. When the run also makes product page header and search results artwork or an App Preview, extras says which canvases and what each is for, and artworkDesign says how you design the header and search yourself, as HTML pages Atlas renders in every language (the app's icon is attached after the picks); its askedByThePerson, when there, is what the person asked those images to be, and comes first. When the run makes no screenshots, noScreenshots says what to design instead and the screenshot canvases are left out. personNote, when there, is what the person told the designer for the screenshots: every direction follows it. Design around the real captures; never draw the interface. Send each direction with propose_direction.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `what`: Send each direction as a template: the JSON get_template returns (any subset of its fields) and/or ops {op: "replace", path, value} on a base starter. Fonts must be ones Atlas has (system fonts, the bundled gallery fonts, or uploaded); colors are hex. Per-slot looks go in slots[i].over (a whole bg, device.tilt, device.dx/dy, deco…). Laurels and badges show a rating, so only use the app's real App Store rating. Right-to-left languages mirror automatically.
- `name` (string): No design project: {AutopilotRun.ownDesignHow}.
- `(nested)` (string): Atlas doesn't know the app's design language yet. Before designing, read it in the project and send report_app_support with look, then call get_design_brief again: {AppLookProfile.scanHow}
- `(nested)` (string): Make one direction per template in shot_templates, adapting that gallery template (its base and layout) to the app and the design project, named “<Template> · for {result["app"]?.stringValue ?? "the app"}”. The gallery's art props that show a subject ({subjects}) were drawn for its sample app: keep one only where it fits this app, and hide the others (off: true on that decoration). Its hand-drawn marks suit any app.
- `(nested)` (string): the app
- `source`: Don't stop: design the three directions from this brief (and the summary, when there is one), send each with propose_direction, and skip creating them in the design project.
- `length` (string): landscape
- `height`: Atlas lays Apple Vision Pro out itself: the template's background and headline style, the headline centered at the top, the capture in a floating window below. Design for iPhone and iPad.

## get_event_artwork_brief

**Title:** Get the event artwork brief  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/ArtworkStudio/GetEventArtworkBriefTool.swift:23`

Reads the brief the person wrote when they pressed Make the Artwork on an In-App Event in Atlas: what the art should show, the look to start from (`newLook`: three concepts in the app's brand; `template`: Atlas's event layouts in the app's colors; `extendCard`: keep the event's card, attached, and make only the details image to match), whether the event's name is drawn into the art (then write it as {{eventName}} and Atlas draws it in each language), whether a moving version is made, the event's texts, the app's design (look, design project), the art direction (the idea, where the App Store lays its text, the craft and the check of each render), the sizes and rules, the concepts already sent, `otherEvents`: the ideas already drawn for the app's other events, to stay different from, `revision`: the one concept to redraw and what the person asked for, with its images attached, and `addMotion`: concepts to give motion as they are, with `motionDirection` (Apple's rules for event videos and how the loop moves). Render and look at each image with render_event_artwork, then send each concept with propose_event_artwork_concept.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events or the prompt.
- `card`: 3840 × 2160 (16:9)
- `details`: 2160 × 3840 (9:16)
- `name`: attached: the event's card as it is on the App Store. Make the details image to match it.
- `title` (string): Three concepts that are different ideas (for example a wide scene, a close-up of one subject, a gathering of lights or figures), each a card and a details image from one world, recomposed for each frame so they read as a pair. Mark the one you'd choose as pick.
- `(nested)` (string): Three concepts, one from each of the first three layouts here, in {appName}'s colors and its own world. A layout is a composition to start from, not a picture to copy: make each a full scene, crafted as artDirection says. The first suits the event's badge, so events with the same badge share it: what makes the art this event's is its subject, taken from this event's own texts, never the layout alone.
- `(nested)` (string): Keep the attached card as it is. Make three versions of the details image (9:16) that continue it: the same colors, light and subject, recomposed for the tall frame. Send only details.
- `(nested)` (string): none yet: {app.name} has no captures in Atlas. Design from the look and the project.
- `slot`: none yet: design from the look and the project.

## get_export_compliance

**Title:** Read Export Compliance  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/ExportCompliance/GetExportComplianceTool.swift:18`

Returns an app's Export Compliance: the version being prepared and the build attached to it (number and usesNonExemptEncryption, as App Store Connect has it and with what's queued on top; null when no build is attached), the answers (usesEncryption, exempt, containsProprietaryCryptography, containsThirdPartyCryptography, availableOnFrenchStore; null where unanswered) and who gave them, the app's encryption declarations (id, state, codeValue, appDescription and their answers), the changes waiting in Review & Push and an open suggestion. App Store Connect's API takes the build's usesNonExemptEncryption, a new encryption declaration and the build's link to one: propose_export_compliance queues them. It doesn't take the declaration's documents, which the person uploads in App Store Connect when Apple asks. answersFromBuild is true when the answers are only what the build's flag implies (false reads as exempt: it can't tell exempt encryption from none). infoPlistKey says whether builds answer the question themselves through ITSAppUsesNonExemptEncryption: state reported (report_encryption_key), readInProject (Atlas read the app target), inferred (the newest uploads arrived answered, which an answer given per build in App Store Connect also does) or unknown; present, value, how Atlas knows, the last report, expected (the value, build settings and Info.plist lines once the answer is settled), canAdd with whyNot, and next: Add It to the Project on the page starts Claude Code to add it, or add it yourself in the project and report it with report_encryption_key.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `state`: Exempt: encryption only through Apple's operating systems (HTTPS and TLS with URLSession or Network, the Keychain, CryptoKit, CommonCrypto, Data Protection), or none at all; the build then answers usesNonExemptEncryption false and needs no declaration. Not exempt: its own or bundled encryption (OpenSSL, BoringSSL, libsodium, WireGuard, a custom protocol, end-to-end encrypted messaging, a VPN), which needs an encryption declaration. The Info.plist key ITSAppUsesNonExemptEncryption (NO when exempt) answers this for every build uploaded after it's added, and ITSEncryptionExportComplianceCode names an approved declaration's codeValue. Answers with no build attached stay in Atlas until the Submit sheet attaches one.

## get_in_app_events

**Title:** Get In-App Events  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/GetInAppEvents/GetInAppEventsTool.swift:24`

Reads an app's In-App Events from App Store Connect, all of them or one (`eventId`), with the parts you ask for (`include`: texts, media, mediaDetails, review, deepLinkCheck, design, push, queued, or all). Without include, every part but the two heaviest, mediaDetails and design: `leftOut` names them, ask for them when you need them (with eventId to keep the answer small). Each event comes with its id, reference name, badge, state, dates, primaryLocale, deepLink, purpose and priority (null when App Store Connect has none), purchase requirement, and its texts per language (name ≤30 characters, shortDescription ≤50, longDescription ≤120). `missingLanguages` are the store page's languages the event isn't written in yet (people there see the primary language), less those with a suggestion waiting (`suggestedLanguages`; `openSuggestions` has each with its texts, who sent it (`by`; a revision of a written language has `revision: true` and `revises`, only the texts it changes). Reading settles the suggestions as In-App Events does: one whose texts App Store Connect has already is done and leaves, and a new language's texts sent before that language was written become a revision of the texts that differ, its why starting "Suggested before this language was written:"; `stale` and `staleSuggestions` name any left that would add nothing (withdraw your own with withdraw_event_texts) or texts waiting in Review & Push (`queuedTexts`: per language, its changeId(s), newLanguage when the push creates it, waitingForAcceptance, by, and the queued name, shortDescription and longDescription). Only events with `editable: true` take new texts. `media` says, per language, whether it has its own card (16:9) and details page (9:16), as an image or a video, or shows the primary language's; `mediaDetails` has the same per language and kind as App Store Connect gives it (fileName, fileSize, isVideo, width, height, previewFrameTimeCode, imageUrl, state, shownFrom when it's the primary language's), with `atlasFile` when it was uploaded from a file Atlas still has, `matchesQueued` the queued changes sending that same file, and `sameAsPrimary` on a language's own copy of the primary's; `stillMissing` lists what no language shows yet (both are needed to submit the event) and the languages without their own; `queuedArtwork` is art waiting in Review & Push, each with the file Atlas will send: `path` on this Mac (open it to see exactly what goes), `fileSize`, `width`/`height`, a video's `seconds` and `previewFrameTimeCode`, `fileExists`, `languageCreatedByPush` when its language is created by the same push, the file's `originalName`, `sha256` and `origin` (from: makeTheArtwork with conceptId and title, render_event_artwork with page, upload or imageBase64 with name, chooseFiles), `sameAsPrimary` when it's the primary language's art again (with `copyNeeded` false where the language shows the primary's without it: those are in `identicalCopies` for the person to take out), `alreadyInAppStoreConnect` when that language has this file already, and `pushStatus` while a push has it. `queuedArtworkSummary` groups the queued art by kind and file with its languages. `pushInProgress` is true while Review & Push is pushing; `pushChanges` are this app's In-App Event changes in that push (or the one just finished) with their status: queued, sending (progress), done, failed (reason), conflict or notSent (reason). `queued` are the new events waiting in Review & Push, not created yet: their reference names are taken too. `artworkUpload` is this launch's link for sending a card or details page file made elsewhere (POST the bytes, `?name=` the file name). `design` is what the art is designed from: the app's look and design language, what Atlas knows of the app, its design project if one is connected, and `how` to make each piece as an HTML page Atlas renders, still or as a seamless loop. `missingForReview` lists what App Store Connect still needs before it takes the event to App Review (deepLink, primaryLocale, purpose, dates, primaryTexts, languageTexts, card, details, linkNotClaimed), each `missing`, `queued` in Review & Push or `suggested` (waiting for the person to accept it), with `readyForReview`; `queuedDetails` are the deep link, purpose, priority and primary language changes waiting; `deepLinkClaim` says whether the app's project (its folder in Atlas) declares the deep link's URL scheme or applinks domain; `deepLinkCheck` is the last report_deep_link_check for the deep link the event will have (null when not checked), `stale: true` with `staleReason` once the event's start or end moved since it was made (`checkedDates`): check it again. Dates (showsFrom, starts, ends) are as App Store Connect has them, checked at the time you read: missingForReview also lists a date App Store Connect would refuse (publishStartPassed and eventStartPassed: it only takes dates in the future; eventEndBeforeStart, eventTooShort, eventTooLong, publishStartAfterEventStart, publishStartTooEarly), each with `fix` and, for the card's date, `suggested` (a publishStart that works, ISO 8601); `reviewWarnings` say when App Review (up to 2 days; the event shows only once it's approved) may not approve it before its card shows (cardShowsSoon) or it starts (eventStartsSoon): they never block. `queuedDates` are dates waiting in Review & Push (`by` who queued them; `suggestion` an assistant's dates waiting beside the person's, to accept or dismiss); `datesEditable` says whether propose_event_details can change them (else `datesNotEditable` says why). Read-only. Follow with propose_event_texts for the missing languages, render_event_artwork and propose_event_artwork for the art, propose_event_details for a missing deep link, purpose or primary language or dates to fix, or propose_in_app_event for a new event.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): One event's id, to read only that one.
- `enum` (string): appId
- `appReviewUsuallyTakesHours`: {app.name} · {events[0].referenceName}
- `media`: not read for archived events

## get_in_app_review_notes

**Title:** Get In-App Review Notes  
**Source:** `Atlas/Managers/MCP/Tools/InAppTexts/ReviewNotes/GetInAppReviewNotesTool.swift:12`

Reads the Review Notes of each subscription and in-app purchase (App Store Connect's Review Information › Review Notes): what App Review reads about a product, e.g. what it unlocks and how to test it. One note per product, not localized. Per product: `note` (App Store Connect's with anything queued on top), `live` (App Store Connect's, when a queued change differs) and who queued it, `state`, and `writesTo`: "current", "next review submission" (approved: it's sent with the product's next review) or "locked: with App Review". `limit` is 4,000 characters. Change one with propose_in_app_review_note, e.g. in the same task that changes what a purchase unlocks.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.

## get_in_app_texts

**Title:** Get In-App Texts  
**Source:** `Atlas/Managers/MCP/Tools/InAppTexts/GetInAppTextsTool.swift:12`

Reads an app's In-App Texts in Atlas: the subscription group's display name and each subscription's and in-app purchase's display name and description, per locale, shown on the purchase sheet and in Settings → Subscriptions. `columns` lists each text's id (group.name, <productId>.name, <productId>.description) and its limit. Per locale, `texts` has the current text (App Store Connect's with anything queued on top), `live` App Store Connect's where a queued change differs, `missing` the columns still empty, and `states` what App Review would reject in a text, per column: propose a version without it. `textRules` lists App Review's rules for these texts. App Store Connect needs at least one group name localization before a subscription can be added for review, and a name to create a locale. Pass `locales` to read only some. Propose texts with propose_in_app_texts. Each product's Review Notes for App Review (one per product, not localized) are read and proposed with get_in_app_review_notes and propose_in_app_review_note.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `type` (string): appId

## get_listing

**Title:** Get store listing  
**Source:** `Atlas/Managers/MCP/Tools/Listing/GetListingTool.swift:17`

Reads an app's store listing in Atlas: the newest editable version (else the live one, which is read-only), its primary locale, and each locale's texts with anything waiting in review laid on top. `states` says which fields are missing, over the limit, machine-translated, already proposed or would be rejected by App Review (rewrite those). `storeTextRules` lists App Review's rules to follow in every text. `fields` gives each field's level and limit: name, subtitle and privacyPolicyUrl belong to the app; promotionalText, description, keywords (comma-separated, counted in bytes), whatsNew, supportUrl and marketingUrl belong to the version. `glossary.keepUntranslated` lists terms to leave as they are, and `glossary.tone` the tone to write in. Pass `locales` to read only some, and `fields` to read only some fields (name, subtitle, description, keywords, promotionalText, whatsNew, privacyPolicyUrl, supportUrl, marketingUrl, or urls for the three URLs): a whole listing in many languages is large, mostly its descriptions, so ask for what you need, e.g. fields: ["whatsNew"] for release notes; `fieldsNotInThisVersion` names the ones asked for that this version doesn't have (a first version has no whatsNew). `languagesNotOnAppStore` lists the languages the app's project supports and its App Store page doesn't have yet: suggest their texts with suggest_fields; only the person adds their pages. Pass `version` with a new version queued with propose_app_version (get_app_versions' `queued`) to read it before it's in App Store Connect: its fields start from the version before it and are editable, `version.queued` is true, and texts proposed for it with propose_listing_text or suggest_fields (with the same `version`) wait with it in Review & Push.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A version, e.g. 1.2: the one being prepared (when left out), or a new one queued with propose_app_version.
- `enum` (string): appId

## get_page_screenshots

**Title:** Get a product page's screenshot run  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageShots/GetPageScreenshotsTool.swift:25`

Reads a custom product page's screenshot run in Atlas (Make Screenshots for This Page): who the page is for (`page.audience`, the brief, keywords and promotional text), the default set's screens (`screens`, numbered from 1, with their captions in the primary language and their captures attached in order), the template the set is laid out with, the page's languages (primary first) and devices, and the run: its stage, the plan so far and `changeRequest`, what the person asked to change. Plan the page's own set from it and send it with propose_page_screenshots: the screens in the order that tells this page's story and a caption for each in every language. `look` says how the set looks: when its choice is claudeDesign, send three looks with propose_page_look. `recapture`, when the person turned on Capture Screens Again, has the upload link for screens captured again in the Simulator, named with report_page_capture (`requested` lists the screens a request_page_recapture asked for). To capture some screens again when it isn't on, ask with request_page_recapture instead of telling the person to turn it on. The default page's screenshots never change.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's name or id, from the prompt or get_product_pages.
- `headline` (array): name
- `locale` (array): screen
- `headline` (array): subhead

## get_page_tests

**Title:** Get Product Page Optimization tests  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageTests/GetPageTestsTool.swift:18`

Reads an app's Product Page Optimization (A/B) tests of the header and search results artwork. tests: App Store Connect's tests (testId, name, state, isOver, trafficProportion, reviewRequired, startDate, endDate), with the treatments, languages and placed artwork (assetId) of the tests not over, or of the one testId names; noTests says so when there are none. results is always null: the API doesn't give results (resultsNote). inProgress is the test in the way of a new one (one at a time). testable, per placement (header, searchResults): the artwork Autopilot made (languages, those still waiting in Review & Push), the run's variant (change, languages, errors) or why there's none, and library: images already in the app's App Asset Library a treatment can use (assetId, size, the locale its name carries). proposals: the tests assistants proposed and their status (pending, made, dismissed, withdrawn). Then propose one with propose_page_test.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): Read this test's treatments too, even when it's over.

## get_price_points

**Title:** Get price points  
**Source:** `Atlas/Managers/MCP/Tools/Pricing/GetPricePointsTool.swift:15`

Lists Apple's price points for one product in one territory around today's price, or around `near`: each point's customer price and proceeds (Small Business Program rate, after tax) in the territory's currency. Only these prices can be proposed with propose_prices. A subscription without a price in the United States yet lists its US points only (current is null): its US price sets its starting price.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The product's Apple ID, product ID or name, from get_prices.
- `(nested)` (string): A territory code such as BRA or BR, or its name.
- `description` (string): appId

## get_prices

**Title:** Get prices  
**Source:** `Atlas/Managers/MCP/Tools/Pricing/GetPricesTool.swift:21`

Reads an app's subscription and in-app purchase prices in every territory: today's price and proceeds, Atlas's suggestion with its reason (when the app shows suggestions) and any price waiting in review, plus the app's pricing mode (keepPrices, showSuggestions or applyRecommended). Apps set to keepPrices refuse every price proposal. Pass productId to read one product; `hint` explains the fields.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A product's Apple ID, product ID or name. Leave it out for every product.

## get_privacy_questionnaire

**Title:** Read the App Privacy questionnaire  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/GetPrivacyQuestionnaireTool.swift:14`

Returns Apple's App Privacy questionnaire for an app: the definitions of collect, linked to the user and tracking, every data type with its id, category, fastlane key and privacy-manifest key, the six purposes, the confidence levels, the answers already in the app's worksheet (with who gave them), the open questions and the person's answers to earlier ones (answeredQuestions, with the types each answer changed). App Store Connect has no API for App Privacy: answers you propose with propose_privacy_answers go into Atlas's worksheet, where the person reviews each one and enters them in App Store Connect themselves. Calling this shows the person that a scan has started.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `bundleId`: App Store Connect has no API for App Privacy. Your answers go into Atlas's worksheet as suggestions; the person reviews each one, then copies them into App Store Connect. Suggestions aren't legal advice.

## get_product_pages

**Title:** Get custom product pages  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/GetProductPages/GetProductPagesTool.swift:22`

Reads an app's custom product pages as Atlas's Product Pages section shows them. `defaultPage` is the page every custom one is compared with and starts from: the version it starts from, the last approved version (whose keywords pages choose), its promotional text per language and its numbers. `keywords` has, per language, the approved version's keywords still `free` and the ones a page uses (`usedBy`: keyword → page name): a keyword leads to one page. `pages` are App Store Connect's pages and the drafts made in Atlas (state `draft`, not in App Store Connect until the person pushes): id, name, url, visible, state (PREPARE_FOR_SUBMISSION, WAITING_FOR_REVIEW, IN_REVIEW, APPROVED, REJECTED…), `newVersion` when a version after the approved one is being prepared or reviewed, deepLink, `languages` with their own promotional text, keywords and screenshots (`textFromDefault` when only the text is the default page's), `showsDefaultIn` the languages with nothing of their own, `numbers` for the last 28 days (impressions, pageViews, downloads, downloadRate, and `vsDefault`: above or below by points, aboutTheSame, or tooFewToCompare under 200 page views: never quote a rate then; `arrivals`, where the page's link is used: campaign tokens and referring apps or sites, most page views first), `queued` (changes waiting in Review & Push, not pushed), `takesTexts` (false with `why`; `newVersionNote` for an approved page), and `brief`: who an accepted suggestion's page is for and the screenshots it asked for (`screenshotsAdded` stays false until the page has its own in App Store Connect: the person makes them with Make Screenshots for This Page, which asks you to plan them with get_page_screenshots). `suggestions` are the pages and promotional texts suggested over MCP with their status (open, notOffered: stopped by App Review's rules, dismissed: don't suggest them again) and who sent them (`by`). `pageLimit` is pages of 70 (drafts, hidden and rejected ones count) and the room left with the suggestions waiting. `textRules` are the rules texts follow, and `next` what to do. `pageId` reads one page with its texts when the list leaves them out. Read-only. Follow with propose_product_page or propose_product_page_texts.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): Only this page (an id from pages), with its texts. Leave it out for every page.

## get_release

**Title:** Read the release  
**Source:** `Atlas/Managers/MCP/Tools/Release/GetReleaseTool.swift:16`

Returns, per platform, the version on its way to the App Store (being prepared, with App Review, approved or rolling out; else the one live): its state and phase (prepare, waiting, review, rejected, pending = approved and waiting for the person, approved = Apple releases it, phased, live), releaseType (MANUAL, AFTER_APPROVAL, SCHEDULED with earliestReleaseDate), phasedRelease (state ACTIVE/PAUSED/COMPLETE, day of 7, percentage of automatic updates), the review submission (state, submittedDate, items: the version and the In-App Events in it), attachedBuild, and possibleActions now. Before submitting (and after a rejection) also builds (newest first; only VALID ones that haven't expired can be chosen), defaultBuildId, whatsNew per language (missing, suggested, notPushed), encryption (the answer known for the default build, null when none), reviewInformationComplete, pendingChanges in Review & Push (they're pushed with the submission), offeredEvents that could go with it, and submitBlockers. A rejected version has rejection: App Review's message isn't in the API, so ask the person. `proposals` lists the release actions proposed for the app (pending, outdated with whyOutdated, confirmed, dismissed, withdrawn, replaced). Propose one with propose_release_action.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): IOS, MAC_OS, VISION_OS or TV_OS; every platform when left out.
- `name`: Submitting, releasing and every other action are the person's: propose one with propose_release_action and it waits on the Overview's version card until they confirm it.

## get_retention

**Title:** Get retention messages  
**Source:** `Atlas/Managers/MCP/Tools/Retention/GetRetentionTool.swift:16`

Reads an app's retention messages: what subscribers see on Apple's Confirm Cancellation screen after they tap Cancel Subscription. Returns each message (id, referenceName, status draft/queued/inReview/live/rejected, kind message/image/offer, the subscriptions that show it, header and body by locale with their lengths, missing languages and what keeps it from being pushed), the retention offers by subscription, the subscriptions (id, productId, name, duration, US price, the message it shows), the languages (sourceLocale first) and Apple's limits: header ≤66 and body ≤144 characters, 10 messages an app, 10 offers a subscription. Use it before propose_retention_message and propose_retention_offer.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.

## get_reviews

**Title:** Get App Store reviews  
**Source:** `Atlas/Managers/MCP/Tools/Reviews/GetReviewsTool.swift:16`

Reads an app's written App Store reviews from every country, newest first: each with its id, territory, rating, title and body as written, the language Atlas detected, the version reviewed, the reply already on the App Store (if any) and a reply already suggested. `show` picks needsReply (default: no reply yet and under 5 stars), low (1–2 stars), replied or all; `limit` is 60 unless given (200 at most). Also returns the counts, the app's current version and the groups sent before. Read-only. Follow with propose_review_replies (one reply per review, in the reviewer's language) and propose_review_themes (the subjects people write about). Ratings without text aren't here: Apple's API only has written reviews.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): needsReply (default), low, replied or all.
- `description` (string): appId
- `(nested)` (string): {matching.count - limit} more match; raise limit to read them.
- `on` (string): With each reply send waitTopics (bug, billing, account, featureRequest, personal) and unsure. 
- `(nested)` (string): The person's rule decides what goes out; you never send and can't change it.

## get_screenshot_context

**Title:** Get screenshot context  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/GetScreenshotContextTool.swift:14`

Reads what an app's localized App Store screenshots are made of in Atlas: the display types templates render (iphone 6.9″, ipad 13″) and their pixel sizes, the slots (numbered from 1) and their names, the locales in scope (each gets its own screenshots), the primary locale's captions, the listing's name and subtitle, and the template version. Captions are short marketing headlines drawn above or below a real screenshot of the app; they must fit the template, so check them with measure_caption before proposing. fileUploadURL and fileSizes are for propose_screenshot_file (a file for one screenshot, never scaled); setsChangedByHand lists the sets the person changed by hand. Pass locale and displayType to read that set as the language page shows it (`set`): each screenshot's position (from 1), id and what made it (template, a file, or live on the App Store), for propose_screenshot_file, propose_screenshot_removal and propose_screenshot_order.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The version string, e.g. 1.4. Leave it out for the version being prepared.
- `(nested)` (string): With displayType: the language whose set to list, e.g. de-DE.
- `(nested)` (string): With locale: iphone, iphone_duo, ipad, mac, watch or vision_pro.
- `name` (array): locale
- `screenshots` (array): deletedOnPush
- `fileName` (optionalString): locale

## get_store_page

**Title:** Get Store Page for suggestions  
**Source:** `Atlas/Managers/MCP/Tools/Suggestions/GetStorePageTool.swift:15`

Reads an app's Store Page in Atlas for suggestions: the newest editable version, its primary locale, and per locale each field's current text, App Store Connect's text where it differs (`live`), and the suggestions already open for it with their source, so you don't repeat them. `fields` gives each field's limit in characters or bytes (keywords count bytes) and whether it's editable. Pass `version` to check it's the one you mean, and `locales` to read only some. `languagesNotOnAppStore` lists the languages the app's project supports and its App Store page doesn't have yet (reported with report_app_support): suggested ones are in `locales` with `new: true` and no texts, so suggest every field for them in that language; added ones (`new: true`, created when the person pushes) too. Their pages are created only when the person adds them. `storeTextRules` lists App Review's rules to follow in every text, and a locale's `states` the fields whose text already breaks one: suggest a version that doesn't. Send suggestions with suggest_fields.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The version string, e.g. 1.4, or a new version queued with propose_app_version. Leave it out for the editable version.
- `type` (string): appId
- `editable`: If you can read the app's project, answer these with answer_app_questions: Atlas keeps the answers for every later suggestion and run.

## get_subscriptions

**Title:** Get subscriptions  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/GetSubscriptionsTool.swift:15`

Reads what an app sells in App Store Connect: each subscription group (id, referenceName) with its subscriptions (id, productId, name, duration, state, price in the United States, introductoryOffer, promotionalOffers, winBackOffers and offerCodes with every attribute, their territories, US price, territoryPrices priced apart (promotional offers), custom codes and one-time code batches, queuedOffers waiting in Review & Push, reviewScreenshot), its in-app purchases (type, state, offerCodes with every attribute, territories, US price, custom codes and one-time code batches, queuedOffers, reviewScreenshot), and the new subscriptions (queued, each with the queuedOffers that wait for it) and in-app purchases (queuedInAppPurchases) already waiting in Review & Push. reviewScreenshot.state MISSING keeps a product in Missing Metadata. Use it before propose_subscription, propose_in_app_purchase, propose_introductory_offer, propose_promotional_offer, propose_win_back_offer, propose_offer_code, propose_in_app_purchase_offer_code and propose_purchase_review_screenshot; reviewScreenshotUploadURL is where review screenshots go first, offerDurations lists the durations each offer mode takes and offerRules the offers' limits.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `subscriptions`: letters, digits, _ and ., up to 64
- `(nested)` (string): Reference names, identifiers and offer code names are only seen by the developer. A custom code is typed by customers: no other platforms, betas or placeholders.
- `(nested)` (string): {offer.summary} · {offer.territories.title}
- `state` (string): UNKNOWN
- `(nested)` (string): {offer.summary} · {offer.territories.title}

## get_template

**Title:** Get screenshot template  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/GetTemplateTool.swift:11`

Reads an app's screenshot template: one JSON document for every locale and display type, with sizes in u (the canvas's short side ÷ 1320), the caption's text styles and fit rules, fonts and per-script fallbacks, right-to-left rules, the device frame, and per-slot overrides under slots.<n>.over (n from 0 here). Paths in propose_template are the dotted paths of this JSON, e.g. caption.headline.size. Also returns the history of versions. Pass version for an older one.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): appId

## list_apps

**Title:** List apps  
**Source:** `Atlas/Managers/MCP/Tools/Apps/ListAppsTool.swift:12`

Lists every app in the App Store Connect account open in Atlas: appId (the Apple ID other tools take), name, bundleId, sku, primaryLocale, pricingMode (showSuggestions, applyRecommended or keepPrices; price proposals are refused for keepPrices) and pendingCount (changes waiting in review).


## list_captures

**Title:** List captures  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/ListCapturesTool.swift:12`

Lists the captures (real screenshots of the app) each locale in scope uses, per display type and slot (from 1). localizedUI is false when a locale has none of its own and shows the primary locale's interface. capturedAt is when it was imported or captured; stale is true when it was marked out of date (mark_captures_stale), with staleReason. Pass captureId to get_capture to see one. When some no longer show the app as it is, ask to redo just those with request_recapture instead of a whole Autopilot run.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): iphone, iphone_duo or ipad. Leave it out for all three.
- `(nested)` (string): A locale code such as de-DE. Leave it out for every locale in scope.

## list_missing_translations

**Title:** List missing translations  
**Source:** `Atlas/Managers/MCP/Tools/Listing/ListMissingTranslationsTool.swift:12`

Lists the store-listing fields that are empty in a locale while the primary locale has text, for the newest editable version of an app: per locale, each field with its source text in the primary locale and its limit. Fields already proposed or waiting in review don't count as missing. URLs (copyAsIs) are copied, not translated. Translate each field and send it with propose_listing_text.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `type` (string): appId
- `fields` (string): Version {listing.version.versionString} is read-only, so only name, subtitle and privacyPolicyUrl can be proposed until the person creates a new version.

## list_proposals

**Title:** List screenshot and release proposals  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/ListProposalsTool.swift:15`

Lists the screenshot proposals sent for an app, oldest first: proposalId, kind (template or captions), the template version a template proposal is based on, and status: pending, stale (based on an older template version; the person rebases or discards it), accepted, partial or rejected. pageTests lists the Product Page Optimization tests proposed with propose_page_test, when there are any. releaseProposals lists the release actions proposed with propose_release_action, oldest first, when there are any: proposalId (rp-…), action, title, versionString, platform, client, reason, status (pending, confirmed, dismissed, withdrawn or replaced) and when it was received and settled. Withdraw your own pending one with withdraw_suggestion or withdraw_release_action and its proposalId.

- `appId` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `proposals` (string): stale

## list_recording_moments

**Title:** List an App Preview recording's moments  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ListRecordingMomentsTool.swift:13`

Lists the moments of the run's App Preview recording on a device in a language: id (the screen), screen, start_s, end_s and reason, as marked in report_recording (or from when each screen appears), with chosen (it goes in the App Preview: 6 s each plus a 6 s end card, within Apple's 15–30 s) and recordAgain (the person asked for it again: record it and send it with rerecord_moment before the design step).

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): iphone or ipad; the first recording's device when left out.
- `(nested)` (string): The recording's locale; the primary language when left out.

## mark_captures_stale

**Title:** Mark captures out of date  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/Recapture/MarkCapturesStaleTool.swift:14`

Marks captures (real screenshots of the app, as list_captures has them) out of date because the app changed under them, with the reason and evidence (a file or commit) the person reads. Each item of targets is a slot (from 1) or a screen's name, a locale, and a displayType (left out: every device). Screenshots → Captures labels them Out of date and list_captures returns stale with the reason, until a new capture takes their place. To have them captured again, ask with request_recapture.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): Instead of slot: the slot's name, e.g. Today.
- `(nested)` (string): The locale, e.g. ja.
- `(nested)` (string): iphone, iphone_duo, ipad or mac; leave out for every device.
- `(nested)` (string): What changed, in a sentence the person reads.
- `(nested)` (string): What shows it: a file or commit.

## measure_caption

**Title:** Measure caption  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/MeasureCaptionTool.swift:14`

Measures a caption on a slot (from 1) with Atlas's fit engine, the same one the renders use: {fits, size, lines, maxLines, fill, label, glyphsMissing}. Sizes are in u; the headline shrinks from the template's size to its smallest before it overflows. Pass displayType (iphone, the default, or ipad) and templatePatch to measure against a template change you're considering.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A locale code such as de-DE.
- `description` (string): The headline to measure.
- `(nested)` (string): A subhead, for slots that show one.
- `(nested)` (string): iphone, iphone_duo or ipad.
- `description` (string): appId

## next_step

**Title:** Ask Autopilot what's next  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/NextStepTool.swift:12`

Says what the app's Screenshot Autopilot run wants from you now: capture (with the targets left and problems to retry with their fix), wait (the person is picking or choosing, or Atlas is making a simulator this Mac lacks: don't report that one; ask again after retryAfterSeconds), design (get_design_brief then propose_direction; with prompts, the header and search concepts with propose_artwork_concept, and with Motion loop each concept's motion prompt, its animated pages with revise_artwork_concept), revise_direction or revise (the person's note; revise_artwork_concept for concepts), animate_header and revise_loop (the chosen header's loop, with revise_artwork_concept), write_captions (missing or too long, then propose_captions with run), revise_app_preview (the person's note on the App Preview, then revise_app_preview), answer_app_questions (what Atlas wants to know about the app, then answer_app_questions), choose_screens (the plan has none yet, then update_capture_plan), or done. Call it after each step until it says done.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.

## propose_age_rating

**Title:** Propose age rating answers  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/ProposeAgeRatingTool.swift:15`

Proposes answers to an app's age rating questionnaire: answers: [{question, answer, why, evidence}], with question ids and answers from get_age_rating, evidence as "file:line — finding" strings, and could_not_see for what you couldn't check. Each answer is queued in Atlas (status "queued") and waits until the person confirms it; "unchanged" means App Store Connect already has it; "refused" says why. Nothing reaches App Store Connect until the person pushes.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A question id from get_age_rating, e.g. userGeneratedContent.
- `(nested)` (string): none, infrequent, frequent, no or yes.
- `(nested)` (string): Why, in a sentence the person can check.
- `description` (string): What the code can't show, e.g. content on your servers.
- `changeId`: Each answer waits in Atlas until the person confirms it on the Age Rating page.

## propose_app_price

**Title:** Propose the app's price  
**Source:** `Atlas/Managers/MCP/Tools/AppPriceAvailability/ProposeAppPriceTool.swift:15`

Proposes what an app itself costs to download: price in the base territory's currency (0 or "free" for Free), one of Apple's price points there (get_app_price_and_availability with territory lists them), and territory, the base territory (the current one, else USA). Every other territory gets Apple's equalized price. It's queued in Review & Push (status "queued") as a new price schedule starting when the person pushes; it replaces any prices set by hand elsewhere and scheduled changes. A price that isn't a point is refused with the nearest ones; "unchanged" means it's already the price. A paid price needs the Paid Applications agreement, which Atlas can't check: say so in reason when the app wasn't paid before. Give a reason and evidence (e.g. the project's paywall or a README).

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): The base territory, e.g. USA or US.
- `(nested)` (string): Why this price, in a sentence the person can check.
- `description` (string): appId
- `status` (optionalStrings): evidence

## propose_app_version

**Title:** Propose a new app version  
**Source:** `Atlas/Managers/MCP/Tools/Versions/ProposeAppVersionTool.swift:15`

Proposes a new App Store version: versionString (one to three whole numbers, higher than the latest, e.g. the project's MARKETING_VERSION), platform (IOS, MAC_OS, VISION_OS or TV_OS; IOS when left out and the app has it), and a reason with evidence. It's queued in Review & Push (status "queued") and App Store Connect creates it, in Prepare for Submission, when the person pushes. Its texts can be written in the same task, before it exists: pass its versionString as `version` to get_listing, get_app_information, propose_listing_text and suggest_fields (What's New, description, keywords, App Review notes…). They wait with it, go into it right after it's created, and are discarded with it. "unchanged" means it's already queued; "refused" says why, e.g. a version still in progress on that platform.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): e.g. 1.5
- `(nested)` (string): IOS, MAC_OS, VISION_OS or TV_OS.
- `(nested)` (string): Why this number, in a sentence the person can check.
- `description` (string): appId
- `versionString` (optionalStrings): evidence
- `(nested)` (string): It waits in Review & Push until the person pushes; App Store Connect then creates it in Prepare for Submission. Write its texts now: pass version "{version.versionString}" to get_listing, propose_listing_text, get_app_information and suggest_fields, and they go into it right after it's created.

## propose_artwork_concept

**Title:** Propose a header and search concept  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/Concepts/ProposeArtworkConceptTool.swift:14`

Sends one header and search concept for the Autopilot run, apart from the screenshot directions (next_step's design action hands you the prompts). concept is one item of the concepts prompt's answer, as you wrote it; send each as soon as it's written, and the person sees it on the Design step. artworkDesign carries its pages, one self-contained HTML page per canvas (the pages prompt): send them with the concept, or later with the same concept id. Atlas renders each in the primary language and checks it like propose_direction, and returns the images. Refused, with what to fix, for a template the person didn't pick or another concept took, a kind another concept has (going freely), a missing follows_the_request when the person asked for something, text besides the name and phrases, or a page that doesn't render or breaks Apple's rules.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): How the concept follows what the person asked (get_design_brief's artworkDesign.askedByThePerson); the concept's follows_the_request works too.
- `description` (optionalString): followsTheRequest

## propose_artwork_variant

**Title:** Send a Product Page Optimization variant  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ProposeArtworkVariantTool.swift:14`

When next_step says design_variant: the variant for that placement, as html (the whole page, when next_step gives the currentPage) or else as template fields and/or ops laid on the current artwork's look (get_design_brief's extras describe the canvases), changing ONE idea only, the one next_step names (by default the current image shows the interface doing the task, the variant the outcome or feeling). Say the change in a sentence. When the idea is the words, pass texts [{locale, headline}] for every language too, and for a page phrase (data-al="text") that isn't one of next_step's translatedPhrases, phrases [{phrase, locale, text}] for every language but the primary one. The phones still show the real picked captures. Atlas renders and checks it in every language; the person creates the test from Review & Push.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The variant's whole page, when the current image is a page (next_step's currentPage).
- `description` (string): The one idea changed, in a sentence.
- `type` (optionalArray): texts
- `languages`: Nothing more: the person creates the test from Review & Push. Call next_step.

## propose_availability

**Title:** Propose where the app is sold  
**Source:** `Atlas/Managers/MCP/Tools/AppPriceAvailability/ProposeAvailabilityTool.swift:31`

Proposes where an app is sold. For an app without an availability (get_app_price_and_availability: availability.state "notSet"), it queues its first one: territories ("all" by default, or codes), availableInNewTerritories (default true) and an optional pre-order until preOrderReleaseDate (YYYY-MM-DD, 2 to 180 days away, for an app that isn't released yet). App Store Connect can't remove an availability once it's set up. For an app that has one, makeAvailable and makeUnavailable queue one change per territory. Changes wait in Review & Push (status "queued") until the person pushes; "unchanged" means nothing would change, and "refused" says why. Give a reason and evidence.

- `status`: They wait in Review & Push until the person pushes.

## propose_captions

**Title:** Propose captions  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/ProposeCaptionsTool.swift:14`

Proposes screenshot captions, each {locale, slot (from 1), headline, subhead?}. Each item is measured against the current template on iPhone and iPad and refused when it doesn't fit (the reason says by how much, e.g. "needs 3 lines at 72 u; the template allows 2"), when the font can't draw it, when the locale is unknown, or when App Review would reject it: pricing such as “free”, prices, discounts or trials (Guideline 2.3.7), other platforms (2.3.10), beta or demo (2.2), placeholders (2.1), “coming soon” (2.3) or “For Kids” (2.3.8). The others are queued together in Atlas's Proposals sheet; nothing changes until the person accepts them, and accepted captions read "Proposed by" you until someone edits them. Keep brand names and the glossary's terms untranslated. During a Screenshot Autopilot run, when next_step asks for write_captions, pass the run's ID as run: the captions are saved right away instead of queued, and the run checks them again. When it asks for write_artwork_texts, send items {locale, placement: search or header, headline} with run instead of slots: the search results image's and the header's own texts (an empty header headline removes its line). For placement text, add phrase: one of the pages' phrases as next_step gave it, in the primary language, with its words in that locale as headline.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `enum` (string): Why, in a sentence or two the person reads before accepting.
- `(nested)` (string): A short title, e.g. Shorter German captions.
- `(nested)` (string): An Autopilot run's ID, when next_step asked for write_captions.
- `items` (optionalString): title

## propose_compliance_answers

**Title:** Propose App Compliance answers  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/Compliance/ProposeComplianceAnswersTool.swift:19`

Proposes answers to an app's App Compliance page: answers: [{rule, answer, why, evidence}] with the rules and answer names get_compliance lists as proposable. traderStatus takes trader (with traderDetails: name, address, phone, email; fields you leave out keep the prepared ones) or nonTrader; icpFilingNumber takes icpNumber (with icpNumber) or stopSelling; securityAssessment takes needsAssessment (features like sharing AI-generated content or end-to-end encrypted messaging) or noAssessment; aiGeneratedContent takes offersAI (chatbots, image or video generation, voice or face changes; with aiFiling {kind: largeLanguageModel or algorithm, number, name, technologyOwner when it's another company's model}, as far as the project shows it) or noAI (none, or off or geoblocked in China mainland); medicalDevice takes regulated or notRegulated. Never make up a filing number. Evidence is "file:line — finding" strings; could_not_see says what the project can't show. Each answer waits in Atlas (status "queued") until the person accepts it; "unchanged" means it's already their answer or your open suggestion; "refused" says why. What accepting does (each result's pushedWhenAccepted): stopSelling becomes a change in Review & Push that takes the app off sale in China mainland when the person pushes (changeId, the same change propose_availability's makeUnavailable CHN queues, so they never double up). Apple's API takes no other answer: trader or nonTrader, icpNumber, needsAssessment or noAssessment, offersAI or noAI, regulated or notRegulated stay in Atlas, and the person enters them in App Store Connect and marks them as declared. Pass run (from begin_suggestions) during Suggest Everything.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): traderStatus, icpFilingNumber, securityAssessment, aiGeneratedContent or medicalDevice.
- `(nested)` (string): trader, nonTrader, icpNumber, stopSelling, needsAssessment, noAssessment, offersAI, noAI, regulated or notRegulated.
- `(nested)` (string): The company or person selling, as on legal pages.
- `(nested)` (string): The postal address, only if the project shows it.
- `(nested)` (string): Only if the project shows it.
- `(nested)` (string): A contact email.
- `(nested)` (string): e.g. {ICPFilingNumber.example}
- `(nested)` (string): largeLanguageModel or algorithm.
- `(nested)` (string): The CAC's approved filing number, only if the project shows it.
- `(nested)` (string): The registered filing name, only if the project shows it.
- `(nested)` (string): The company whose model it is, when it isn't the person's own.
- `(nested)` (string): Why, in a sentence the person can check.
- `description` (string): What the project can't show, e.g. whether you sell as a business.
- `(nested)` (string): The Suggest Everything run begin_suggestions returned, if this is part of one.
- `status` (object): unchanged
- `answer`: Each answer waits on its card in App Compliance until the person accepts it. Accepting stopSelling queues a change in Review & Push that the person pushes; every other answer stays in Atlas, and the person enters it in App Store Connect and marks it as declared, since Apple's API doesn't take it.

## propose_direction

**Title:** Propose a screenshot design direction  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ProposeDirectionTool.swift:13`

Sends one design direction for the Autopilot run: a name ("Quiet Indigo"), a one-sentence rationale, and the screenshots' template — the JSON get_template returns (any subset of its fields) and/or ops on dotted paths — laid on a base starter (above, band or panorama). When the run also makes header and search artwork, artworkDesign carries them: one HTML page per canvas that you design completely (get_design_brief's artworkDesign says how); Atlas renders each in the primary language, checks it and returns the images, so look at them. When the person said what they expect (artworkDesign.askedByThePerson), the images must show it, and followsTheRequest says how. extrasTemplates.appPreview can give the App Preview's captions a look of their own. When the run makes no screenshots (get_design_brief's noScreenshots), leave base, template and ops out unless they style its App Preview. In a run whose next_step hands you prompts, the header and search are concepts sent with propose_artwork_concept instead, and artworkDesign is refused here. Refused, with what failed, for unknown template fields, values out of range, fonts that can't draw a language, a missing page, a page that doesn't render or breaks Apple's rules, words written outside data-al (they'd read the same in every language), or a missing followsTheRequest. Pass sourceLink to the direction in the design project so the person can open it there.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The direction's name, e.g. Quiet Indigo.
- `(nested)` (string): Why, in a sentence the person reads.
- `(nested)` (string): above, band or panorama.
- `description` (string): Where to refine it, e.g. the Claude Design project's link.
- `(nested)` (string): Required when get_design_brief has artworkDesign.askedByThePerson: in a sentence, what in this direction's header and search shows what the person asked (e.g. "three of their motivational phrases on the header, one on search").

## propose_event_artwork

**Title:** Propose In-App Event artwork  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/Artwork/ProposeEventArtworkTool.swift:21`

Queues an In-App Event's card (16:9) and/or details page (9:16), checked with render_event_artwork first. `artwork` is a list of {kind: card|details, fileId, locales, posterSeconds}: `fileId` from render_event_artwork or the upload link; `locales` the languages to upload it into, left out: the event's primary language only (Apple shows the primary language's art in every language without its own), "all": every language the event has; `posterSeconds` a video's poster frame. A language whose texts wait in Review & Push as new (get_in_app_events' queuedTexts with newLanguage) can be named too: its upload waits for the push to create it. The same file as the primary language's art (same SHA-256, queued or already in App Store Connect) isn't queued again for a language that has no card or details page of its own: `sameAsPrimary` lists those, as they show the primary's already; it is queued where it replaces the language's own art or other art waiting for it. Each file is checked again: one with a refusal isn't queued, and a language the event doesn't have yet is skipped (add its texts with propose_event_texts first). Each language becomes one change in Review & Push that waits for the person to look at it and accept it in the event's media card; pushing uploads it and replaces that language's card or details page. Proposing the same kind and language again replaces the waiting one. `status` is queued, notNeeded (every language named already shows it) or refused. Nothing is pushed or submitted for review here.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events.
- `type` (string): appId
- `sameAsPrimary`: Nothing to queue: those languages already show the primary language's art. Never push or submit it yourself.
- `title` (string): In-App Events (⌘5) → {event.referenceName} → Images and video, and Review & Push
- `note`: “{event.referenceName}” is with App Review: its art can change once the review is over.

## propose_event_artwork_concept

**Title:** Propose an event artwork concept  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/ArtworkStudio/ProposeEventArtworkConceptTool.swift:25`

Sends one concept for the In-App Event artwork the person asked for with Make the Artwork in Atlas (read it with get_event_artwork_brief first). A concept is the card (16:9) and the details image (9:16) from one composition, or only the details image when the brief extends the card. Give each as a full HTML page (`cardHtml`, `detailsHtml`), or as a file render_event_artwork made or one sent to the upload link (`cardFileId`, `detailsFileId`): a render's file keeps its page. Atlas renders the pages at 3840 × 2160 and 2160 × 3840 (with {{eventName}} drawn in each language when the brief has wordsInArt, and as a 20-second loop when it has motion), checks them under the event's text and shows them to the person. `name` is two or three words, `why` one sentence on the idea for the person, `pick` true on the one you'd choose. When the brief has a revision, send only that concept again with `replaces`. Refused when a render breaks Apple's rules: fix it and send it again. Nothing is queued or pushed: the person chooses and uses one in Atlas.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id.
- `(nested)` (string): The concept's name, two or three words, e.g. Snowfall Path.
- `(nested)` (string): One sentence for the person: the idea, and why it reads at card size.
- `description` (string): The card as a full HTML page, 16:9.
- `(nested)` (string): The details image as a full HTML page, 9:16.
- `(nested)` (string): The card as a file from render_event_artwork or the upload link, instead of cardHtml.
- `(nested)` (string): The details image as a file from render_event_artwork or the upload link, instead of detailsHtml.
- `(nested)` (string): The conceptId being redrawn or given motion, from the brief's revision or addMotion.
- `(nested)` (string): {$0.title}: {$0.detail}
- `(nested)` (string): Done: the person chooses in Atlas. Finish without pushing anything.
- `(nested)` (string): Give the next concept its motion ({motionLeft} left), with replaces.
- `(nested)` (string): Send the next concept ({left} left).
- `(nested)` (string): Send the next concept ({left} left), a different idea from otherEvents' too.
- `refusals` (optionalString): {kind.mcpValue}Html

## propose_event_details

**Title:** Propose an In-App Event's details  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/Details/ProposeEventDetailsTool.swift:26`

Proposes details of an existing In-App Event that's still editable (draft, ready for review or rejected; see get_in_app_events' `editable`): deepLink (where Open on the card goes: a universal link https://… on a domain in the app's Associated Domains, or the app's own scheme myapp://…; App Store Connect won't take the event to App Review without one), purpose (APPROPRIATE_FOR_ALL_USERS, ATTRACT_NEW_USERS, KEEP_ACTIVE_USERS_INFORMED or BRING_BACK_LAPSED_USERS), priority (HIGH or NORMAL), primaryLocale (a language the event is written in, e.g. en-US), and its dates: publishStart (from when the card shows), eventStart and eventEnd, ISO 8601 with a time zone (2026-11-21T18:00:00Z or 2026-11-21T15:00:00-03:00). Send only the ones to change; a date left out stays as it will be (queued, else App Store Connect's). Dates are checked at the time you send them: all in the future (App Store Connect refuses a date that has passed: "Supplied date must be in the future"), the event lasting 15 minutes to 31 days, the card showing at most 14 days before the start and no later than it; get_in_app_events' missingForReview says which date is wrong and `suggested` gives a publishStart that works. The dates go as one change keeping the event's countries and regions, refused when Atlas doesn't know them (datesEditable false). When the person already queued dates of their own (get_in_app_events' queuedDates with `by` not you), yours never replace them: omitted dates come from theirs, and yours wait beside them as a suggestion (status "suggested", with personsDates) that the person accepts or dismisses; sending dates again replaces it. Each change is queued in Review & Push, waiting for the person to accept it; a value App Store Connect would refuse is refused with how to fix it (status "refused"). `warning` says when App Review (up to 2 days; the event shows only once it's approved) may not approve it before its card shows or it starts; it doesn't block. Before proposing a deep link, check in the project that the app opens it on this event, and report what you found with report_deep_link_check. Nothing reaches App Store Connect until the person pushes.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events.
- `(nested)` (string): Where Open goes: https://alba.app/events/new-year or alba://events/new-year.
- `(nested)` (string): APPROPRIATE_FOR_ALL_USERS, ATTRACT_NEW_USERS, KEEP_ACTIVE_USERS_INFORMED or BRING_BACK_LAPSED_USERS.
- `(nested)` (string): HIGH or NORMAL.
- `(nested)` (string): A language the event is written in, e.g. en-US.
- `(nested)` (string): From when the card shows, ISO 8601 with a time zone: in the future, at most 14 days before eventStart.
- `(nested)` (string): When the event starts, ISO 8601 with a time zone, e.g. 2026-11-23T00:00:00Z: in the future.
- `(nested)` (string): When it ends, ISO 8601 with a time zone: 15 minutes to 31 days after eventStart.
- `(nested)` (string): Why, in one sentence, for the person.
- `description` (string): appId
- `changeId` (string): The event’s page in In-App Events and Review & Push → {builder.group(event)}, waiting for the person to accept it

## propose_event_texts

**Title:** Suggest an In-App Event's texts  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/ProposeEventTextsTool.swift:19`

Suggests an In-App Event's texts in more languages, shown in Atlas's In-App Events with Accept, Dismiss and Accept All Languages. `texts` is a list of {locale, name (≤30 characters), shortDescription (≤50), longDescription (≤120), why}: all three written in that language, natural rather than literal (a winter event isn't one where December is summer), in the voice of that language's store page. `why` is one sentence for the person on why it reads this way (≤240). Over a limit, that language is refused with its count: shorten it and send it again. A language get_in_app_events lists in `queuedTexts` already has texts waiting in Review & Push and is refused: leave it. Only events that get_in_app_events marks editable take texts. Sending a language again replaces its waiting suggestion. get_in_app_events' `openSuggestions` shows what waits and who sent it, `stale` once App Store Connect has that language written; take your own back with withdraw_event_texts. To change a language that's already written (an editable event's: draft, ready for review or rejected), e.g. a description that names a day the event no longer ends on, send revise: true (for the call, or on a text object) with only the texts to change and why, required: the others stay as they are, the same rules and limits apply, and `revised` gives each change against the current text (`marked`: [-removed-]{+added+}). The person sees Now and Suggested with the changed words marked, and accepts, edits or dismisses it. Accepted texts wait in Review & Push; nothing reaches App Store Connect until the person pushes. {StoreTextGuidelinePlace.eventText.summary}

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events.
- `type` (string): appId
- `reason` (string):  Fix it and send that language again.
- `skipped` (string): In-App Events (⌘5) → {event.referenceName}

## propose_export_compliance

**Title:** Propose export compliance  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/ExportCompliance/ProposeExportComplianceTool.swift:35`

Proposes an app's export compliance answers from the project, with why and evidence (file:line). Send usesEncryption; with it exempt (only encryption in Apple's operating systems: HTTPS and TLS through URLSession or Network, CryptoKit, CommonCrypto, the Keychain); when not exempt, also containsProprietaryCryptography, containsThirdPartyCryptography and availableOnFrenchStore, and appDescription (how the app uses encryption) unless declarationId names one of get_export_compliance's declarations with the same answers. Queued in Review & Push as yours: the build's usesNonExemptEncryption, and when it isn't exempt an encryption declaration linked to the build (an existing one with the same answers is reused). The answers and evidence show on the Export Compliance page, where the person confirms or rejects them. With no build attached the answers wait in Atlas (status "kept") and the Submit sheet sends them. Apple reviews a new declaration and may ask for documents, which the person uploads in App Store Connect. "unchanged" means nothing would change; "refused" says why.

- `status` (optionalString): why
- `linksBuild`: Waiting in Review & Push as yours until the person pushes; the answers and your evidence show on the Export Compliance page, where they confirm or reject them.

## propose_in_app_event

**Title:** Propose In-App Event  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/ProposeInAppEventTool.swift:62`

Proposes a new In-App Event for an app, queued in Atlas's Review & Push as “Create “<referenceName>”” for the person to review. Read get_in_app_events first: reference names are unique, so leave the ones its events and `queued` events have. badge is LIVE_EVENT, PREMIERE, CHALLENGE, COMPETITION, NEW_SEASON, MAJOR_UPDATE or SPECIAL_EVENT; purpose APPROPRIATE_FOR_ALL_USERS (default), ATTRACT_NEW_USERS, KEEP_ACTIVE_USERS_INFORMED or BRING_BACK_LAPSED_USERS; priority NORMAL (default) or HIGH; purchaseRequirement NO_COST_ASSOCIATED (default) or IN_APP_PURCHASE. publishStart, eventStart and eventEnd are ISO 8601 dates and times with a time zone: the event starts in the future and lasts 15 minutes to 31 days, and its card shows in the future, at most 14 days before it starts. App Review usually takes up to 2 days and the event shows only once it's approved, so a card or start within 2 days comes back with a `warning` (not a refusal): leave App Review time. texts are by locale, name ≤30, shortDescription ≤50 and longDescription ≤120, all three per language: usually the primary language; write the others with propose_event_texts once the event is created. Anything App Store Connect would refuse is refused with the reasons (status "refused"); proposing your own queued reference name again replaces it. Give deepLink (where Open on the card goes) when you know it: the event is created without one, but App Store Connect won't take it to App Review until it has one (set it later with propose_event_details). Nothing reaches App Store Connect until the person pushes, and the person adds the card and details page images and submits the event for review: no tool does either. {StoreTextGuidelinePlace.eventText.summary}

- `reasons`: The event card image or video (16:9, 1920×1080 to 3840×2160), added in App Store Connect.
- `(nested)` (string): Review & Push → In-App Events · New, as {change.title}

## propose_in_app_purchase

**Title:** Propose In-App Purchase  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/PurchaseSetup/ProposeInAppPurchaseTool.swift:42`

Proposes a new in-app purchase for an app, e.g. a lifetime unlock its StoreKit code buys that App Store Connect doesn't have yet (see get_subscriptions' inAppPurchases and queuedInAppPurchases). type is NON_CONSUMABLE, CONSUMABLE or NON_RENEWING_SUBSCRIPTION. The product ID must be exactly the one the app's code uses; it can't be changed or reused once created. displayName (≤30) and description (≤45) are written in locale (the app's primary language when left out); price is its price in the United States in US dollars, and every other territory gets Apple's equalized price; it's available everywhere. reviewScreenshot is the App Review screenshot (without one it stays in Missing Metadata): send the file to get_subscriptions' reviewScreenshotUploadURL and pass the fileId. Anything App Store Connect would refuse is refused with the reasons (status "refused"). An accepted proposal is queued for the person to review (status "queued"); proposing the same productId again replaces it. Nothing reaches App Store Connect until they push. {StoreTextRules.inAppSummary}

- `reasons` (optionalStrings): evidence

## propose_in_app_purchase_offer_code

**Title:** Propose In-App Purchase Offer Code  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/InAppPurchaseOfferCodes/ProposeInAppPurchaseOfferCodeTool.swift:79`

Proposes an offer code for an in-app purchase App Store Connect has (consumable, non-consumable or non-renewing subscription): the purchase for free or at a lower price, for people who redeem a code (in the App Store, in the app or by link). price is the US price in US dollars (0 for free), equalized everywhere else; territoryPrices sets some apart and territories limits where it runs. customerEligibilities says who can redeem it, by what they've bought in the app. It can come with a customCode and a batch of oneTimeCodes, made after it when the person pushes. An in-app purchase has up to 10 active offer codes. action add_custom_code and add_one_time_codes add codes to one it has; deactivate turns an offer code, or one of its custom codes or batches, off for good. A subscription's offer codes use propose_offer_code. Anything App Store Connect would refuse is refused with the reasons (status "refused"); an accepted proposal is queued for the person (status "queued"). Paid codes are refused for apps set to Keep my prices. Nothing reaches App Store Connect until they push.


## propose_in_app_review_note

**Title:** Propose In-App Review Note  
**Source:** `Atlas/Managers/MCP/Tools/InAppTexts/ReviewNotes/ProposeInAppReviewNoteTool.swift:12`

Proposes a subscription's or in-app purchase's Review Notes (App Store Connect's Review Information › Review Notes), from get_in_app_review_notes: for App Review only, one per product, not localized. Update it in the same task that changes what a purchase unlocks (e.g. new MCP tools a purchase opens), so review reads what's true. The store text rules don't apply: the notes may mention a $0 trial or Guideline 3.1.1. Send productId and note (and a reason with evidence), or several with notes: [{productId, note, reason, evidence}]. Refused (status "refused", with code and reason): over 4,000 characters (over_limit), empty (empty), a product the app hasn't (unknown_product), notes the person changed and hasn't pushed (changed_by_person), or a product with App Review (locked). Accepted notes are queued in Review & Push as the assistant's (status "queued", with writesTo: "next review submission" for an approved product); nothing reaches App Store Connect until the person pushes.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The product ID, e.g. com.SimProps.complete (or its column, com.SimProps.complete.reviewNote).
- `(nested)` (string): The whole Review Notes, within 4,000 characters.
- `(nested)` (string): One sentence: why it changes.
- `items` (string): The product ID.
- `(nested)` (string): The whole Review Notes.
- `(nested)` (string): Why it changes.
- `kind` (string): git, code, release, …
- `ref` (string): What to look at.
- `productId`: Those are already the notes, in App Store Connect or queued; nothing new was queued.

## propose_in_app_texts

**Title:** Propose In-App Texts  
**Source:** `Atlas/Managers/MCP/Tools/InAppTexts/ProposeInAppTextsTool.swift:13`

Proposes an app's In-App Texts: the subscription group's display name (column group.name) and each subscription's and in-app purchase's display name and description (<productId>.name, <productId>.description), from get_in_app_texts. Send one with locale, column and text, or several with proposals: [{locale, column, text}]. Each is checked like a manual edit: over the limit, empty, an unknown column or locale, or a text the person already changed is refused with the reason (status "refused"). So is a text App Review would reject (get_in_app_texts' textRules): a price, “free” or a discount, a subscription's trial length, another platform, placeholder text, “coming soon” or “For Kids”, with the rule and the phrases in `issues`; an in-app purchase may still be named “XX-day Trial” (Guideline 3.1.1). Accepted proposals are queued for the person to review in Atlas (status "queued"); a locale App Store Connect doesn't have yet is created when they push, and needs a name (blockedReason says so). Nothing reaches App Store Connect until they push. For a product's Review Notes for App Review (e.g. when a release changes what it unlocks), use propose_in_app_review_note.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): An App Store Connect locale code, e.g. de-DE.
- `(nested)` (string): The column id, e.g. group.name or lumen.monthly.description.
- `(nested)` (string): The proposed text, within the column's limit.
- `(nested)` (string): An App Store Connect locale code.
- `(nested)` (string): The column id.
- `(nested)` (string): The proposed text.
- `column`: That's already the text in App Store Connect or in review; nothing new was queued.

## propose_introductory_offer

**Title:** Propose Introductory Offer  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/PurchaseSetup/ProposeIntroductoryOfferTool.swift:49`

Proposes an introductory offer for new subscribers of one subscription: FREE_TRIAL, PAY_AS_YOU_GO or PAY_UP_FRONT, for a duration (THREE_DAYS…ONE_YEAR; get_subscriptions' offerDurations lists which each mode takes). It works for a subscription App Store Connect has (one without an introductory offer, see get_subscriptions' introductoryOffer) and for a new one still queued by propose_subscription, which the push creates first. A paid offer's price is in US dollars and equalized everywhere else; it must be below the subscription's price. territories defaults to everywhere the subscription is sold. Anything App Store Connect would refuse is refused with the reasons (status "refused"); an accepted proposal is queued for the person to review (status "queued"), and proposing again replaces it. Paid offers are refused for apps set to Keep my prices (a free trial sets no price). Nothing reaches App Store Connect until they push.

- `(nested)` (string): {offer.summary} · {offer.territories.title}
- `(nested)` (string): It's one more step of the new subscription's change: the push creates the subscription, then the offer.
- `(nested)` (string): When the person pushes, App Store Connect gets the offer in each country or region it runs in.
- `reasons` (string): mode

## propose_listing_text

**Title:** Propose store text  
**Source:** `Atlas/Managers/MCP/Tools/Listing/ProposeListingTextTool.swift:14`

Proposes text for store-listing fields of an app's newest editable version (name, subtitle and privacyPolicyUrl also when only the live version exists). Send one field with locale, field and text, or several with proposals: [{locale, field, text}]. Each proposal is checked like a manual edit: over the limit, not an https URL, a locale the app doesn't have or a read-only field is refused with the reason (status "refused"); fix it and propose again. Text App Review would reject is refused too, with issues [{kind, guideline, phrases}]: pricing such as “free”, prices, discounts or trials (2.3.7), other platforms (2.3.10), other apps' names or unverifiable claims in the name, subtitle or keywords (2.3.7), beta or demo (2.2), placeholders (2.1), “coming soon” (2.3) or “For Kids” (2.3.8); get_listing's storeTextRules has them all. Accepted proposals are queued for the person to review in Atlas (status "queued"); nothing reaches App Store Connect until they push. Fields: {ListingField.mcpNames.joined(separator: ", ")}. Pass `version` with a new version queued with propose_app_version to write its texts (whatsNew, description, keywords…, and name, subtitle and privacy URLs, which only change with a new version) before it's in App Store Connect: they wait with it in Review & Push, go into it right after Atlas creates it, and are discarded with it.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A version, e.g. 1.2: the one being prepared (when left out), or a new one queued with propose_app_version.
- `(nested)` (string): An App Store Connect locale code, e.g. de-DE.
- `(nested)` (string): The field, e.g. subtitle or whatsNew.
- `(nested)` (string): The proposed text, within the field's limit.
- `(nested)` (string): An App Store Connect locale code.
- `(nested)` (string): The field.
- `(nested)` (string): The proposed text.
- `field`: The person changed this field too. Both versions wait in Review & Push, where they pick one.

## propose_offer_code

**Title:** Propose Offer Code  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/Offers/ProposeOfferCodeTool.swift:73`

Proposes an offer code for a subscription App Store Connect has, or a new one still queued by propose_subscription (the push creates the subscription first; discarding it discards the code): free time or a lower price people redeem with a code (in the App Store, in the app or by link). mode, duration, numberOfPeriods and price (US dollars, equalized everywhere else; territoryPrices sets some apart) work as in propose_introductory_offer; customerEligibilities says who can redeem it. It can come with a customCode and a batch of oneTimeCodes, made after it when the person pushes. A subscription has up to 10 active offer codes. action add_custom_code and add_one_time_codes add codes to one it has; deactivate turns an offer code, or one of its custom codes or batches, off for good. Anything App Store Connect would refuse is refused with the reasons (status "refused"); an accepted proposal is queued for the person (status "queued"). Paid offers are refused for apps set to Keep my prices. Nothing reaches App Store Connect until they push.


## propose_page_look

**Title:** Propose a look for a product page's screenshots  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageShots/ProposePageLookTool.swift:21`

Sends one of three looks for a custom product page's own screenshots, when the person chose A new look from Claude Design in Make Screenshots for This Page (get_page_screenshots' look.choice is claudeDesign): a name ("Quiet Indigo"), a one-sentence rationale, and the template — the JSON get_template returns (any subset of its fields) and/or ops on dotted paths — laid on base: default (the default page's template) or a starter. Atlas checks it like an edit in the template editor (unknown fields, values out of range and fonts that can't draw a language are refused), draws the page's first screenshot with it and attaches the image: look at it. A look sent again with the same name takes the place of the one before. At most three; the person chooses one. The default page's screenshots never change.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's name or id, as get_page_screenshots has it.
- `(nested)` (string): The look's name, e.g. Quiet Indigo.
- `(nested)` (string): Why it suits this page's audience, in a sentence the person reads.
- `(nested)` (string): default (the default page's template), or a starter from get_page_screenshots' look.starters.
- `description` (string): Where to refine it, e.g. the Claude Design project's link.

## propose_page_screenshots

**Title:** Plan a product page's screenshots  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageShots/ProposePageScreenshotsTool.swift:18`

Sends the plan of a custom product page's own screenshots after get_page_screenshots: `angle` (the page's story in a sentence, ≤200 characters), `reason` (why this order and these words for this audience, ≤300), `screens` in the page's order [{screen, captions: {locale: {headline, subhead}}}], each `screen` one of the default set's, numbered from 1, at most 10, and `languages` (the ones you think need the page's own images; the primary is always among them). Every screen needs a caption in the primary language. Atlas checks each caption against App Review's rules and the template's caption box on every device; one that fails is left out and listed in `refused` with why, and a primary caption that fails refuses the whole plan. Each screen keeps the captions Atlas has for it unless you send them again, wherever it moves (one that no longer fits its new place is left out and listed), so send the other languages a few at a time with the same screens; a screen you leave out goes with its captions. You can't push: the person makes the set, looks at it and puts it in Review & Push.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's name or id, as get_page_screenshots has it.
- `(nested)` (string): The page's story in a sentence, e.g. “Privacy first: the lock, then writing, then search.”
- `(nested)` (string): Why this order and these words, for this page's audience.
- `headline` (string): The headline.
- `subhead` (string): The subhead, optional.
- `description`: The screenshots in the page's order.

## propose_page_test

**Title:** Propose a Product Page Optimization test  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageTests/ProposePageTestTool.swift:23`

Proposes a Product Page Optimization (A/B) test of the header or the search results image, from get_page_tests: name (or Atlas names it "Header: Interface vs Outcome"), placement (header or searchResults: one per test), trafficProportion (percent of visitors who see the treatment, 1–100, default 50), treatment (variant: the Autopilot run's variant for that placement, see testable.variant; library: images already in the app's library, with assets [{locale, assetId}] from testable.library), locales (default: every language the treatment has), startsTest (true sends it to App Review once made; default false keeps a draft), and a reason with evidence. It waits in Review & Push for the person, who opens it prefilled and creates it; status "queued" with proposalId. With treatment variant and no variant yet, Atlas asks the run for one (variant: "asked"): call next_step, design it, send it with propose_artwork_variant. Refused (status "refused", code, reason) while another test isn't over (Apple runs one at a time), for a variant with Apple's errors, a language the treatment lacks, or a library image that isn't processed or the right size. Sending the same placement again replaces your open proposal. action: deleteDraft with testId queues deleting a draft test as a change in Review & Push (a running test can't be stopped through the API); action: withdraw with proposalId takes back your own pending proposal.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): The test's name in App Store Connect, up to 64 characters.
- `locale` (string): e.g. de-DE
- `assetId` (string): From testable.library.
- `description` (string): Why this test, in a sentence the person reads.
- `description` (string): deleteDraft: the draft's testId from get_page_tests.
- `(nested)` (string): withdraw: your proposal's id.
- `kind` (string): analytics, reviews, design, …
- `ref` (string): What to look at.
- `code` (optionalString): placement
- `header` (optionalArray): assets

## propose_prices

**Title:** Propose prices  
**Source:** `Atlas/Managers/MCP/Tools/Pricing/ProposePricesTool.swift:12`

Proposes new prices for one subscription: send territory and price, or several with prices: [{territory, price}]. Prices are in the territory's currency and must be one of Apple's price points (get_price_points); a price between points is refused with the two nearest ones. Each proposal is queued for the person to review in Atlas (status "queued"); nothing reaches App Store Connect until they push. Today's price is "unchanged" and withdraws your earlier proposal for that territory. A subscription without a price in the United States yet takes only its US price, queued as its starting price: Apple equalizes it in every other country or region. Unknown territories or products, in-app purchases and every price for an app set to Keep my prices are refused (status "refused") with the reason.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The subscription's Apple ID, product ID or name, from get_prices.
- `(nested)` (string): A territory code such as BRA or BR.
- `description` (string): A territory code.
- `description` (string): appId

## propose_privacy_answers

**Title:** Propose App Privacy answers  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/ProposePrivacyAnswersTool.swift:16`

Proposes App Privacy answers for an app into Atlas's worksheet, where the person reviews each one. Send collects (the first question), answers: [{type, collected, purposes, linked, tracking, confidence, rationale, evidence: [{kind, sdk, version, entry, path, line, excerpt}]}] with ids from get_privacy_questionnaire, open_questions: [{id, question, affects, if_yes: {summary, collected, purposes, linked, tracking}, if_no: {...}}] for what the code can't show (such as what a server keeps), and scan: {repository, commit, sdks, manifests_read, tracking_signals, could_not_see}. When the person answers a question, that answer's collected, purposes, linked and tracking become the answer of every type in affects, as the person's own, and collects turns Yes when one becomes collected; an if_yes or if_no with only a summary changes nothing, so give collected whenever an answer changes the types. get_privacy_questionnaire returns the answers in answeredQuestions. Each answer is "queued" (waits for review), "conflict" (the person answered differently; they pick), "unchanged" or "refused" with the reason: fix it and send it again. Set final: false while more calls follow; the scan ends with the last call.

- `status`: The person answered this type differently. Both answers are shown; they pick one.
- `status` (array): refused
- `status` (array): queued
- `(nested)` (string): sdk_manifest, dependency, info_plist, entitlement or code.
- `(nested)` (string): The SDK, e.g. RevenueCat.
- `(nested)` (string): The SDK's version, e.g. 5.14.2.
- `(nested)` (string): The manifest key or dependency, e.g. NSPrivacyCollectedDataTypePurchaseHistory.
- `(nested)` (string): The file, relative to the repository.
- `description` (string): A short excerpt of the code or manifest.
- `(nested)` (string): e.g. Email Address becomes collected, linked, for App Functionality.
- `type` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `description` (string): A data type id from get_privacy_questionnaire, e.g. purchases.
- `enum` (string): Why, in a sentence the person can check.
- `items` (string): A stable id, e.g. q1.
- `(nested)` (string): A yes-or-no question for the person.
- `type` (string): e.g. northpier/lumen.
- `(nested)` (string): The commit you read.
- `items` (string): The SDK.
- `(nested)` (string): Its version.
- `type` (string): What you found about tracking.
- `(nested)` (string): What the code can't show, e.g. what your servers keep.

## propose_product_page

**Title:** Suggest a custom product page  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/ProposeProductPage/ProposeProductPageTool.swift:19`

Suggests a custom product page for an app, shown in Atlas's Product Pages (⌘4) with Dismiss and Accept; accepting makes a draft page in Atlas. Read get_product_pages first. Send `name` (the page's reference name, one no page has), `audience` (who it's for and what it should do, ≤200 characters), `reason` (why, from the evidence, ≤300) and `evidence` [{source, detail}], each with the number that points to this page: analytics (get_analytics_funnel, or get_analytics_breakdown by source, language, territory or productPage), reviews (read with get_reviews) or keywords (the approved version's ones it chooses); a page without evidence Atlas can show isn't listed, so it's refused. `keywords` {locale: [keyword]} only from get_product_pages' keywords.<locale>.free, the ones the page's audience searches: a keyword leads to one page, so one another page uses is refused with its name. `promotionalText` {locale: text} in the app's languages, ≤170 characters each, written for that audience; the others show the default page's. `startFrom` is defaultPage (its screenshots, App Previews and text), empty, or a page's id to copy (all but its keywords). `screens` is what the page's screenshots should show, in order, [{screen, caption}] or a sentence: real screens of the app. Search results show the first three, not the promotional text; they're the page's brief, which the person makes into the page's own set with Make Screenshots for This Page. `deepLink` is a complete link the app opens (check it in the project). Every problem is refused at once with how to fix it: an unknown language, a text over 170, a keyword not approved or taken, a name taken, no room under the 70 pages (drafts, hidden and rejected ones count, and so do suggested pages waiting). Sending a name you suggested again replaces that suggestion; a dismissed one is refused. {ProductPageTextRules.summary} You can't push, submit or make a page visible: the person does.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's reference name, e.g. “Weekly reflections”: shown in Atlas and App Store Connect.
- `(nested)` (string): Who it's for and what it should do, e.g. “People who want a look back at their week”.
- `(nested)` (string): Why, from the evidence, in a sentence or two.
- `type` (string): defaultPage (default), empty, or the id of a page in App Store Connect to copy.
- `screen` (string): The screen.
- `caption` (string): Its caption, optional.
- `(nested)` (string): Where the app opens from this page, e.g. https://example.app/reflections. Optional.

## propose_product_page_texts

**Title:** Suggest a product page's promotional texts  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/ProposeProductPageTextsTool.swift:22`

Suggests promotional text for languages of a custom product page, a page in App Store Connect or a draft made in Atlas (ids from get_product_pages; only pages with takesTexts). `texts` is [{locale, promotionalText, reason}]: ≤170 characters, written for the page's audience in that language, `reason` one sentence for the person on why it reads this way (≤300; the call's `reason` when left out). `evidence` [{source, detail}] is optional, from analytics, reviews or keywords as in propose_product_page. Each shows on that language of the page with Dismiss, Use and Edit, and Accept; sending a language again replaces its waiting suggestion. Skipped, with why: a language the app doesn't have, an empty text or one over 170, the page's own text again, or a language whose text already waits in Review & Push (`queued` in get_product_pages). An approved page's suggestion shows once the person presses Edit… there, which makes a new version. {ProductPageTextRules.summary} Accepted texts wait in Review & Push; nothing reaches App Store Connect until the person pushes.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's id from get_product_pages: a page in App Store Connect or a draft (draft-…).
- `description` (string): An App Store locale code the app has, e.g. de-DE.
- `(nested)` (string): The text, ≤170 characters.
- `(nested)` (string): Why it reads this way, for the person. Optional.
- `(nested)` (string): Why, for every text without its own, e.g. “From your English text; German reviews say gesperrt.”
- `description` (string): appId
- `problems` (array): texts

## propose_promotional_offer

**Title:** Propose Promotional Offer  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/Offers/ProposePromotionalOfferTool.swift:33`

Proposes a promotional offer for a subscription App Store Connect has, or a new one still queued by propose_subscription (the push creates the subscription first; discarding it discards the offer): a discount or free time the app offers its current or lapsed subscribers with a signed StoreKit offer, under offerIdentifier. mode, duration, numberOfPeriods and price (US dollars, equalized everywhere else; territoryPrices sets some apart) work as in propose_introductory_offer; a paid price is below the subscription's. A subscription takes up to 10. action update_prices gives one it has a new price or territories (mode and duration can't change: delete it and create another); the territories it prices apart (get_subscriptions' territoryPrices) keep their prices unless territoryPrices is given ({} prices none apart). action delete removes one. Anything App Store Connect would refuse is refused with the reasons (status "refused"); an accepted proposal is queued for the person (status "queued"), and proposing again for the same offer replaces it. Paid offers are refused for apps set to Keep my prices. Nothing reaches App Store Connect until they push.


## propose_purchase_review_screenshot

**Title:** Propose Purchase Review Screenshot  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/PurchaseSetup/ProposePurchaseReviewScreenshotTool.swift:35`

Proposes the App Review screenshot of a subscription or in-app purchase: a PNG or JPEG of the purchase as the app shows it (usually the paywall). Without one the product stays in Missing Metadata and StoreKit doesn't return it (see get_subscriptions' reviewScreenshot per product). Atlas is sandboxed: send the file to get_subscriptions' reviewScreenshotUploadURL with curl --data-binary @paywall.png (?name=paywall.png) and pass the fileId it returns as file. It works for products App Store Connect has (the push deletes the old screenshot and uploads this one) and for new ones queued by propose_subscription or propose_in_app_purchase. For a product App Store Connect has, it arrives on its card as a suggestion (status "suggested") the person accepts or dismisses; for a queued product it joins its change (status "queued"). Nothing is uploaded until they push. Name the plan shown, its price, the device, the language and your checks so the card can say them.


## propose_release_action

**Title:** Propose a release action  
**Source:** `Atlas/Managers/MCP/Tools/Release/ProposeReleaseActionTool.swift:51`

Proposes what to do with a version on its way to the App Store, with a reason and evidence: submit (for App Review, with buildId or buildNumber, releaseType MANUAL/AFTER_APPROVAL/SCHEDULED with releaseDate, phasedRelease, encryption when the build has no answer, and eventIds), release (an approved version waiting for the person), pause_phased_release, resume_phased_release, complete_phased_release (everyone now), cancel_submission (while it waits for review) or resubmit (a rejected submission back to App Review once it's fixed). Nothing is sent: it waits on the version card in Atlas (status "queued") until the person confirms it; submit opens the Submit sheet with your choices for their Submit. One proposal per app and platform: a new one replaces your own. "refused" says why and what's possible, e.g. a build Apple is still processing, What's New missing in a language (write it with suggest_fields first), or a version already with App Review. "unchanged" means the same is already waiting. Withdraw yours with withdraw_release_action; get_release's proposals say what became of them.


## propose_retention_message

**Title:** Propose Retention Message  
**Source:** `Atlas/Managers/MCP/Tools/Retention/ProposeRetentionMessageTool.swift:60`

Proposes a retention message for an app: the header (≤66 characters) and body (≤144) subscribers see on Apple's Confirm Cancellation screen, by locale. Leave messageId out for a new message, with referenceName and subscriptions (an app has at most 10 messages; a subscription shows one, so naming one that shows another message moves it). kind is message, image (add imageBase64 or imagePath: a PNG 3840 wide, 160 to 2160 tall, no transparency, readable in light and dark) or offer (the subscription's retention offers show with it; propose them with propose_retention_offer). Write the source language first (get_retention's sourceLocale); Atlas translates the rest, or pass more languages in texts. Anything too long or that App Store Connect would refuse is refused with the reasons (status "refused"). An accepted proposal waits in Review & Push (status "queued"), and proposing the same message again updates it. With suggestion true and one locale, the wording is offered under that language's too-long warning instead (status "suggested"). Nothing reaches App Store Connect until the person pushes. {StoreTextGuidelinePlace.retentionMessage.summary}

- `reasons`: When the person pushes, App Store Connect gets the message's words, image and subscriptions, and it goes to App Review; subscribers see it once Apple approves it. Test it by canceling a sandbox subscription.

## propose_retention_offer

**Title:** Propose Retention Offer  
**Source:** `Atlas/Managers/MCP/Tools/Retention/ProposeRetentionOfferTool.swift:39`

Proposes a retention offer for one subscription: what Apple can show with the retention message when someone taps Cancel Subscription (offer type 5). mode is FREE_TRIAL, PAY_AS_YOU_GO or PAY_UP_FRONT; months is how long it lasts; price is in US dollars in the United States, and every other territory gets Apple's equalized price. A subscription has at most 10 retention offers; Apple picks who's eligible and the best offer. Anything App Store Connect would refuse is refused with the reasons (status "refused"). An accepted proposal waits in Review & Push (status "queued"); the subscription's message must be kind "offer" to show it (propose_retention_message). Nothing reaches App Store Connect until the person pushes.

- `reasons` (optionalStrings): evidence

## propose_review_replies

**Title:** Suggest replies to reviews  
**Source:** `Atlas/Managers/MCP/Tools/Reviews/ProposeReviewRepliesTool.swift:13`

Suggests a reply for each review, shown under it in Atlas's Reviews with Send Reply, Edit and Dismiss. `replies` is a list of {reviewId, text, meaning, waitTopics?, unsure?}: `text` in the reviewer's own language (≤5,970 characters; a few sentences is right), `meaning` what it says in English, for the person. When the person has Reply Automatically on, also send `waitTopics`, what the review is about from bug, billing, account, featureRequest and personal (empty when none), and `unsure: true` when you aren't sure what it means: Atlas's rule decides from them which replies go out by themselves and which wait. You can't turn it on, change it or send. Be specific to what the review says, read the project to say what is fixed or planned, and never promise what isn't there; no personal data, no asking for a better rating. Reviews that already have a reply are skipped. Nothing is sent to the App Store: the person sends each reply. A new suggestion for the same review replaces the earlier one. {StoreTextGuidelinePlace.reviewReply.summary}

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `type` (string): appId
- `reason` (string):  Fix it and send that reply again.
- `skipped`: No review has this id. Use the ids from get_reviews.

## propose_review_themes

**Title:** Group reviews by subject  
**Source:** `Atlas/Managers/MCP/Tools/Reviews/ProposeReviewThemesTool.swift:16`

Sets "What people write about" in Atlas's Reviews: up to 8 groups of reviews on one subject, most mentioned first. `themes` is a list of {title (≤60 characters, e.g. "iCloud sync since 1.3"), note (≤240: what's going on and what to do about it), reviewIds (from get_reviews), action, territory?, replies?}. `action` is one of reply_to_all (it's fixed or answered: give `replies`, one {language, text} per language of the group's reviews, each a message that fits every review of the group in that language), open_pricing (a price or plan complaint; `territory` alpha-2 opens that country), suggest_store_page (the store page should say it) or show_reviews (just list them). Send every group in one call: it replaces the groups sent before. Nothing is sent to the App Store; with Reply to All the person reviews each language's message and sends it.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `type` (string): appId
- `groups`: group-{index + 1}

## propose_screens

**Title:** Suggest screens for the plan  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ProposeScreensTool.swift:14`

Suggests screens for the app's screenshot plan, each with its name, why (reason), what shows it (evidence: a file, target or commit), how to reach it from launch (steps, like the plan's) and a caption in the primary language (none on Apple Watch). As the answer to next_step's suggest_screens (pass its run), they show under that device's screens in the open plan (status shown). At any other time, with or without a run (at Review & Push, say, when the app gained a screen), they're queued for the app's next plan (status queued, with a proposalId): pass device watch for the Apple Watch app's own screens; otherwise they're the set's, for iPhone and iPad. Either way the person adds the ones they want with Add to Plan; nothing is added on its own. A screen the plan already has is refused: send its new steps with update_capture_plan.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from next_step, when answering suggest_screens.
- `(nested)` (string): Outside suggest_screens: watch for the Apple Watch app's own screens; leave out for the set's (iPhone and iPad). suggest_screens names its own device.
- `(nested)` (string): The screen's name, e.g. Insights.
- `(nested)` (string): Why it shows the app well, in a sentence.
- `(nested)` (string): The file, target or commit that shows it.
- `(nested)` (string): How to reach it from launch, e.g. tab “Insights” → wait for the mood chart.
- `(nested)` (string): The primary language's headline, 3–6 words. Left out on Apple Watch.
- `refused` (string): 

## propose_screenshot_file

**Title:** Propose a screenshot file  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/Hand/ProposeScreenshotFileTool.swift:18`

Suggests a screenshot file for one language and device: it replaces the screenshot at position (from 1) or, without position, goes after the last one (at most 10 per set). Send the PNG or JPEG first with curl -s --data-binary @01.png -H 'Content-Type: image/png' '<get_screenshot_context's fileUploadURL>?name=01.png' and pass the fileId it returns. The file must be one of the device's App Store sizes (get_screenshot_context's displayTypes list them), upright or turned, without transparency: Atlas never scales a screenshot, and a wrong size is refused with the sizes to use. A file replacing a screenshot Atlas made from the template stops it being redrawn when the template or caption changes. It waits on the Screenshots language page for the person to accept or dismiss, then in Review & Push. Proposing the same place again replaces the waiting one. Positions are as get_screenshot_context lists the set with the same locale and displayType. To delete screenshots use propose_screenshot_removal, and to change their order propose_screenshot_order.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The language, e.g. de-DE.
- `(nested)` (string): iphone, iphone_duo, ipad, mac, watch or vision_pro.
- `description` (string): The fileId the upload link returned.
- `(nested)` (string): Why, in a sentence or two the person reads before accepting.
- `(nested)` (string): Screenshots → {locale.name} → {display.title}, to accept or dismiss, then Review & Push

## propose_screenshot_order

**Title:** Propose a screenshot order  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/Hand/ProposeScreenshotOrderTool.swift:14`

Suggests a new order for one language's set on one device: `order` lists every screenshot's current position (from 1) in the new order, e.g. [3, 1, 2, 4, 5] puts the third first; or pass `screenshotIds` in the new order, as get_screenshot_context lists them with the same locale and displayType. Name each screenshot once, all of them: to drop some, use propose_screenshot_removal. It waits on the Screenshots language page for the person to accept or dismiss; pushing then reorders the set in App Store Connect, uploading nothing again. Screenshots Atlas makes from the template move only in this language's set: they're still redrawn when the template or the caption changes, and the other languages keep the template's order. Sending another order for the same set replaces the waiting one.

- `description` (optionalStrings): screenshotIds

## propose_screenshot_removal

**Title:** Propose deleting screenshots  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/Hand/ProposeScreenshotRemovalTool.swift:14`

Suggests deleting screenshots from one language's set on one device. Name them by position (from 1) or by id, as get_screenshot_context lists them when you pass it the same locale and displayType. It waits on the Screenshots language page for the person to accept or dismiss; accepting marks them “Will be deleted” and the ones after them move up, then pushing deletes them in App Store Connect (after any uploads, so a failed upload never leaves the language with fewer). A screenshot Atlas makes from the template goes only from this language's set: the template keeps the slot, and the other languages keep their screenshot there. The primary language must keep at least one screenshot per device. A language with no screenshots of its own shows the primary one's: there's nothing to delete. Sending another removal for the same set replaces the waiting one.

- `description` (optionalStrings): screenshotIds

## propose_subscription

**Title:** Propose Subscription  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/ProposeSubscriptionTool.swift:43`

Proposes a new auto-renewable subscription for an app, e.g. one its StoreKit code buys that App Store Connect doesn't have yet (see get_subscriptions). group is an existing group's id or reference name; any other name makes a new group, which needs groupDisplayName (its App Store name). The product ID must be exactly the one the app's code uses; it can't be changed or reused once created. duration is ONE_WEEK, ONE_MONTH, TWO_MONTHS, THREE_MONTHS, SIX_MONTHS or ONE_YEAR. displayName (≤30) and description (≤45) are written in locale (the app's primary language when left out); price is the starting price in the United States in US dollars, and every other territory gets Apple's equalized price. reviewScreenshot is the App Review screenshot of the paywall (without one it stays in Missing Metadata): send the file to get_subscriptions' reviewScreenshotUploadURL and pass the fileId; add an introductory offer to it with propose_introductory_offer while it's queued. Anything App Store Connect would refuse is refused with the reasons (status "refused"). An accepted proposal is queued for the person to review (status "queued"); proposing the same productId again replaces it. Nothing reaches App Store Connect until they push. {StoreTextRules.inAppSummary}

- `reasons` (optionalStrings): evidence
- `(nested)` (string): {subscription.group.referenceName} (new)

## propose_template

**Title:** Propose template revision  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/ProposeTemplateTool.swift:14`

Proposes a revision of an app's screenshot template as operations on the dotted paths get_template returns, e.g. {op: "replace", path: "caption.headline.size", value: 104}, based on the version you read. Refused for unknown paths, values out of range, and a fallback font that can't draw its script; the reason names each. When queued, it waits in Atlas's Proposals sheet until the person accepts it as the next version, and the result's stress lists how the stress locales (primary, longest, right to left, CJK) fit across every slot with it. Check captions with measure_caption first. Besides the fields get_template shows, a template may set device.tilt {rz, ry, rx} in degrees, device.dx/dy, device.top (pin the phone's top edge, a fraction of the height), device.empty "black" (a switched-off screen without a capture), device.pair {dx, top} (the phone behind on a slot whose layout is "pair": its own capture in front, the slot before it's behind), caption.placement below, caption.headline.upper/italic/shadow/tight (box sized to each language's lines)/emph {on: first|last, weight, font, italic}/mark {color, pad, rot, radius}, caption.subhead.italic and deco (shapes, laurels, badges, and art props: controller, chess, dice, person, underline, asterisk, arrow, corner, pointer, star, white and in front unless color or z says otherwise, each with optional anchor cap|l1end, avoid down|squeeze|hide, span (the slot a figure continues on) and off); a null value removes one. slots.<i>.layout is standard, hero or pair. A slot override may also replace the whole bg. Laurels and badges show a rating: use the app's real App Store rating, which Atlas checks before every push.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `value` (string): Why, in a sentence or two the person reads before accepting.
- `(nested)` (string): A short title, e.g. Smaller headline, hyphenation on.
- `refusals` (optionalString): title

## propose_win_back_offer

**Title:** Propose Win-Back Offer  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/Offers/ProposeWinBackOfferTool.swift:62`

Proposes a win-back offer for a subscription App Store Connect has, or a new one still queued by propose_subscription (the push creates the subscription first; discarding it discards the offer): free time or a lower price Apple shows people who used to subscribe (in the app, in Settings and, with USE_AUTO_GENERATED_ASSETS, on the App Store), from startDate. mode, duration, numberOfPeriods and price (US dollars, equalized everywhere else; territoryPrices sets some apart) work as in propose_introductory_offer. Eligibility: paidMonths, sinceLastSubscribed and waitMonths; targetSubscriptionPlanType (create only) limits it to one payment plan. action update changes the eligibility, dates, priority or promotion of one it has (send only what changes; terms, prices and plan can't change); action delete removes one. Anything App Store Connect would refuse is refused with the reasons (status "refused"); an accepted proposal is queued for the person (status "queued"), and proposing again for the same offer replaces it. Paid offers are refused for apps set to Keep my prices. Nothing reaches App Store Connect until they push.


## render_artwork

**Title:** Render a header or search page  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/RenderArtworkTool.swift:13`

Renders a header or search results page (get_design_brief's artworkDesign) the way Atlas makes the artwork: filled in for the language with the placement's text, the app's name, icon and the picked captures, fitted, at the poster moment. Returns the image (960 px wide), where each data-al element landed, how the text fits, every check, and what propose_direction would refuse. Pass html to try a page, or direction to see one already sent; locale (default the primary language) and headline to try other words.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): header, search or wide.
- `(nested)` (string): The page to try.
- `(nested)` (string): A direction's id or name: its page for kind, when html isn't sent.
- `(nested)` (string): A header concept's id or name: the page you're making for it (its own, or its loop's, when html isn't sent). While Design waits for its pages, a page that passes shows on its row.
- `(nested)` (string): A plan locale, e.g. de-DE; the primary one by default.
- `(nested)` (string): The words to try; the placement's own text by default.

## render_event_artwork

**Title:** Render In-App Event artwork  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/Artwork/RenderEventArtworkTool.swift:32`

Makes or checks one In-App Event's card (16:9, shown in search, Today and on the product page) or details page (9:16, the top of the event's page) in one language: the art Apple shows behind the event's badge, name and description. Give exactly one of: `html`, a full HTML page Atlas renders as a still at 3840 × 2160 (card) or 2160 × 3840 (details page), or with `motion: true` as a video: its CSS and SVG animation as a 20-second seamless loop at 30 fps, 1920 × 1080 or 1080 × 1920 (page JavaScript doesn't run); `fileId`, a PNG, JPEG, MP4 or MOV sent to the upload link get_in_app_events gives (`curl --data-binary @card.mp4 '<link>?name=card.mp4'`), e.g. stills or loops an app's own tools render; or `imageBase64`, a PNG or JPEG under 24 MB. Returns the art, the same art as the App Store lays the badge, the name and the description (short on the card, long on the details page) over it in `locale`, and its checks against Apple's rules: `refusals` (size outside 1920 × 1080–3840 × 2160 or 1080 × 1920–2160 × 3840, not exactly 16:9 or 9:16, wrong format, not 30 or 60 fps, a video shorter than 5 s or longer than 30 s, audio that isn't stereo AAC/PCM at 44.1 or 48 kHz, over 500 MB) must be fixed before propose_event_artwork takes it; `warnings` (text in the art, a busy lower part where Apple puts the name, transparency, a codec Apple doesn't name) are worth fixing. With `motionFrames`, a page's loop is shown at a few moments and checked, quickly. Make art without words, logos, borders or gradients, a calm lower part, and a seamless loop for a video. Returns a `fileId` to propose. Read-only: nothing is queued.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events.
- `description` (string): The language to lay the event's text in, e.g. de-DE. Default: the event's primary language.
- `(nested)` (string): A full HTML page to render as the art, with no text in it.
- `(nested)` (string): A file sent to the upload link, or one this tool returned.
- `(nested)` (string): A PNG or JPEG, base64-encoded.
- `(nested)` (string): The name Apple gets for an html or imageBase64 file, e.g. gratitude-card.png.
- `description` (string): appId
- `uploadLink` (optionalBool): motion
- `uploadLink`: the art, then the art with the event's text as the App Store lays it

## render_preview

**Title:** Render preview  
**Source:** `Atlas/Managers/MCP/Tools/Screenshots/RenderPreviewTool.swift:14`

Renders one screenshot as Atlas would push it (at half size) and returns it as a PNG image: the locale's capture in the template with its current caption, or the primary locale's caption when it has none. Pass templatePatch to see a template change before proposing it.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): A locale code such as ar-SA.
- `description` (string): iphone, iphone_duo or ipad.
- `description` (string): appId

## report_app_support

**Title:** Report the devices and languages the app supports  
**Source:** `Atlas/Managers/MCP/Tools/AppSupport/ReportAppSupportTool.swift:14`

After reading the app's Xcode project, tell Atlas what it supports: the targets ("Lumen (iOS, visionOS)", "LumenWatch Watch App"), the devices they run on besides iPhone (ipad, watch, vision, mac when it has a macOS target or Mac Catalyst, so the Mac App Store takes Mac screenshots of its own (not when it only runs on Mac as an iPad app), and iphone_duo when the iOS target builds with the iOS 27.1 SDK or later, which makes iPhone Duo screenshots required from April 2027) with why ("Lumen runs on iPad", "Lumen has a watch app, LumenWatch", "1.4 adds visionOS", "Lumen supports Mac Catalyst", "Built with the iOS 27.1 SDK"), and every language in its string catalogs (Localizable.xcstrings) with how many strings are translated, plus a note when it matters ("Right to left; tested in LumenUITests"). Atlas compares the languages with the App Store page: the ones it doesn't have yet are suggested as new pages, and Autopilot plans each device. With look, also what the project says of the app's look (accent and theme colors, fonts, dark mode), its icon in one sentence, who it's for and when they use it, and the header scene template you recommend from that (night, land, window, horizon, hero or pattern) with a one-sentence reason: Atlas's plan shows it, and the header and search prompts use it. Each report replaces the last (the look stays until a report has one). Atlas can't open the project itself.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `type` (string): Where the languages come from, e.g. Localizable.xcstrings.

## report_capture

**Title:** Report a screenshot capture  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ReportCaptureTool.swift:12`

Records a capture for the Autopilot run: the screen (id from the plan), displayType (the plan's: iphone, iphone_duo, ipad, mac, watch or vision), locale, and the upload ID the upload URL returned for its PNG (or, if Atlas can read it, a file path). Give the attempt (1–3) and a score from 0 to 1 with notes saying why (e.g. "Keyboard covers the prompt"); the best one is picked. The PNG must be the device's full size, e.g. 1320 × 2868 on iPhone, 2007 × 2853 on iPhone Duo's inner display, a Mac's whole screen on Mac. Atlas reads the text in it and measures how much is blank: when the result has a check (text in another language, cut-off labels, a system prompt or a mostly blank screen), fix what it says and capture it again as the next attempt; a clean attempt is used over one with a check. The result says how many are left.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The screen's id from the plan.
- `(nested)` (string): The plan's device: iphone, iphone_duo, ipad, mac, watch or vision.
- `(nested)` (string): The locale the app ran in, e.g. de-DE.
- `(nested)` (string): On iphone_duo, the target's pose from next_step: open (inner display) or closed (cover display).
- `(nested)` (string): The upload ID the upload URL returned.
- `(nested)` (string): A PNG path, when Atlas can read it (prefer upload).
- `description` (string): Why it scored so, in a few words.
- `fix` (string): Fix it and capture this screen again as attempt {capture.attempt + 1}.

## report_capture_problem

**Title:** Report a capture problem  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ReportCaptureProblemTool.swift:12`

Tells the person a screen couldn't be captured on a device in a locale: what happened ("The photo picker asked for access and covered the entry") and the fix you propose, as a command or step (e.g. xcrun simctl privacy booted grant photos <bundle ID>). When a command was refused (not allowed in this session), pass it as refusedCommand and don't try it in another form; proposedFix then says what to change in the project so it isn't needed (e.g. a scheme that sets the environment variable). When the fix is a change to the project (a test, a scheme, sample data) rather than a command, pass changesProject: true, with the file and line in proposedFix, and report it once: Atlas holds the same screen on that device in the other languages, and the person answers for all of them. When the fix is a step for the person that isn't a command (install something, sign in), pass changesProject: false. When no screen on the device can be captured in any language because this Mac lacks the runtime its simulator needs (e.g. iPhone Duo without an iOS 27.1 runtime; get_capture_plan's simulator says needsRuntime), report it once with affectsDevice: true and go on with the other devices; don't download simulator runtimes yourself: Atlas offers the person to install them. When the runtime is installed and only the simulator is missing, Atlas makes it itself (simulator making, next_step waits): don't report that. Don't stop: capture the other screens. The person retries with the fix (next_step then lists it under retryWithFix), reuses the primary language's capture, keeps the capture already sent, or uploads one by hand.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The screen's id from the plan.
- `(nested)` (string): The plan's device: iphone, iphone_duo, ipad, watch or vision.
- `(nested)` (string): The locale, e.g. de-DE.
- `(nested)` (string): On iphone_duo, the target's pose from next_step: open (inner display) or closed (cover display).
- `(nested)` (string): What happened, in a sentence.
- `(nested)` (string): A command or step that would fix it.
- `(nested)` (string): The command that wasn't allowed, when that's what stopped you.

## report_deep_link_check

**Title:** Report whether the app opens an event's deep link  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/Details/ReportDeepLinkCheckTool.swift:21`

After checking in the app's project that it opens an In-App Event's deep link, tell Atlas what you found: deepLink (the link you checked: the event's, or the one you propose with propose_event_details), opens (true only when it opens this event's screen), shows (what the person sees), beforeStart (what it shows before the event begins: App Review taps Open then, so it must show the event and its start date, never a plain screen), needsPremium (the screen needs a subscription: an event with NO_COST_ASSOCIATED must never land on a paywall), where (file:line where the link is handled), build (MARKETING_VERSION (CURRENT_PROJECT_VERSION) you checked, e.g. "1.2.0 (21)"), testedInSimulator (you opened it with xcrun simctl openurl) and problems (each thing still wrong: cold launch, already open, after onboarding, unknown or ended event). Each report replaces the last for that event; one for another deep link than the event's shows once the event has it. Atlas keeps the dates it was made under (yours when you suggested dates beside the person's, else the event's, queued or App Store Connect's): once its start or end moves, get_in_app_events' deepLinkCheck says `stale: true` with why, as beforeStart may name the old start. Check again and report it.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events.
- `(nested)` (string): The deep link checked.
- `description` (string): What the person sees when it opens, in one sentence.
- `(nested)` (string): What it shows before the event begins.
- `description` (string): file:line where the link is handled.
- `(nested)` (string): MARKETING_VERSION (CURRENT_PROJECT_VERSION) checked, e.g. 1.2.0 (21).
- `description` (string): appId
- `shows`: The event costs nothing (NO_COST_ASSOCIATED) but its link lands on Premium: App Review rejects that. Fix it, then report again.

## report_design_source

**Title:** Report what the design project holds  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ReportDesignSourceTool.swift:12`

After opening the app's connected design project (Claude Design, a Figma file), tell Atlas what you found: its title ("Northpier Brand · design system"), colors [{name, hex}], typefaces, logo and voice. Atlas shows it under Connect a Design Project. Atlas can't open these sources itself.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The system or project's name and kind.
- `required` (string): e.g. New York Bold for headlines · SF Pro Text for the rest.
- `(nested)` (string): e.g. Moon mark, light and dark.
- `(nested)` (string): e.g. Calm, short sentences, no exclamation marks.

## report_encryption_key

**Title:** Report the export compliance key  
**Source:** `Atlas/Managers/MCP/Tools/AppInformation/ExportCompliance/ReportEncryptionKeyTool.swift:43`

After adding the export compliance key to the app's project (or finding it there), tell Atlas: status added (you changed the project), alreadyThere (it already had the key with this value) or couldNotAdd (with reason); value NO or YES (ITSAppUsesNonExemptEncryption; YES also needs complianceCode, the approved declaration's codeValue); where, each place it's set (file with line, or buildSetting, the target and its configurations: the app target, and an embedded app with its own bundle such as a watchOS app); commit when you made one; notes. get_export_compliance's infoPlistKey.expected says the value once the answer is settled; a value that contradicts it is refused. Each report replaces the last; the Export Compliance page shows it. Nothing reaches App Store Connect: builds uploaded from then on answer the question themselves.

- `expected` (optionalString): commit
- `shows` (optionalArray): where

## report_page_capture

**Title:** Report a screen captured again for a product page  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageShots/ReportPageCaptureTool.swift:18`

Names a capture of one of the default set's screens, taken again for a custom product page when the person turned on Capture Screens Again in Make Screenshots for This Page (get_page_screenshots' recapture): the screen (its number from 1), the locale the app ran in, displayType (iphone or ipad) and the upload ID the upload link returned for its PNG, with what it shows now. The PNG must be the device's full size: 1320 × 2868 on iPhone, 2064 × 2752 on iPad. A screen sent again in the same language on the same device takes the place of the one before; at most three screens are captured again. A language without its own capture uses the primary language's. The default page's captures never change.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's name or id, as get_page_screenshots has it.
- `description` (string): The locale the app ran in, e.g. de-DE.
- `(nested)` (string): iphone or ipad.
- `(nested)` (string): The upload ID the upload link returned.
- `(nested)` (string): What the screen shows now, e.g. “The diary locked with Face ID”.

## report_recording

**Title:** Report an App Preview recording  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ReportRecordingTool.swift:13`

Records the App Preview's Simulator recording for the Autopilot run: displayType (iphone or ipad), locale, the upload ID the upload URL returned for the video (xcrun simctl io booted recordVideo --codec h264), and marks: when each of the plan's screens appears, in seconds from the recording's start. Atlas cuts the App Preview from it (15–30 s), adds the captions and end card in the chosen direction, and checks it against Apple's rules. When it can't be recorded, pass problem instead of upload: the run goes on without it.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): iphone or ipad.
- `(nested)` (string): The locale the app ran in, e.g. en-US.
- `(nested)` (string): The upload ID the upload URL returned for the video.
- `screen` (string): The screen's id from the plan.
- `type` (string): The screen's id from the plan.
- `type` (string): Why it works, in a few words.
- `type` (string): Why it couldn't be recorded, instead of upload.

## report_review_screenshot_run

**Title:** Report a review screenshot run  
**Source:** `Atlas/Managers/MCP/Tools/Subscriptions/PurchaseSetup/ReportReviewScreenshotRunTool.swift:18`

While you make App Review screenshots of an app's subscriptions and in-app purchases (Make Review Screenshots… in Atlas), report where you are so the person sees it: status "working" with a short step ("Opened Lumen in Simulator · iPhone 17 Pro", "Opened the paywall from Settings → Lumen Plus", "Selecting Annual and waiting for its price") and productId while you capture that product; "paywall_not_found" with tried (every way you tried, in one sentence) when nothing leads to a purchase screen; "no_prices" with saw (what the paywall showed) when StoreKit returned no products; "done" when every product was sent with propose_purchase_review_screenshot. A stop needs the person: they say where the paywall is, or let you add a StoreKit configuration, and Atlas asks again.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `enum` (string): While working: what you do now, in a few words.
- `(nested)` (string): While working: the product you capture now.
- `(nested)` (string): With paywall_not_found: every way you tried.
- `(nested)` (string): With no_prices: what the paywall showed.

## request_page_recapture

**Title:** Ask to capture a product page's screens again  
**Source:** `Atlas/Managers/MCP/Tools/ProductPages/PageShots/RequestPageRecaptureTool.swift:21`

Asks Atlas to let you capture again some of the default set's screens for a custom product page (its screens should show something else for that page's audience), without the person turning on Capture Screens Again first: the page, the screens (numbers from 1, as get_page_screenshots lists them; at most three a page), the locale and displayType (iphone or ipad) the app runs in, and the reason and evidence the person reads. Status queued (with requestId): the person accepts or declines it in Atlas; tell them, nothing else to do until then. Status opened: get_page_screenshots now has recapture with the upload link; capture those screens and name each PNG with report_page_capture. The default page's captures never change, and nothing reaches App Store Connect until the person pushes.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The page's name or id, from get_product_pages.
- `description` (string): The locale the app runs in, e.g. de-DE.
- `(nested)` (string): iphone or ipad; iphone when left out.
- `(nested)` (string): Why these screens should show something else for this page.
- `(nested)` (string): What shows it: a file or commit.
- `title`: Atlas shows it to the person in Screenshots with Accept and Decline. Tell them; nothing else to do until then.

## request_recapture

**Title:** Ask to redo some captures  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/Recapture/RequestRecaptureTool.swift:21`

Asks Atlas to redo only some of the app's captures, and moments of its App Preview, without a whole Autopilot run: when the app's screens changed (new texts in a language, a redesigned screen). It works even when the app has no saved Autopilot run: the run is then made from the captures the set uses (list_captures: their screens, devices, iPhone Duo poses and sizes), and only what has a capture can be redone; moments need the run's recordings, so without one they come back in unknownMoments with momentsReason. Each item of targets names a screen (its id, name or number in the plan) or a slot (from 1, as list_captures numbers them), a locale, a displayType (left out: every device that captures it) and on iPhone Duo a pose (left out: both); an item with only a locale is every screen in it. moments are App Preview moments (screen ids) to record again. Give the reason and evidence (a file or commit) the person reads. Result status queued (with requestId): Atlas shows it to the person with Accept and Decline, and once accepted the run waits for you; tell the person, and nothing else to do until then. Status opened: the person let you open capture-only runs; go on with get_capture_plan, then next_step after each step, which asks only for these captures. Plan, Design and the captions are skipped: the set keeps its template and captions, and Review & Push sends only the images that change. Nothing reaches App Store Connect until the person pushes.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The screen's id, name or number in the plan (get_capture_plan's screens).
- `description` (string): The locale, e.g. ja.
- `(nested)` (string): iphone, iphone_duo, ipad, mac, watch or vision_pro; leave out for every device.
- `(nested)` (string): On iPhone Duo: open or closed; leave out for both.
- `description` (string): Why they need redoing, in a sentence the person reads, e.g. the phrases were rewritten.
- `(nested)` (string): What shows it: a file or commit, e.g. d038b58.

## rerecord_moment

**Title:** Record an App Preview moment again  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/RerecordMomentTool.swift:14`

Before the design step, records again a moment the person asked for at Pick (next_step says record_again; list_recording_moments marks it recordAgain). Call it with moment_id alone to see what to record and where; record only that screen the same way as the recording (xcrun simctl io <udid> recordVideo --codec h264), upload it to the plan's upload URL, then call it again with the upload ID, device and locale, and start_s/end_s when the screen has settled and ends. The new take stands in for that moment of the device's recording; the rest stays.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The moment's id from list_recording_moments (its screen).
- `(nested)` (string): The upload ID the upload URL returned for the new take.
- `(nested)` (string): iphone or ipad.
- `(nested)` (string): The take's locale.
- `description` (string): Why this take works, in a short sentence.
- `retakesLeft`: Launch the app on this screen with the plan's launch arguments for the locale, start recording, and for 6 to 8 s do the thing a person does here so the screen changes: a slow real drag through a list, opening an item, typing and letting the result arrive, a control animating. Something should move at least half that time, never more than 2 s of nothing. Stop it with exactly killall -INT simctl, upload it with curl --data-binary and -H 'Content-Type: video/quicktime', and call rerecord_moment with the upload ID, device, locale, start_s and end_s, the stretch where the action happens. Only the app may be on screen.

## revise_app_preview

**Title:** Revise the App Preview  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ReviseAppPreviewTool.swift:13`

Sends the App Preview's new version after the person asked for changes (next_step's revise_app_preview gives the note and the current cut): which plan screens play and in what order, its length, the captions' size, the end card, optionally its look and a library track. Say what changed in changes. Atlas makes every App Preview again with it and shows the person the new version. The recordings stay as they are.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): What changed, in a short sentence the person reads: “Slower pace, starts with Search”.
- `(nested)` (string): Optional: a library track (warm_acoustic, calm_piano, bright_pop) for other music.
- `type`: The plan screen IDs that play, in order. Leave out to keep the current order.
- `description`: The App Preview's length, 15 to 30 seconds. Longer is a slower pace.
- `description`: The captions' size against the template's, 0.8 to 1.4.
- `type`: The end card: caption false shows only the app's name; screen is the plan screen whose caption it shows.
- `changes` (optionalStrings): screens

## revise_artwork_concept

**Title:** Revise a header and search concept  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/Concepts/ReviseArtworkConceptTool.swift:15`

Sends a concept's new pages. When next_step says revise (the person's note on concepts), send each concept the note is for, with artworkDesign holding the pages that change (whole pages; the others stay) and change_notes saying what changed; pass last: false on every one but the final. When next_step hands you a concept's motion prompt (artwork-motion) at design or revise, or says animate_header or revise_loop, send that concept's animated pages (every canvas) the same way: Atlas checks that every animation repeats evenly in the loop, frame 0 is the still, the last frame leads back to it, the data-al elements never move and no frame jumps; at Design the person then chooses among the loops, later Atlas makes them in every language. Rendered and checked like propose_artwork_concept.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The concept's id ("A") or name.
- `(nested)` (string): What changed, in plain words, for the person to read.
- `concept`: Send the next concept or direction for the same note; pass last: true (or leave it out) on the final one.

## revise_direction

**Title:** Revise a screenshot design direction  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/ReviseDirectionTool.swift:12`

Sends a revised direction after the person asked for changes (next_step gives the note and each direction's current template and header and search pages): the direction's id (or name), its new template fields and/or ops laid on the direction as it is, and artworkDesign with the header and search pages that change (whole pages; the others stay), rendered and checked like propose_direction's. extrasTemplates.appPreview for the App Preview. A run without screenshots takes no template unless it styles the App Preview. Optionally a new rationale (what changed) and sourceLink. Pass last: false on every direction but the final one; the run goes back to the person to choose after the last.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): The direction's id or name.
- `description` (string): What changed, in a sentence.
- `(nested)` (string): Where to refine it.
- `direction`: Send the next direction for the same note; pass last: true (or leave it out) on the final one.

## set_app_preview_music

**Title:** Set the App Preview's music  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/SetAppPreviewMusicTool.swift:13`

Changes the music under the run's App Preview to one of Atlas's library tracks (warm_acoustic, calm_piano, bright_pop, soft_ambient, lofi_beat, cinematic_build, playful_marimba), made on this Mac and free to use on the App Store. At the plan it's the plan's music; at Watch the App Preview, every App Preview is mixed again with it. Only the person can choose their own file.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): A library track: warm_acoustic, calm_piano, bright_pop, soft_ambient, lofi_beat, cinematic_build or playful_marimba.
- `(nested)` (string): The same as track.
- `(nested)` (string): Not taken: only the person chooses their own file, which confirms they hold the rights.

## start_display_recording

**Title:** Record iPhone Duo’s inner display  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/StartDisplayRecordingTool.swift:15`

Call this right before running a UI test for iPhone Duo's open screens (not its closed ones: closed, the test's own screenshot is the cover display they need). A UI test's screenshot there (XCUIScreen.main) is the cover display, and the test closes the app right after it, too soon to screenshot the inner display yourself. Atlas opens the Duo if it's closed, then records its inner display at full size. Run the test on the simulator it names, with -resultBundlePath (one screen or several, in any language), then call finish_display_recording with that path: each screenshot the test attached comes back as the inner display at that moment, with an upload ID for report_capture. The project needs no change for it.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan.
- `(nested)` (string): iphone_duo, the only device that needs it.

## suggest_fields

**Title:** Suggest field values  
**Source:** `Atlas/Managers/MCP/Tools/Suggestions/SuggestFieldsTool.swift:17`

Suggests values for an app's fields in Atlas; each one shows under its field until the person accepts, edits or dismisses it. Items are {area, locale | page, device, field, value, reason, evidence}: area store with a locale code and a Store Page field ({ListingField.mcpNames.joined(separator: ", ")}), or area info with page general (copyright, primaryCategory, secondaryCategory, gamesSubcategories, secondaryGamesSubcategories, contentRights, release; contentRights is USES_THIRD_PARTY_CONTENT or DOES_NOT_USE_THIRD_PARTY_CONTENT, or yes or no; gamesSubcategories is up to two Games subcategory ids, comma-separated, only while the primary category is GAMES, and secondaryGamesSubcategories the same while the secondary category is GAMES), page review (contactFirstName, contactLastName, contactPhone, contactEmail, demoAccountRequired yes or no, demoAccountName, notes; the demo account's password is never suggested), page ageRating (field is a question, value one of its answers), page accessibility with a device (iphone, ipad, watch, vision, mac, tv; field is a feature, value yes or no) or field accessibilityUrl (the app's, no device), or page appPrivacy with a locale and field privacyChoicesUrl (the User Privacy Choices URL in that language). Give a one-sentence reason and evidence such as {kind: "git", ref: "v1.3..4f2c91a"} or {kind: "code", ref: "File.swift:18"}. Per item, status is queued, unchanged (the field already has that value or you suggested it already), updated (you suggested that value already and it took your new reason or evidence, same id), replaced (your older open suggestion for the field was replaced: send a field again to change your value or its reason) or refused with a code: over_limit (with count), unknown_field, unknown_locale, locked (the version is in review), not_permitted, invalid_value or invalid_answer (not one of the question's or feature's answers), guideline (store text App Review would reject, with issues [{kind, guideline, phrases}]: pricing such as “free”, prices, discounts or trials, other platforms, other apps' names, unverifiable claims, beta or demo, placeholders, “coming soon” or “For Kids”; rewrite it as the reason says) or run_stopped (the person stopped receiving the run: stop sending). Follow get_store_page's storeTextRules. Pass total, how many you'll send in all, so Atlas shows progress; when suggesting everything, call begin_suggestions with your plan first and pass its run instead. apply: true queues the values as changes instead, only when the person allowed editing drafts. A store locale may also be a language the app supports and the App Store doesn't have yet (get_store_page's languagesNotOnAppStore): it stays a suggestion, even with apply, in its own tab until the person adds the page. Read get_store_page and get_app_information first. Take back your own open suggestions that went stale (a reason that cites a date that moved, a value no longer right) with withdraw_suggestion and their ids. version may also be a new version queued with propose_app_version: its fields (whatsNew, description, keywords, promotionalText, URLs, copyright, release, page review, and name, subtitle, privacy URLs (privacyChoicesUrl too), categories, both Games subcategories and age rating, which go into the app info App Store Connect makes with it) are then queued with it in Review & Push (status applied, with a note) instead of shown as suggestions, since it has no page in Atlas yet; they go into it right after Atlas creates it, and are discarded with it. contentRights and accessibilityUrl belong to the app, so with version they're handled as without.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The version string, e.g. 1.4: the one being prepared, or a new version queued with propose_app_version.
- `description` (string): The run begin_suggestions returned, when suggesting everything.
- `description` (string): store or info.
- `(nested)` (string): For store and for appPrivacy: an App Store Connect locale code, e.g. en-US.
- `(nested)` (string): For info: general, ageRating, accessibility, appPrivacy or review.
- `(nested)` (string): For accessibility: iphone, ipad, watch, vision, mac or tv.
- `(nested)` (string): The field, question or feature, e.g. whatsNew, notes, wellness or voiceOver.
- `(nested)` (string): The suggested value, within the field's limit. Categories, Games subcategories, contentRights and release by id; an answer by name, e.g. Yes or Infrequent.
- `(nested)` (string): One sentence: why this value.
- `kind` (string): git, code, review, …
- `ref` (string): What to look at.

## update_capture_plan

**Title:** Write the capture plan's steps  
**Source:** `Atlas/Managers/MCP/Tools/Autopilot/UpdateCapturePlanTool.swift:17`

Writes the screens of the Autopilot run's plan from the project: for each, its name, the steps to reach it (e.g. tab "Week" → scroll to top) and, if the plan has none, the caption it goes with. Screens without a device are iPhone's, iPad's and Mac's; device "watch" lists the watch app's own screens (no captions), and device "vision" the Apple Vision Pro windows, each with sameMomentAs: the iPhone screen id whose moment and caption it shows. Match existing screens by id or name; new screens can be added only before the first capture. When the plan says chooseScreens, decide which screens show the app best and send them with replace: true: on each device you send screens for, they become the plan's screens in that order (strongest first, each with a caption as get_capture_plan's choosingScreens says: App Store search results show the first three), and the others there are dropped, except the screens the person added (addedBy in get_capture_plan): they stay, after yours, unless you send them. iPhone Duo uses the same screens as iPhone (get_capture_plan's poses say which it shows open or closed). Also takes the file the steps came from (writtenFrom, e.g. LumenUITests/ScreenshotTests.swift) and the app's sample-data switch. That's while a run captures (stage waiting or capture). At any other time (a run at Plan or Review & Push, or no run), what you send is queued as one proposal for the app's next plan (status queued, with a proposalId): the new steps of screens the plan already has (by id or name; suggest new screens with propose_screens), sampleData and writtenFrom. The person accepts or rejects it when the plan opens, and it applies from that run on; sending a field again replaces what waited for it. setupCommands replaces the commands fixes added (get_capture_plan's simulatorSetup.addedByFixes; [] removes them all): each is run as it is, so it's one line starting with xcrun or xcodebuild, with no VAR=value in front. setupNotes replaces the notes fixes left (simulatorSetup.notes): instructions that aren't commands. Those two are always a proposal, during a capture too. Pass reason and evidence for the person.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The run's ID from get_capture_plan, while it captures.
- `description` (string): The file or files the steps come from.
- `(nested)` (string): How the app loads sample data, e.g. launch argument -ui-sample-week.
- `type` (string): For a proposal: why, in a sentence or two the person reads before accepting.
- `(nested)` (string): For a proposal: the files, targets or commits that show it.

## withdraw_event_texts

**Title:** Withdraw In-App Event text suggestions  
**Source:** `Atlas/Managers/MCP/Tools/InAppEvents/WithdrawEventTextsTool.swift:17`

Withdraws your own text suggestions for an In-App Event that still wait for the person (get_in_app_events' openSuggestions with your client as `by`), new texts and revisions alike (`revision: true`), e.g. the ones in `staleSuggestions`, whose language App Store Connect has written since. `locales` lists the languages, or "all" for every one of yours on the event. Only suggestions sent by this client are removed; `withdrawn` lists them and `left` the languages that weren't, with why (another assistant's, or none waiting). Texts already accepted wait in Review & Push and aren't touched. Nothing reaches App Store Connect.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The event's id, from get_in_app_events.
- `type` (string): appId
- `reason` (string): Suggested by {other.source}, not by you: left for the person.
- `reason`: {app.name} · {eventID} · text suggestions

## withdraw_release_action

**Title:** Withdraw a release proposal  
**Source:** `Atlas/Managers/MCP/Tools/Release/WithdrawReleaseActionTool.swift:16`

Withdraws your own propose_release_action proposal that still waits for the person on the version card, by proposalId (rp-…, from propose_release_action or get_release's proposals); every one of yours for the app when left out. To change it instead, propose again: a new one replaces yours. `withdrawn` lists what was taken back and `left` what wasn't, with why (another assistant's, already confirmed or dismissed, unknown).

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): e.g. rp-3f9a1c2e.

## withdraw_suggestion

**Title:** Withdraw field suggestions  
**Source:** `Atlas/Managers/MCP/Tools/Suggestions/WithdrawSuggestionTool.swift:18`

Withdraws your own suggest_fields suggestions that still wait for the person, by the id suggest_fields returned (sg_7) or get_store_page and get_app_information list with their source: e.g. one whose reason cites a date that has moved, or a value that's no longer right. To change one instead, send its field again with suggest_fields: it replaces your open one (a new value) or takes your new reason (the same value). `id`, or `ids` for several. Only suggestions sent by this client are removed; `withdrawn` lists them and `left` the ids that weren't, with why (another assistant's or Atlas's own, already accepted or dismissed by the person, or unknown). A value the person accepted waits in Review & Push and isn't touched. Nothing reaches App Store Connect. A release proposal's id (rp-…, from propose_release_action or list_proposals) withdraws it from the version card too, as withdraw_release_action does: it's listed in `withdrawn` with kind release and its action.

- `(nested)` (string): The app's Apple ID, bundle ID, SKU or name, from list_apps.
- `(nested)` (string): The suggestion's id, e.g. sg_7, or a release proposal's, e.g. rp-3f9a1c2e.
- `description` (string): appId

