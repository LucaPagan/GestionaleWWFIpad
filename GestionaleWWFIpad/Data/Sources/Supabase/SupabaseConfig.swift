//
//  SupabaseConfig.swift
//  GestionaleWWFIpad
//

import Foundation
import Combine

protocol NetworkClient: Sendable {
    func rpc(_ functionName: String, params: [String: Any?]) async throws -> [String: Any]?
    func fetch(from table: String, query: String) async throws -> [[String: Any]]
}

final class SupabaseConfig: NetworkClient, @unchecked Sendable {

    static let shared = SupabaseConfig() // Maintained for transition

    private let projectURL = AppConfig.supabaseURL
    private let anonKey = AppConfig.supabaseAnonKey

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

    func currentSession() async -> SupabaseSession? {
        guard let token = accessToken, let user = sessionUser else { return nil }
        return SupabaseSession(accessToken: token, user: user)
    }

    private func refreshSession() async throws {
        guard let rToken = refreshToken else {
            throw SupabaseError.authError("Nessun token di refresh disponibile")
        }

        let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let body: [String: String] = ["refresh_token": rToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Risposta non valida dal server")
        }

        guard httpResponse.statusCode == 200 else {
            _ = try? await signOut() // Clear session if refresh fails
            throw SupabaseError.authError("Sessione scaduta, effettua nuovamente il login")
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        accessToken = json?["access_token"] as? String
        refreshToken = json?["refresh_token"] as? String

        if let userDict = json?["user"] as? [String: Any] {
            sessionUser = SupabaseUser(
                id: userDict["id"] as? String ?? "",
                email: userDict["email"] as? String
            )
        }
    }

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Risposta non valida")
        }

        if httpResponse.statusCode == 401, refreshToken != nil {
            // Attempt to refresh the session
            try await refreshSession()
            
            // Retry the request with the new token
            var retryRequest = request
            if let token = accessToken {
                retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw SupabaseError.networkError("Risposta non valida al retry")
            }
            return (retryData, retryHttpResponse)
        }

        return (data, httpResponse)
    }

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

        let cleanParams = params.compactMapValues { $0 }
        request.httpBody = try JSONSerialization.data(withJSONObject: cleanParams)

        let (data, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("RPC \(functionName) failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

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

        let (data, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.apiError("Fetch from \(table) failed")
        }

        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
    
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

        let (responseData, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseError.storageError("Upload failed: \(errorBody)")
        }

        return "\(projectURL)/storage/v1/object/public/\(bucket)/\(path)"
    }
}

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
