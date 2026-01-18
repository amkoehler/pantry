//
//  Increment1Tests.swift
//  pantryTests
//
//  Tests for Increment 1: Check-In Simplification
//

import Testing
@testable import pantry

// MARK: - MessageCycler Tests

struct MessageCyclerTests {

    // MARK: - Initialization

    @Test func init_startsAtIndexZero() {
        let cycler = MessageCycler(messages: ["A", "B", "C"])
        #expect(cycler.currentIndex == 0)
    }

    @Test func init_preservesMessages() {
        let messages = ["First", "Second", "Third"]
        let cycler = MessageCycler(messages: messages)
        #expect(cycler.messages == messages)
    }

    // MARK: - currentMessage

    @Test func currentMessage_returnsMessageAtCurrentIndex() {
        let cycler = MessageCycler(messages: ["Alpha", "Beta", "Gamma"])
        #expect(cycler.currentMessage == "Alpha")
    }

    // MARK: - advance()

    @Test func advance_incrementsIndex() {
        var cycler = MessageCycler(messages: ["A", "B", "C"])
        cycler.advance()
        #expect(cycler.currentIndex == 1)
        #expect(cycler.currentMessage == "B")
    }

    @Test func advance_wrapsAroundToZero() {
        var cycler = MessageCycler(messages: ["A", "B", "C"])
        cycler.advance() // 1
        cycler.advance() // 2
        cycler.advance() // 0 (wrap)
        #expect(cycler.currentIndex == 0)
        #expect(cycler.currentMessage == "A")
    }

    @Test func advance_cyclesThroughAllMessages() {
        var cycler = MessageCycler(messages: ["One", "Two", "Three", "Four"])
        var visited: [String] = []

        for _ in 0..<4 {
            visited.append(cycler.currentMessage)
            cycler.advance()
        }

        #expect(visited == ["One", "Two", "Three", "Four"])
    }

    @Test func advance_multipleFullCycles() {
        var cycler = MessageCycler(messages: ["X", "Y"])

        // Two full cycles
        for _ in 0..<4 {
            cycler.advance()
        }

        #expect(cycler.currentIndex == 0)
    }
}

// MARK: - Cooking Messages Tests

struct CookingMessagesTests {

    @Test func cookingMessages_hasExactlySixMessages() {
        let messages = MessageCycler.cookingMessages
        #expect(messages.count == 6)
    }

    @Test func cookingMessages_startsWithSauteeing() {
        let messages = MessageCycler.cookingMessages
        #expect(messages.first == "Sautéing...")
    }

    @Test func cookingMessages_endsWithSeasoning() {
        let messages = MessageCycler.cookingMessages
        #expect(messages.last == "Seasoning...")
    }

    @Test func cookingMessages_containsExpectedVerbs() {
        let messages = MessageCycler.cookingMessages
        #expect(messages.contains("Simmering..."))
        #expect(messages.contains("Toasting..."))
        #expect(messages.contains("Chopping..."))
        #expect(messages.contains("Whisking..."))
    }

    @Test func cooking_factoryCreatesValidCycler() {
        let cycler = MessageCycler.cooking()
        #expect(cycler.messages.count == 6)
        #expect(cycler.currentIndex == 0)
        #expect(cycler.currentMessage == "Sautéing...")
    }
}

// MARK: - Dirty State Logic Tests

/// Tests for the dirty state comparison logic used in CheckInView.
/// This tests the pure logic pattern: comparing current vs last-applied values.
struct DirtyStateLogicTests {

    /// Simulates the dirty state check used in CheckInView
    private func hasUnappliedChanges(current: String, lastApplied: String) -> Bool {
        current != lastApplied
    }

    @Test func hasUnappliedChanges_sameValues_returnsFalse() {
        let result = hasUnappliedChanges(current: "chicken", lastApplied: "chicken")
        #expect(result == false)
    }

    @Test func hasUnappliedChanges_differentValues_returnsTrue() {
        let result = hasUnappliedChanges(current: "beef", lastApplied: "chicken")
        #expect(result == true)
    }

    @Test func hasUnappliedChanges_bothEmpty_returnsFalse() {
        let result = hasUnappliedChanges(current: "", lastApplied: "")
        #expect(result == false)
    }

    @Test func hasUnappliedChanges_changedToEmpty_returnsTrue() {
        let result = hasUnappliedChanges(current: "", lastApplied: "chicken")
        #expect(result == true)
    }

    @Test func hasUnappliedChanges_changedFromEmpty_returnsTrue() {
        let result = hasUnappliedChanges(current: "chicken", lastApplied: "")
        #expect(result == true)
    }
}
