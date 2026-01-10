//
//  WeeklyPlanViewModelTests.swift
//  pantryTests
//
//  Tests for WeeklyPlanViewModel weekend week selection logic.
//

import Testing
import SwiftData
@testable import pantry

/// Mock date provider for testing with fixed dates
struct MockDateProvider: DateProviding {
    let fixedDate: Date
    func now() -> Date { fixedDate }
}

@MainActor
struct WeeklyPlanViewModelTests {

    // MARK: - Helper Methods

    /// Create a date for a specific day of week in January 2026
    /// Jan 5, 2026 is Monday, so: 5=Mon(1), 6=Tue(2), ..., 10=Sat(6), 11=Sun(7)
    private func date(forDayOfWeek dayOfWeek: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 4 + dayOfWeek  // dayOfWeek 1 (Mon) -> Jan 5
        components.hour = 12  // Noon to avoid timezone edge cases
        return Calendar.current.date(from: components)!
    }

    /// Create an in-memory model container for testing
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WeeklyPlan.self, PlannedMeal.self, Meal.self, MealOutcome.self, UserPreferences.self,
            configurations: config
        )
    }

    // MARK: - Weekend Week Selection Tests

    @Test func selectedWeek_onMonday_defaultsToCurrent() throws {
        let container = try createTestContainer()
        let monday = date(forDayOfWeek: 1)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: monday)
        )

        #expect(vm.selectedWeek == .current)
    }

    @Test func selectedWeek_onTuesday_defaultsToCurrent() throws {
        let container = try createTestContainer()
        let tuesday = date(forDayOfWeek: 2)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: tuesday)
        )

        #expect(vm.selectedWeek == .current)
    }

    @Test func selectedWeek_onWednesday_defaultsToCurrent() throws {
        let container = try createTestContainer()
        let wednesday = date(forDayOfWeek: 3)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: wednesday)
        )

        #expect(vm.selectedWeek == .current)
    }

    @Test func selectedWeek_onThursday_defaultsToCurrent() throws {
        let container = try createTestContainer()
        let thursday = date(forDayOfWeek: 4)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: thursday)
        )

        #expect(vm.selectedWeek == .current)
    }

    @Test func selectedWeek_onFriday_defaultsToCurrent() throws {
        let container = try createTestContainer()
        let friday = date(forDayOfWeek: 5)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: friday)
        )

        #expect(vm.selectedWeek == .current)
    }

    @Test func selectedWeek_onSaturday_defaultsToNext() throws {
        let container = try createTestContainer()
        let saturday = date(forDayOfWeek: 6)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: saturday)
        )

        #expect(vm.selectedWeek == .next)
    }

    @Test func selectedWeek_onSunday_defaultsToNext() throws {
        let container = try createTestContainer()
        let sunday = date(forDayOfWeek: 7)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: sunday)
        )

        #expect(vm.selectedWeek == .next)
    }

    // MARK: - currentDayOfWeek Tests

    @Test func currentDayOfWeek_onMonday_returns1() throws {
        let container = try createTestContainer()
        let monday = date(forDayOfWeek: 1)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: monday)
        )

        #expect(vm.currentDayOfWeek() == 1)
    }

    @Test func currentDayOfWeek_onSaturday_returns6() throws {
        let container = try createTestContainer()
        let saturday = date(forDayOfWeek: 6)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: saturday)
        )

        #expect(vm.currentDayOfWeek() == 6)
    }

    @Test func currentDayOfWeek_onSunday_returns7() throws {
        let container = try createTestContainer()
        let sunday = date(forDayOfWeek: 7)

        let vm = WeeklyPlanViewModel(
            modelContext: container.mainContext,
            dateProvider: MockDateProvider(fixedDate: sunday)
        )

        #expect(vm.currentDayOfWeek() == 7)
    }
}
