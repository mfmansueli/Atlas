//
//  LiveScreenshotsServices+Push.swift
//  Atlas
//

import Foundation

extension LiveScreenshotsServices: ScreenshotPushProviding {
    var pushing: any ScreenshotPushServices {
        LiveScreenshotPushServices(client: client)
    }
}
