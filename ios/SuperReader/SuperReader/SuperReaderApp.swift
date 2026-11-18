//
//  SuperReaderApp.swift
//  SuperReader
//
//  Created by Andrea Zampierolo on 12/12/25.
//

import SwiftUI

@main
struct SuperReaderApp: App {
    @UIApplicationDelegateAdaptor(SuperReaderAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
