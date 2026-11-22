---
id: shots
group: listing
title: Screenshots and Autopilot
summary: Screenshots for every device and language, from templates or from a new look by Claude.
keywords: screenshots, screenshot, by hand, replace, delete, reorder, upload, import, folder, fastlane, autopilot, template, templates, caption, captions, app preview, video, header, simulator, xcode, claude design, device
showMe: section:screenshots
related: events, assistant
---
Each set is a template plus your app’s screens plus a caption per language. Change the caption and every device follows.

## Autopilot

1. Say what to make: screenshots, an App Preview, header artwork.
2. Choose the look.
3. Check the plan and start it. Atlas captures your app in the Simulator, designs, and writes every language.
4. Come back twice: to choose the look, and to review and push.

When a device has no simulator yet but this Mac has what it needs (Xcode knows the device and its runtime is installed), Atlas makes the simulator itself, in any run, including one that redoes only some captures. Its card goes away by itself. Only what Atlas can’t do waits for you: a runtime to download (several GB, Install on its card), a helper to save again, or a simulator Xcode couldn’t make (the card says why).

> Autopilot needs Xcode on this Mac and an assistant connected. It is part of Atlas Pro.

## Redo only some captures

When some screens changed (new phrases in one language, a redesigned screen), you don’t need a whole new run.

1. Open Screenshots → Captures. ⌘-click captures, or click a language’s name or a screen’s column to choose all of them.
2. Choose Replace… to put in a PNG of your own, or drop one on the capture. It must be that device’s full-size screenshot.
3. Or choose Capture Again with Claude Code: a run for just those captures. The plan, the look and the captions stay, and Review & Push sends only the images that change.

- Claude Code can ask for it too. Its request shows in Screenshots with Accept and Decline.
- It works even when no Autopilot run was saved for the app, as long as the set has captures: the run is made from them, with their screens, devices, iPhone Duo poses and sizes. Only App Preview moments need the run that recorded them.
- Captures Claude Code marked as Out of date keep that label until a new one takes their place.
- To let Claude Code open these runs without asking, turn on Settings → Screenshots → Let Claude Code open capture-only runs. Nothing is pushed either way.

> A product page’s screens can be captured again the same way, up to three a page.

## Screenshots by hand

You don’t need Autopilot or an assistant to change a set. Open a language in Screenshots, pick the device, and work on its screenshots there. Every change waits in Review & Push, with Undo.

1. Click a screenshot to select it. The bar above the set says where it comes from. Use ◀ ▶ to move it, Replace… to put in a file of your own, Delete…, or Undo Change.
2. Click the Add Screenshots tile or drop PNG or JPEG files on it, to add them after the last one. A set holds up to 10.
3. Manage has Add Screenshots…, Import a Folder… and Delete All in that language.

- Replace and Delete work in that language only, or in every language that has its own screenshots.
- A file you put in place of one Atlas made from the template isn’t redrawn when the template or the caption changes. Undo Change brings the template version back.
- A language without screenshots of its own shows the primary language’s. Start from English (U.S.) copies them in, ready to replace one by one, or Add Its Own… starts fresh.
- Import a Folder reads folders named by language, as fastlane makes them (de-DE/iphone-6.9/01.png). The device comes from the folder or file name, or from the image’s size, and the order from the leading number. A table shows what happens to each language before anything changes.
- The primary language must keep at least one screenshot on each device: Apple needs it.

> Atlas never scales a screenshot: the file must be one of the device’s sizes (iPhone 6.9″ 1320 × 2868 or 1290 × 2796, iPad 13″ 2064 × 2752 or 2048 × 2732, Mac 2880 × 1800, 2560 × 1600, 1440 × 900 or 1280 × 800), upright or turned, without transparency. Pushing uploads first and deletes after, so a failed upload never leaves a language with fewer screenshots.
