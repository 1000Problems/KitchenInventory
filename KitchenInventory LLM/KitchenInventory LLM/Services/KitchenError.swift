//
//  KitchenError.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation

enum KitchenError: LocalizedError {
    case noAPIKey
    case networkUnavailable
    case apiError(Int, String)
    case parseError
    case speechUnavailable
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured"
        case .networkUnavailable:
            return "No internet connection. Try again when online."
        case .apiError(let status, let message):
            switch status {
            case 401: return "Invalid API key. Check your key in Settings."
            case 429: return "Too many requests. Wait a moment and try again."
            case 500...599: return "Service temporarily unavailable. Try again shortly."
            default: return "API error (\(status)): \(message)"
            }
        case .parseError:
            return "Couldn't understand the response. Try again."
        case .speechUnavailable:
            return "Speech recognition isn't available on this device. You can still type to add items."
        case .microphoneDenied:
            return "Microphone access is needed for voice input. Enable it in Settings > Privacy > Microphone."
        }
    }
}
