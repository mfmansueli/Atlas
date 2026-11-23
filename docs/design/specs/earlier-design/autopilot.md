ATLAS · SCREENSHOTS · AUTOPILOT · NOVEMBER 2026

# Autopilot: guided setup, then hands-off

Autopilot makes App Store screenshots, the App Preview and header and search artwork, in every language, around what a person is trying to do: say what they want, see the plan, walk away, and come back only to choose and to approve. This is the Autopilot; it replaces the earlier sheet.

**On the canvas.** Board 21 (Estados) shows every step and can be clicked. The separate Studio prototype, which still had the old tab bar, was taken off the ▶ App page on November 18.

**Toolbar update, November 21 (accepted).** Start Autopilot… left the Screenshots page. Autopilot now starts from the Autopilot button in the toolbar, which reads **Make Screenshots…** in Screenshots; its menu also has Make the App Preview… and Make Header and Search Artwork…. While it runs, the button shows the progress, and it turns purple when it needs you. Step 6 ends with **Approve All**, and the push happens in Review & Push (README · toolbar).

## Why it’s built this way: what was hard in the earlier sheet

- **One long plan.** About 12 settings in one scroll: devices, languages, captures, iPhone Duo, screenshot style, still or motion, what the search image shows, header style, templates, expected result, music, simulator options, checkpoints. Most people need three of them.
- **Stops are spread out.** The run could stop at Pick captures, Choose a direction (and a header), Watch the App Preview or the header loop, and Review & Push. It was hard to know when you would be needed, so it was hard to walk away.
- **Engine words.** Directions, template v5, capSrc, render\_artwork, Localize and check: the steps described how Atlas works, not what the person gets.
- **Review is split.** The header loop and the App Preview were approved in one step, screenshots in another place, and the final push in a third.

## The flow

| Step | Who | What the person sees |
| --- | --- | --- |
| **1 · What to make** | You | Three cards with real previews: Screenshots, App Preview video, Header and search artwork. The options that belong to each live on its card (devices; English only or every language; still or moving). One languages row. A sentence says exactly what you’ll get. |
| **2 · Look** | You | For screenshots: a new look from Claude Design, start from templates, or keep the current look. For the header: scene templates (one recommended) or let Claude Design go freely, and what the search image shows. Music, if there’s a video. One optional note for the designer. |
| **3 · Plan** | You | A timeline of who does what and how long it takes, with the two stops marked **You**. The screens, Add a Screen and Suggest Screens fold into the capture line. Two switches for fewer stops or more control. Simulator details behind one link. |
| **4 · Making it** | Autopilot | One progress bar and one sentence (“5 of 10 captures · about 6 min left”). Captures and designs appear as they arrive. Problems Autopilot fixed by itself are counted, not shown as errors. “Next for you: choose the look, in about 10 min.” **Hide · Keeps Going**; the Screenshots card then shows the progress. |
| **5 · Choose** | You | Screenshot looks and headers side by side, Claude’s pick marked, **Ask for Changes…** on each. **Use These** waits until both are chosen. |
| **6 · Review & push** | You | One tab per part (Screenshots, Header and search, App Preview), each in any language and device, with its checks beside it. A change Autopilot made (a shortened German caption) is a check to confirm, with **Looks Good** or **Edit…**. **Approve** each part; **Push to App Store…** waits until all are approved. |

## Templates: see them, know which one is used

