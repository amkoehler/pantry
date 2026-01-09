import Foundation

/// Errors that can occur during API operations
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(underlying: Error)
    case httpError(statusCode: Int, message: String?)
    case decodingError(underlying: Error)
    case serverError(message: String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .noData:
            return "No data received from server"
        }
    }

    /// User-friendly message for display in UI
    var userMessage: String {
        switch self {
        case .networkError:
            return "Unable to connect. Check your internet connection."
        case .serverError:
            return "Something went wrong on our end. Try again later."
        case .httpError(let code, _) where code >= 500:
            return "Something went wrong on our end. Try again later."
        default:
            return "Unable to load your plan. Try again."
        }
    }
}

/// Errors for Foundation Models operations
enum FoundationModelsError: Error, LocalizedError {
    case unavailable
    case sessionInitFailed(underlying: Error)
    case generationFailed(underlying: Error)
    case parsingFailed
    case noSuggestionsGenerated

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Foundation Models not available on this device"
        case .sessionInitFailed(let error):
            return "Failed to initialize AI session: \(error.localizedDescription)"
        case .generationFailed(let error):
            return "AI generation failed: \(error.localizedDescription)"
        case .parsingFailed:
            return "Failed to parse AI response"
        case .noSuggestionsGenerated:
            return "No swap suggestions could be generated"
        }
    }
}
