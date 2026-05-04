//
//  KillingPartApp.swift
//  KillingPart
//
//  Created by 이병찬 on 2/7/26.
//

import SwiftUI
import KakaoSDKAuth
import KakaoSDKCommon
import GoogleSignIn

@main
struct KillingPartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            configureKakaoSDK()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }

                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }

    private func configureKakaoSDK() {
        let appKey = (Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !appKey.isEmpty, appKey != "YOUR_KAKAO_NATIVE_APP_KEY" else {
            return
        }

        KakaoSDK.initSDK(appKey: appKey)
    }
}
