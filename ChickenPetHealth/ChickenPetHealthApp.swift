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

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

private extension ChickenPetHealthApp {
    func configureAppearance() {
        // Navigation bar titles always white
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.backgroundColor = UIColor(Color(hex: "#1B3B36"))
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().tintColor = .white

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

    }
}
