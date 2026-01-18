//
//  pantryTests.swift
//  pantryTests
//
//  Created by alex on 1/1/26.
//

import Testing
@testable import pantry

struct PrepRiskTests {

    // MARK: - init(fromComplexity:)

    @Test func initFromComplexity_quick_returnsFast() {
        let result = PrepRisk(fromComplexity: "quick")
        #expect(result == .fast)
    }

    @Test func initFromComplexity_normal_returnsNormal() {
        let result = PrepRisk(fromComplexity: "normal")
        #expect(result == .normal)
    }

    @Test func initFromComplexity_long_returnsEffortful() {
        let result = PrepRisk(fromComplexity: "long")
        #expect(result == .effortful)
    }

    @Test func initFromComplexity_unknownValue_defaultsToNormal() {
        let result = PrepRisk(fromComplexity: "unknown")
        #expect(result == .normal)
    }

    @Test func initFromComplexity_emptyString_defaultsToNormal() {
        let result = PrepRisk(fromComplexity: "")
        #expect(result == .normal)
    }

    // MARK: - displayLabel

    @Test func displayLabel_fast_returnsEasy() {
        #expect(PrepRisk.fast.displayLabel == "Easy")
    }

    @Test func displayLabel_normal_returnsNormal() {
        #expect(PrepRisk.normal.displayLabel == "Normal")
    }

    @Test func displayLabel_effortful_returnsEffortful() {
        #expect(PrepRisk.effortful.displayLabel == "Effortful")
    }
}

// MARK: - APIMeal to Meal Conversion Tests

struct APIMealConversionTests {

    @Test func toMeal_onePotValue_preservesOnePot() {
        let apiMeal = APIMeal(
            id: 1,
            title: "Chicken Alfredo Pasta",
            protein: "chicken",
            starch: "pasta",
            vegOrFruit: ["broccoli"],
            cuisine: "American",
            method: "stovetop",
            onePotOrPan: "one-pot",
            complexity: "normal",
            estimatedTotalMinutes: 40,
            seasonality: "year-round",
            containsGluten: true,
            containsDairy: true,
            containsNuts: false,
            tags: ["family-friendly"]
        )

        let meal = apiMeal.toMeal()

        #expect(meal.onePotOrPan == "one-pot")
    }

    @Test func toMeal_onePanValue_preservesOnePan() {
        let apiMeal = APIMeal(
            id: 2,
            title: "Sheet Pan Salmon",
            protein: "salmon",
            starch: "potatoes",
            vegOrFruit: ["green beans"],
            cuisine: "American",
            method: "oven",
            onePotOrPan: "one-pan",
            complexity: "quick",
            estimatedTotalMinutes: 30,
            seasonality: "year-round",
            containsGluten: false,
            containsDairy: false,
            containsNuts: false,
            tags: ["seafood"]
        )

        let meal = apiMeal.toMeal()

        #expect(meal.onePotOrPan == "one-pan")
    }

    @Test func toMeal_noValue_convertsToNil() {
        let apiMeal = APIMeal(
            id: 3,
            title: "Turkey Burgers",
            protein: "turkey",
            starch: "buns",
            vegOrFruit: ["lettuce"],
            cuisine: "American",
            method: "grill",
            onePotOrPan: "no",
            complexity: "normal",
            estimatedTotalMinutes: 35,
            seasonality: "year-round",
            containsGluten: true,
            containsDairy: false,
            containsNuts: false,
            tags: ["burgers"]
        )

        let meal = apiMeal.toMeal()

        #expect(meal.onePotOrPan == nil)
    }

    @Test func toMeal_preservesTitle_withoutPrefix() {
        let apiMeal = APIMeal(
            id: 1,
            title: "Chicken Alfredo Pasta with Broccoli",
            protein: "chicken",
            starch: "pasta",
            vegOrFruit: ["broccoli"],
            cuisine: "American",
            method: "stovetop",
            onePotOrPan: "one-pot",
            complexity: "normal",
            estimatedTotalMinutes: 40,
            seasonality: "year-round",
            containsGluten: true,
            containsDairy: true,
            containsNuts: false,
            tags: []
        )

        let meal = apiMeal.toMeal()

        #expect(meal.title == "Chicken Alfredo Pasta with Broccoli")
        #expect(!meal.title.hasPrefix("One-Pot:"))
    }
}

// MARK: - Meal Model Tests

struct MealModelTests {

    @Test func init_withOnePotOrPan_storesValue() {
        let meal = Meal(
            title: "Test Meal",
            prepRisk: .normal,
            onePotOrPan: "one-pot"
        )

        #expect(meal.onePotOrPan == "one-pot")
    }

    @Test func init_withoutOnePotOrPan_defaultsToNil() {
        let meal = Meal(
            title: "Test Meal",
            prepRisk: .normal
        )

        #expect(meal.onePotOrPan == nil)
    }
}
