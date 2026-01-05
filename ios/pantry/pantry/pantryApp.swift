//
//  PantryApp.swift
//  pantry
//
//  Created by alex on 1/1/26.
//

import SwiftUI
import SwiftData

@main
struct PantryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            WeeklyPlan.self,
            PlannedMeal.self,
            MealOutcome.self,
            UserPreferences.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(PantryTheme.Colors.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

/// Routes between onboarding and main app based on user state.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    /// Track onboarding completion separately to force view updates
    @State private var showMainApp = false

    var body: some View {
        Group {
            if showMainApp {
                ContentView()
            } else {
                OnboardingView(onComplete: {
                    showMainApp = true
                })
            }
        }
        .onAppear {
            // Check if already completed onboarding
            showMainApp = preferences.first?.hasCompletedOnboarding == true
        }
    }
}
