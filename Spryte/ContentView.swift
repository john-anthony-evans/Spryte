//
//  ContentView.swift
//  Spryte
//
//  Created by John Evans on 12/13/25.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var splashUIHidden = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    private var effectiveColorScheme: ColorScheme? {
        // Force dark mode on Splash Screen tab
        if selectedTab == 1 {
            return .dark
        }
        return appearanceMode.colorScheme
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("App Icons", systemImage: "app.grid", value: 0) {
                IconsTab(appearanceMode: $appearanceMode)
            }

            Tab("Splash Screen", systemImage: "app.background.dotted", value: 1) {
                SplashTab(isUIHidden: $splashUIHidden)
            }
        }
        .toolbar(splashUIHidden ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.25), value: splashUIHidden)
        .preferredColorScheme(effectiveColorScheme)
    }
}

#Preview {
    ContentView()
}
