//
//  MessageCycler.swift
//  pantry
//
//  Pure value type for cycling through a list of messages.
//  Extracted for testability from CookingSpinner.
//

import Foundation

/// Cycles through an array of messages in order, wrapping around at the end.
struct MessageCycler {
    let messages: [String]
    private(set) var currentIndex: Int = 0

    init(messages: [String]) {
        precondition(!messages.isEmpty, "Messages cannot be empty")
        self.messages = messages
    }

    /// The message at the current index.
    var currentMessage: String {
        messages[currentIndex]
    }

    /// Advances to the next message, wrapping around to the first after the last.
    mutating func advance() {
        currentIndex = (currentIndex + 1) % messages.count
    }
}

// MARK: - Cooking Messages

extension MessageCycler {
    /// Standard cooking-themed messages for the loading spinner.
    static let cookingMessages = [
        "Sautéing...",
        "Simmering...",
        "Toasting...",
        "Chopping...",
        "Whisking...",
        "Seasoning..."
    ]

    /// Creates a MessageCycler with the standard cooking messages.
    static func cooking() -> MessageCycler {
        MessageCycler(messages: cookingMessages)
    }
}
