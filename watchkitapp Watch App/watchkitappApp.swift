//
//  watchkitappApp.swift
//  watchkitapp Watch App
//
//  Created by Max Valdez on 08/03/26.
//

import SwiftUI

@main
struct watchkitapp_Watch_AppApp: App {
    init() {
        WatchConnectivityClient.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
