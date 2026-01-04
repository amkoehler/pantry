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
