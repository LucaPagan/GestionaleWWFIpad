//
//  AppConfig.swift
//  GestionaleWWFIpad
//

import Foundation

enum AppConfig {
    static var supabaseURL: String {
        return value(for: "SUPABASE_URL")
    }

    static var supabaseAnonKey: String {
        return value(for: "SUPABASE_ANON_KEY")
    }

    private static func value(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key] as? String else {
            fatalError("Manca il file Secrets.plist o la chiave \(key) non è impostata. Segui la guida per impostare le API keys in sicurezza.")
        }
        return value
    }
}
