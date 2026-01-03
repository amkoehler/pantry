//
//  ContentView.swift
//  pantry
//
//  Created by alex on 1/1/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ThisWeekView()
                .tabItem {
                    Label("This Week", systemImage: "calendar")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
