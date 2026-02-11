//
//  KillingPartApp.swift
//  KillingPart
//
//  Created by 이병찬 on 2/7/26.
//

import SwiftUI

@main
struct KillingPartApp: App {
    init() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            AppFont.registerPaperlogyFonts()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView()
        }
    }
}
