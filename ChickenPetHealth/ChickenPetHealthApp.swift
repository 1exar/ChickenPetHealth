//
//  ChickenPetHealthApp.swift
//  ChickenPetHealth
//
//  Created by Дмитрий on 22.11.2025.
//

import SwiftUI

@main
struct ChickenPetHealthApp: App {
    @StateObject private var store = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
