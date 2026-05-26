//
//  TranslationService.swift
//  GestionaleWWFIpad
//
//  Created by Antigravity on 17/05/26.
//

import Foundation

final class TranslationService: Sendable {
    static let shared = TranslationService()
    
    private init() {}
    
    /// Keeps CRUD flows deterministic. External translation services should run server-side,
    /// not during admin saves on the iPad.
    func translate(_ text: String, to targetLang: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return fallbackTranslate(trimmed, to: targetLang)
    }
    
    private func fallbackTranslate(_ text: String, to targetLang: String) -> String {
        // Fallback translator for offline/failure scenarios
        let lower = text.lowercased()
        if lower == "punto di interesse" {
            switch targetLang {
            case "en": return "Point of Interest"
            case "de": return "Point of Interest (DE)"
            case "fr": return "Point d'intérêt"
            default: break
            }
        }
        
        // Add a suffix to indicate dynamic translation fallback
        switch targetLang {
        case "en": return "[EN] \(text)"
        case "de": return "[DE] \(text)"
        case "fr": return "[FR] \(text)"
        default: return "[\(targetLang.uppercased())] \(text)"
        }
    }
}
