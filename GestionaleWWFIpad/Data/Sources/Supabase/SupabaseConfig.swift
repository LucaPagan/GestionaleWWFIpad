//
//  SupabaseConfig.swift
//  GestionaleWWFIpad
//

import Foundation
import Combine

protocol NetworkClient: Sendable {
    func rpc(_ functionName: String, params: [String: Any?]) async throws -> [String: Any]?
    func fetch(from table: String, query: String) async throws -> [[String: Any]]
    func delete(from table: String, match: [String: String]) async throws
}

final class SupabaseConfig: NetworkClient, @unchecked Sendable {

    static let shared = SupabaseConfig() // Maintained for transition

    private let projectURL = AppConfig.supabaseURL
    private let anonKey = AppConfig.supabaseAnonKey
    
    private var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.httpMaximumConnectionsPerHost = 1
        config.httpShouldUsePipelining = false
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    /// A separate ephemeral session for storage tasks to avoid session-level protocol caching issues
    private var storageSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        config.httpMaximumConnectionsPerHost = 1
        config.httpShouldUsePipelining = false
        return URLSession(configuration: config)
    }()

    // MARK: - Secure Token Storage (Keychain)

    private var accessToken: String? {
        didSet {
            if let token = accessToken {
                KeychainHelper.save(key: "sb_access_token", value: token)
            } else {
                KeychainHelper.delete(key: "sb_access_token")
            }
        }
    }
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                KeychainHelper.save(key: "sb_refresh_token", value: token)
            } else {
                KeychainHelper.delete(key: "sb_refresh_token")
            }
        }
    }
    private var sessionUser: SupabaseUser? {
        didSet {
            if let user = sessionUser {
                KeychainHelper.save(key: "sb_user_id", value: user.id)
                if let email = user.email {
                    KeychainHelper.save(key: "sb_user_email", value: email)
                }
            } else {
                KeychainHelper.delete(key: "sb_user_id")
                KeychainHelper.delete(key: "sb_user_email")
            }
        }
    }

    private init() {
        // Migrate from UserDefaults to Keychain on first launch
        Self.migrateFromUserDefaults()

        if let token = KeychainHelper.load(key: "sb_access_token"),
           let id = KeychainHelper.load(key: "sb_user_id") {
            self.accessToken = token
            self.refreshToken = KeychainHelper.load(key: "sb_refresh_token")
            let email = KeychainHelper.load(key: "sb_user_email")
            self.sessionUser = SupabaseUser(id: id, email: email)
        }
    }

    /// One-time migration: move tokens from UserDefaults to Keychain, then clear UserDefaults.
    private static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        if let token = defaults.string(forKey: "sb_access_token") {
            KeychainHelper.save(key: "sb_access_token", value: token)
            defaults.removeObject(forKey: "sb_access_token")
        }
        if let token = defaults.string(forKey: "sb_refresh_token") {
            KeychainHelper.save(key: "sb_refresh_token", value: token)
            defaults.removeObject(forKey: "sb_refresh_token")
        }
        if let id = defaults.string(forKey: "sb_user_id") {
            KeychainHelper.save(key: "sb_user_id", value: id)
            defaults.removeObject(forKey: "sb_user_id")
        }
        if let email = defaults.string(forKey: "sb_user_email") {
            KeychainHelper.save(key: "sb_user_email", value: email)
            defaults.removeObject(forKey: "sb_user_email")
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

        let (data, response) = try await session.data(for: request)

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

        let (data, response) = try await session.data(for: request)

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

    private func performRequestWithRetry(
        _ request: URLRequest, 
        useStorageSession: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        var mutableRequest = request
        mutableRequest.setValue("close", forHTTPHeaderField: "Connection")
        
        let nsRequest = (mutableRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest
        if nsRequest?.responds(to: NSSelectorFromString("_setAllowsQUIC:")) == true {
            nsRequest?.setValue(false, forKey: "allowsQUIC")
            if let updatedRequest = nsRequest as URLRequest? {
                mutableRequest = updatedRequest
            }
        }

        let activeSession = useStorageSession ? storageSession : session
        
        // Helper to perform the actual network call based on request type
        let (data, response) = try await activeSession.data(for: mutableRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Risposta non valida")
        }

        // Supabase returns 401 or 400 with "exp" error when token is expired
        let errorBody = String(data: data, encoding: .utf8) ?? ""
        let isTokenExpired = httpResponse.statusCode == 401 || 
                            (httpResponse.statusCode == 400 && errorBody.contains("exp"))

        if isTokenExpired && refreshToken != nil {
            // Attempt to refresh the session
            try await refreshSession()
            
            // Rebuild the request with the new token
            var retryRequest = request
            retryRequest.setValue("close", forHTTPHeaderField: "Connection")
            if let token = accessToken {
                retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            // Retry with the same session
            let (retryData, retryResponse) = try await activeSession.data(for: retryRequest)
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

        // Ensure all parameters are sent, using NSNull for nil values 
        // to match the PostgreSQL function signature.
        let sanitizedParams = params.mapValues { $0 ?? NSNull() }
        request.httpBody = try JSONSerialization.data(withJSONObject: sanitizedParams)

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
    
    func delete(from table: String, match: [String: String]) async throws {
        var queryItems = [String]()
        for (key, value) in match {
            queryItems.append("\(key)=eq.\(value)")
        }
        let queryString = queryItems.joined(separator: "&")
        let urlString = "\(projectURL)/rest/v1/\(table)?\(queryString)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        let (_, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.apiError("Delete from \(table) failed (\(httpResponse.statusCode))")
        }
    }
    
    func uploadFile(bucket: String, path: String, data: Data, contentType: String = "image/jpeg") async throws -> String {
        let url = URL(string: "\(projectURL)/storage/v1/object/\(bucket)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        // We handle the actual network call and retry inside a specialized block
        // to support the 'upload' task type while still benefiting from performRequestWithRetry logic.
        
        // Ensure we have a fresh token before starting a large upload
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // For large uploads, it's safer to refresh the token BEFORE starting if we think it might be stale,
        // but we'll rely on the error handling for now. 
        // Note: performRequestWithRetry uses .data which isn't ideal for large bodies, 
        // so we'll do a manual check-and-refresh for uploadFile to keep it efficient.
        
        func doUpload() async throws -> (Data, HTTPURLResponse) {
            var uploadRequest = request
            uploadRequest.setValue("close", forHTTPHeaderField: "Connection")
            let nsRequest = (uploadRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest
            if nsRequest?.responds(to: NSSelectorFromString("_setAllowsQUIC:")) == true {
                nsRequest?.setValue(false, forKey: "allowsQUIC")
                if let updated = nsRequest as URLRequest? { uploadRequest = updated }
            }
            if let token = accessToken {
                uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (d, r) = try await storageSession.upload(for: uploadRequest, from: data)
            guard let hr = r as? HTTPURLResponse else { throw SupabaseError.networkError("No HTTP response") }
            return (d, hr)
        }

        var (responseData, httpResponse) = try await doUpload()
        
        let errorBody = String(data: responseData, encoding: .utf8) ?? ""
        let isTokenExpired = httpResponse.statusCode == 401 || 
                            (httpResponse.statusCode == 400 && errorBody.contains("exp"))

        if isTokenExpired && refreshToken != nil {
            try await refreshSession()
            (responseData, httpResponse) = try await doUpload()
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseError.storageError("Upload failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        let publicURL = "\(projectURL)/storage/v1/object/public/\(bucket)/\(path)"
        return publicURL
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
