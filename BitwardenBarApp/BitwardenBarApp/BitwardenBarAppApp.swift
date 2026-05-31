//
//  BitwardenBarAppApp.swift
//  BitwardenBarApp
//
//  Created by hz.impact on 5/31/26.
//

import SwiftUI
import BitwardenBar

@main
struct BitwardenBarAppApp: App {
    @NSApplicationDelegateAdaptor(BitwardenBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
