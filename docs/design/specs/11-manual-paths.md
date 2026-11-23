ATLAS · BY HAND · 22 NOVEMBER 2026

# Everything by hand, too

Claude Code and Autopilot are a shortcut, never the only way. Every change Atlas can make for you, you can also make yourself, in the page where it belongs. This review lists what each section lets you do by hand and adds what Screenshots was missing.

**On the canvas.** In *▶ App clicável*, press Play → Screenshots. Click a screenshot to select it (Replace…, Delete…, ◀ ▶), use the **Add Screenshots** tile, or **Manage** for Import a Folder… and Delete All…. Switch the language (try Polish, which has no screenshots yet) and the device. Every change lands in Review & Push, and “N not pushed” under the title opens just those.

## The rule

- **The page is for doing it yourself; the Autopilot button is for asking Claude Code.** Manual controls live in the content, next to what they change. Autopilot stays top right. Neither depends on the other, and neither needs Claude Code to be connected.
- **Same path afterwards.** What you do by hand and what Claude suggests both wait in Review & Push, with the same Undo.

## Section by section

| Section | By hand | With Claude Code | Gap |
| --- | --- | --- | --- |
| Store Page | Type in every field, in every language; Accept, Use and Edit or Dismiss each suggestion | Suggest Texts… | None |
| Screenshots | Add, replace, reorder and delete, per language and device; import a folder; a language can use English (U.S.) or get its own | Make Screenshots… (Autopilot) | Was missing: only caption suggestions could be accepted. **Added now.** |
| App Preview videos | — | Make the App Preview… | No way to upload, replace or delete a video yourself. Same flow as screenshots, next. |
| Product Pages | New Page…, its texts, deep link and languages | Suggest Pages…, Make Screenshots for This Page… | A page’s own screenshots can only be made by Claude. It should reuse this flow. |
| In-App Events | Every text; Choose Files… for the card and details image | Make the Artwork…, Write Event Texts… | None |
| App Information | Answer every question and field | Suggest Answers… | None |
| Pricing | Accept, Use and Edit or Dismiss suggestions; Add Subscription… | Suggest Prices… | No way to set a price yourself, for every country or one. The plan says this stays free. |
| Retention | Write the message and choose the offer | Write a Retention Offer… | None |
| Reviews | Write and send a reply, Reply to All | Draft Replies…, Reply Automatically… | None |

## Screenshots by hand

### Where

- Language menu and device switch (iPhone 6.9″, iPad 13″, Mac) choose the set: one set per language and device, up to 10 screenshots.
- Under them: the size the device needs and how many there are, “iPhone 6.9″ · 1320 × 2868 · 5 of 10”.
- Each screenshot is a button with its position. Click to select; the bar above the set shows what it is (“Made by Atlas from the template and its caption · live” or “Uploaded by you: Lumen-de-03.png · not pushed”), with ◀ ▶ to move it, Replace…, Delete… and Undo Change.
- The last tile is **Add Screenshots**: click it or drop files on it. **Manage** has Add Screenshots…, Import a Folder… and Delete All … in German….
- Under each screenshot, its state: Live, Caption suggested, Replaced · not pushed, New · not pushed, Will be deleted.

### The cases

| You want to | How | What happens |
| --- | --- | --- |
| Replace one screenshot in one language | Select it → Replace… → Only German | The other languages keep theirs. If Atlas made it from the template, it stops being redrawn when the template or caption changes; Undo Change brings the template version back. |
| Replace it in every language with the same image | Replace… → Every language with its own screenshots | For images without words, or words you accept in every language. |
| A different file in each language | Manage → Import a Folder… | Folders by language, as fastlane names them (`de-DE/iphone-6.9/01.png`). A table shows what each folder does before anything changes; unknown languages and wrong sizes are skipped with the reason. Replace their screenshots, or add after them. Languages not in the folder stay as they are. |
| Add screenshots | The Add tile, Manage → Add, or drop files | Each file is checked; wrong sizes are skipped, never scaled. They go at the end, to one language or every language with its own set; at most 10. |
| Change the order | Select → ◀ ▶ | “New order” in Review & Push. Slots 1–3 are the ones search results show on iPhone. |
| Delete one | Select → Delete… → Only German, or every language | The ones after it move up. The last English (U.S.) screenshot of a device can’t be deleted: Apple needs it. |
| Delete all in a language | Manage → Delete All iPhone 6.9″ Screenshots in German… | After the push the App Store shows the English (U.S.) ones in German. iPad and Mac keep theirs. |
| A language with none of its own | Banner: “Polish uses the English (U.S.) screenshots.” | **Add Its Own…**, or **Start from English (U.S.)**, which copies the English set into Polish so you can replace them one by one. |
| Change your mind | Undo Change on the screenshot, Undo in the toast, or remove it in Review & Push | Nothing reached the App Store yet. |

### What Apple decides

- Screenshots belong to the version: changes go out with version 1.4 and App Review sees them. When no version is editable, the section says so and offers to make one.
- Sizes: iPhone 6.9″ 1320 × 2868 or 1290 × 2796; iPad 13″ 2064 × 2752 or 2048 × 2732; Mac 2880 × 1800, 2560 × 1600, 1440 × 900 or 1280 × 800. Portrait or landscape. PNG or JPEG, without transparency. Up to 10 per language and device.
- A language without its own screenshots shows the primary language’s. Smaller iPhones and iPads use the largest size when they have none of their own.
- Atlas never scales or edits a screenshot you give it: a stretched one is a common App Review rejection.

## For Claude Code

- A set is one `appScreenshotSet` (version localization × display type). Add: reserve an `appScreenshot`, upload its parts, commit with the checksum, then wait for Apple’s processing. Delete: delete the `appScreenshot`. Order: replace the set’s `appScreenshots` relationship. Replace is upload, then reorder into the old position, then delete the old one, as one queued change.
- Push uploads before deletes, so a failed upload never leaves a language with fewer screenshots than before.
- Each slot remembers where it came from: template render, uploaded by hand, or copied from another language. An uploaded slot isn’t re-rendered by template or caption changes until Undo Change or Restore Template Version.
- Import a Folder reads fastlane’s `screenshots/` layout and Atlas’s own export: language folder, device from the folder or file name (`iphone-6.9`, `ipad-13`, `mac` or the pixel size), order from the leading number.
- Size checks are the same as Autopilot’s; nothing is resized. Drag and drop: on the Add tile, on a screenshot (asks to replace it), or anywhere on the set.
- MCP: assistants can propose a replacement file for a slot like any other suggestion; they never delete a screenshot.

Next: the same flow for App Preview videos and for a product page’s own screenshots, and a price you set yourself in Pricing.
