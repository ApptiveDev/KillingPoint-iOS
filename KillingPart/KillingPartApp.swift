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
        AppFont.registerPaperlogyFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView()
        }
    }
}
