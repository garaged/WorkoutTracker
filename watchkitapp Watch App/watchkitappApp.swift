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
        if let seed = WatchUITestSeed.current {
            WatchConnectivityClient.shared.applyUITestSeed(seed)
        } else {
            WatchConnectivityClient.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