- **What’s in use now** is said at the top of each section (“On the App Store now: Caption above device · template v4”), and marked **In use now** on its option and in the template list.
- **Preview, then pick.** Clicking a template previews it large with Lumen’s 5 real screens and captions, in any language. Picking is a separate, explicit button: **Add to My Picks**, or **✓ Pick 2 · Remove** when it’s already picked.
- **Every device.** The preview has a device switch with every device Lumen ships on: iPhone, iPad (landscape), iPhone Duo (inner display, which runs the iPad layout), Mac, Vision Pro and Apple Watch. The ones picked in step 1 are plain; the others carry a + and show a line with **Add … to the Run**, so you can try a template on a device before deciding to make it. Mac is a real 16:10 Mac App Store screenshot: Lumen’s Mac window, with its menu bar, on a MacBook, in the template’s layout. Vision Pro uses the template’s colors and type around Lumen’s window. Apple Watch shows the bare screens, since Apple frames them itself and no template applies.
- **The real template, not a sketch.** Thumbnails, the preview and My picks are drawn by the same engine as the screenshot editor, so what you see in step 2 is what the editor will start from, props, two-phone slots and all.
- **A missing language is said, then fixed.** Where Lumen’s screens were never captured in a language (iPad, iPhone Duo and Mac exist in 4 languages today), the preview marks those screenshots “English interface”. The plan says the run captures the other languages, and the review checks that every screenshot shows Lumen in its own language.
- **Review every device.** Review & push has a device switch for every device in the run (iPhone, iPad, iPhone Duo, Mac, Vision Pro, Apple Watch) in every language, drawn by the same engine, and any screenshot opens large with the language switch in the viewer.
- **See one larger.** Clicking any screenshot opens it large. Arrows step through the set, and the language switch sits in the viewer too, so you can flip between English, German, Japanese and Arabic without closing it.
- **Templates look different from each other.** Each has its own layout, not only colors: caption above or below, full-bleed with a band, stacked or poster type, left-aligned editorial, spotlight, tilted device.
- **My picks** is a tray of 3 numbered slots under the preview, with what happens next (“Claude Design makes one look from each pick… You choose one after it’s made”). Empty slots say so.
- The header scenes work the same way: a large preview of the scene in Lumen’s colors with its loop, a sentence on what Claude Design would make of it for Lumen, and the same tray.
- Afterwards the name stays visible: in Choose (“Made from your pick 1, the Cinema template”), in Review (“Look: … saved as template v5, replacing Caption above device (v4)”), and on the Screenshots page (“Live now · template: Caption above device (v4)”).

## Principles

1. **Ask for outcomes, not settings.** The first question is “What should Autopilot make?”, answered by pointing at pictures.
2. **Progressive disclosure.** Each option appears only when it applies, next to the thing it changes. Rare settings (simulator, picking captures yourself) are one click away, never in the way.
3. **Exactly two stops, announced up front.** The plan shows them; the run says how long until the next one; notifications bring you back. “Choose the look for me” makes it one.
4. **Say what you get, in the person’s words.** “180 screenshots, an App Preview in English and moving header artwork, in 18 languages”, not stages and templates.
5. **Fixes are good news.** When Autopilot handles a problem (a keyboard in the way, a caption too long), it says so calmly and lets you confirm it in the review.
6. **Review where you approve.** Seeing, checking, asking for changes and approving happen in the same place, per part.

## Where the earlier sheet’s options went

| Earlier sheet | Now |
| --- | --- |
| Presets, the make table, iPhone Duo row | Step 1 cards (Duo is a device chip; its inner/cover choice moves to the plan’s screens) |
| Captures: Capture in Simulator / Reuse | Automatic: reuse when only artwork is made; otherwise capture. Changeable in the plan’s capture line. |
| Screenshot style, Header style, What the search image shows, Expected result, Music | Step 2 · Look |
| Plan screens, Add a Screen, Suggest Screens, Simulator options, checkpoints | Step 3 · Plan (folded) |
| Pick captures | Off by default (“Let me pick the captures myself”); Claude Code picks the best of 3 tries and every pick is visible in the review. |
| Choose a direction and a header | Step 5 · Choose |
| Watch the App Preview / the header loop, Ready for review, Review & Push | Step 6 · Review & push, one tab per part |
| Cancel Run… | In the footer of steps 4–6 |

## For Claude Code

- The engine, MCP tools, prompts and checks don’t change. This is a new front for the same run.
- Replace the earlier Autopilot sheet with this flow. Nothing else uses it.
- Notifications: “Autopilot needs you: choose the look” and “…: review everything, then push”, with the time the run started.
- Times shown are estimates from the device count, languages and earlier runs; show “about”, and update them as the run goes.

To validate: whether people miss Pick captures as a default stop; whether one note for the designer is enough, or each part needs its own; and how the Look step reads for an app with no design system connected (Atlas’s starters instead of Claude Design).
