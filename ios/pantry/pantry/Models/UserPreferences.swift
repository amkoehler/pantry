//
//  UserPreferences.swift
//  pantry
//

import Foundation
import SwiftData

/// Stores user settings and onboarding state.
/// This should be treated as a singleton - only one instance per user.
@Model
class UserPreferences {
    var id: UUID = UUID()

    /// Dietary restriction toggles - hard filters that exclude non-compliant meals
    var glutenFree: Bool
    var dairyFree: Bool
    var nutFree: Bool

    /// Default number of dinners per week (1-7), defaults to 5 (Mon-Fri)
    var defaultDinnerCount: Int

    /// Whether user has completed the onboarding flow
    var hasCompletedOnboarding: Bool

    /// Last time meals were synced from the API (for incremental sync)
    var lastMealSyncDate: Date?

    init(
        id: UUID = UUID(),
        glutenFree: Bool = false,
        dairyFree: Bool = false,
        nutFree: Bool = false,
        defaultDinnerCount: Int = 5,
        hasCompletedOnboarding: Bool = false,
        lastMealSyncDate: Date? = nil
    ) {
        self.id = id
        self.glutenFree = glutenFree
        self.dairyFree = dairyFree
        self.nutFree = nutFree
        self.defaultDinnerCount = defaultDinnerCount
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastMealSyncDate = lastMealSyncDate
    }
}
