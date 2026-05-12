//
//  SupabaseConfig.swift
//  GestionaleWWFIpad
//
//  Centralized Supabase client configuration.
//  Provides a single shared instance for all services.
//

import Foundation

// MARK: - SupabaseConfig

/// Centralized Supabase client for all backend communication.
///
/// Usage:
/// ```swift
/// let response = try await SupabaseConfig.shared.rpc("upsert_poi", params: poi.toSupabaseParams())
/// ```
///
/// Note: This is a lightweight REST wrapper that does NOT depend on the
/// official Supabase Swift SDK. This keeps the project dependency-free
/// and gives full control over network behavior for offline-first design.
final class SupabaseConfig: @unchecked Sendable {

    // MARK: - Singleton
    static let shared = SupabaseConfig()

    // MARK: - Configuration
    // ⚠️ These are publishable keys — safe to include in client code.
    // The anon key is restricted by RLS policies.
    let projectURL = "https://iwnobncyjorizoecehll.supabase.co"
    let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3bm9ibmN5am9yaXpvZWNlaGxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNTEyNDMsImV4cCI6MjA5MzkyNzI0M30.dVvX2k-avrYFqoaWz4aDrRddCjMXm4UKE6QcSHjp3MQ"

    // MARK: - Session State
    private var accessToken: String? {
        didSet {
            if let token = accessToken { UserDefaults.standard.set(token, forKey: "sb_access_token") }
            else { UserDefaults.standard.removeObject(forKey: "sb_access_token") }
        }
    }
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken { UserDefaults.standard.set(token, forKey: "sb_refresh_token") }
            else { UserDefaults.standard.removeObject(forKey: "sb_refresh_token") }
        }
    }
    private var sessionUser: SupabaseUser? {
        didSet {
            if let user = sessionUser {
                UserDefaults.standard.set(user.id, forKey: "sb_user_id")
                UserDefaults.standard.set(user.email, forKey: "sb_user_email")
            } else {
                UserDefaults.standard.removeObject(forKey: "sb_user_id")
                UserDefaults.standard.removeObject(forKey: "sb_user_email")
            }
        }
    }

    private init() {
        if let token = UserDefaults.standard.string(forKey: "sb_access_token"),
           let id = UserDefaults.standard.string(forKey: "sb_user_id") {
            self.accessToken = token
            self.refreshToken = UserDefaults.standard.string(forKey: "sb_refresh_token")
            let email = UserDefaults.standard.string(forKey: "sb_user_email")
            self.sessionUser = SupabaseUser(id: id, email: email)
        }
    }

    // MARK: - Auth

    /// Sign in with email/password via Supabase Auth
    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.authError("Login failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        accessToken = json?["access_token"] as? String
        refreshToken = json?["refresh_token"] as? String

        if let userDict = json?["user"] as? [String: Any] {
            sessionUser = SupabaseUser(
                id: userDict["id"] as? String ?? "",
                email: userDict["email"] as? String
            )
        }
    }

    /// Sign out
    func signOut() async throws {
        if let token = accessToken {
            let url = URL(string: "\(projectURL)/auth/v1/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            _ = try? await URLSession.shared.data(for: request)
        }
        accessToken = nil
        refreshToken = nil
        sessionUser = nil
    }

    /// Get current session if available
    func currentSession() async -> SupabaseSession? {
        guard let token = accessToken, let user = sessionUser else { return nil }
        return SupabaseSession(accessToken: token, user: user)
    }

    // MARK: - REST API

    /// Call a Supabase RPC function
    func rpc(_ functionName: String, params: [String: Any?]) async throws -> [String: Any]? {
        let url = URL(string: "\(projectURL)/rest/v1/rpc/\(functionName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        // Filter out nil values
        let cleanParams = params.compactMapValues { $0 }
        request.httpBody = try JSONSerialization.data(withJSONObject: cleanParams)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("RPC \(functionName) failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Fetch rows from a table via REST (GET)
    func fetch(from table: String, query: String = "") async throws -> [[String: Any]] {
        let urlString = "\(projectURL)/rest/v1/\(table)\(query.isEmpty ? "" : "?\(query)")"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.apiError("Fetch from \(table) failed")
        }

        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    // MARK: - Storage

    /// Upload a file to Supabase Storage
    func uploadFile(bucket: String, path: String, data: Data, contentType: String = "image/jpeg") async throws -> String {
        let url = URL(string: "\(projectURL)/storage/v1/object/\(bucket)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseError.storageError("Upload failed: \(errorBody)")
        }

        // Return public URL
        return "\(projectURL)/storage/v1/object/public/\(bucket)/\(path)"
    }

    /// Get public URL for a storage object
    func publicURL(bucket: String, path: String) -> String {
        "\(projectURL)/storage/v1/object/public/\(bucket)/\(path)"
    }
}

// MARK: - Supporting Types

struct SupabaseUser {
    let id: String
    let email: String?
}

struct SupabaseSession {
    let accessToken: String
    let user: SupabaseUser
}

enum SupabaseError: LocalizedError {
    case networkError(String)
    case authError(String)
    case apiError(String)
    case storageError(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Errore di rete: \(msg)"
        case .authError(let msg):    return "Errore autenticazione: \(msg)"
        case .apiError(let msg):     return "Errore API: \(msg)"
        case .storageError(let msg): return "Errore storage: \(msg)"
        }
    }
}
