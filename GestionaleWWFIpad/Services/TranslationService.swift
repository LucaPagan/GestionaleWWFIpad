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
    
    /// Translates a text from Italian to a target language.
    /// Uses MyMemory free API, and falls back to a clean mock system if offline or failed.
    func translate(_ text: String, to targetLang: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let langPair = "it|\(targetLang)"
        guard let encodedText = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=\(langPair)") else {
            return fallbackTranslate(trimmed, to: targetLang)
        }
        
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return fallbackTranslate(trimmed, to: targetLang)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let responseData = json["responseData"] as? [String: Any],
                   let translation = responseData["translatedText"] as? String,
                   !translation.isEmpty,
                   translation != trimmed {
                    return translation
                }
                
                if let matches = json["matches"] as? [[String: Any]],
                   let firstMatch = matches.first,
                   let translation = firstMatch["translation"] as? String,
                   !translation.isEmpty,
                   translation != trimmed {
                    return translation
                }
            }
        } catch {
            print("Translation API error: \(error)")
        }
        
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
