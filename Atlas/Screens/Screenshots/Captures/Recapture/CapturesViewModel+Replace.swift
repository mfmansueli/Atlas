//
//  CapturesViewModel+Replace.swift
//  Atlas
//

import Foundation

/// Replace…: one capture swapped for a PNG dropped on it or chosen, with no
/// run. The template and captions stay, so Review & Push sends only that
/// image.
extension CapturesViewModel {
    /// Replace… on a cell: the open panel for it.
    func chooseReplacement(for cell: CaptureCellKey) {
        replaceTarget = cell
        isReplaceImporterPresented = true
    }

    /// Puts `url` in `cell`; a PNG of the wrong device or too small is
    /// refused, as at import.
    func replace(_ cell: CaptureCellKey, with url: URL, securityScoped: Bool = false) async {
        let isAccessing = securityScoped && url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        let size = CaptureFolderScanner.pixelSize(of: url)
        if let refusal = CaptureReplacement.refusal(size: size, for: cell.displayType) {
            errorMessage = refusal
            return
        }
        guard let size, var document = screenshots.document else { return }
        isReplacing = true
        defer { isReplacing = false }
        let captures: [ScreenshotCapture]
        do {
            captures = try await screenshots.services.importCaptures([CaptureReplacement.item(url, size: size, in: cell)], for: screenshots.app)
        } catch let error as CaptureImportError {
            errorMessage = error.localizedDescription
            return
        } catch {
            errorMessage = AppleErrorCopy(String(localized: "The capture wasn’t replaced.", comment: "kind:error"), error: error).text
            return
        }
        captures.forEach { document.captures.add($0) }
        await screenshots.commit(document)
        errorMessage = nil
        selection.remove(cell)
        let name = document.slotName(cell.slot)
        screenshots.notice = String(localized: "Replaced \(name) in \(cell.locale). Only its screenshot changes in Review & Push.")
    }
}
