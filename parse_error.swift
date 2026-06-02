import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Data/Sources/Supabase/SupabaseConfig.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// We want to add a helper function inside SupabaseConfig to parse human readable errors
let helperFunction = """
    private func extractUserFriendlyError(from data: Data, fallback: String) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return fallback
        }
        
        // Translate common Supabase database messages into Italian for the manager
        if message.contains("bundle light is missing") || message.contains("not ready") {
            return "Impossibile pubblicare il percorso: i pacchetti dati (bundle) per l'uso offline non sono ancora pronti o sono obsoleti. Salva prima come bozza e attendi la generazione."
        }
        if message.contains("duplicate key value") {
            return "Un elemento con questo nome o codice esiste già nel sistema."
        }
        if message.contains("foreign key constraint") {
            return "Impossibile completare l'operazione perché questo elemento è collegato ad altri dati (es. percorsi o eventi attivi)."
        }
        
        return message // Return the parsed English message if no translation exists
    }
"""

if !content.contains("extractUserFriendlyError") {
    // Insert it before the last closing brace of SupabaseConfig
    if let lastBrace = content.range(of: "}", options: .backwards, range: content.startIndex..<content.range(of: "struct SupabaseUser")!.lowerBound) {
        content.insert(contentsOf: "\n" + helperFunction + "\n", at: lastBrace.lowerBound)
    }
}

// Replace all instances of `String(data: data, encoding: .utf8) ?? "Unknown error"` with `extractUserFriendlyError(from: data, fallback: ...)`
content = content.replacingOccurrences(of: """
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("RPC \\(functionName) failed (\\(httpResponse.statusCode)): \\(errorBody)")
""", with: """
            let errorBody = extractUserFriendlyError(from: data, fallback: String(data: data, encoding: .utf8) ?? "Unknown error")
            throw SupabaseError.apiError(errorBody)
""")

content = content.replacingOccurrences(of: """
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("Edge Function \\(functionName) failed (\\(httpResponse.statusCode)): \\(errorBody)")
""", with: """
            let errorBody = extractUserFriendlyError(from: data, fallback: String(data: data, encoding: .utf8) ?? "Unknown error")
            throw SupabaseError.apiError(errorBody)
""")

content = content.replacingOccurrences(of: """
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("Insert into \\(table) failed (\\(httpResponse.statusCode)): \\(errorBody)")
""", with: """
            let errorBody = extractUserFriendlyError(from: data, fallback: String(data: data, encoding: .utf8) ?? "Unknown error")
            throw SupabaseError.apiError(errorBody)
""")

content = content.replacingOccurrences(of: """
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("Upsert into \\(table) failed (\\(httpResponse.statusCode)): \\(errorBody)")
""", with: """
            let errorBody = extractUserFriendlyError(from: data, fallback: String(data: data, encoding: .utf8) ?? "Unknown error")
            throw SupabaseError.apiError(errorBody)
""")

content = content.replacingOccurrences(of: """
            let errorBody = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseError.storageError("Upload failed (\\(httpResponse.statusCode)): \\(errorBody)")
""", with: """
            let errorBody = extractUserFriendlyError(from: responseData, fallback: String(data: responseData, encoding: .utf8) ?? "Unknown error")
            throw SupabaseError.storageError(errorBody)
""")

content = content.replacingOccurrences(of: """
        case .apiError(let msg):     return "Errore API: \\(msg)"
""", with: """
        case .apiError(let msg):     return msg
""")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Added user friendly error extraction to SupabaseConfig")
