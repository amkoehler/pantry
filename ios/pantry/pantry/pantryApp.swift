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
            // Models will be added here as they're implemented:
            // Meal.self,
            // WeeklyPlan.self,
            // PlannedMeal.self,
            // MealOutcome.self,
            // UserPreferences.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
