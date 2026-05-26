//
//  SupabaseConfig.swift
//  GestionaleWWFIpad
//

import Foundation
import Combine
import os

protocol NetworkClient: Sendable {
    func rpc(_ functionName: String, params: [String: Any?]) async throws -> [String: Any]?
    func invokeFunction(_ functionName: String, body: [String: Any?]) async throws -> [String: Any]?
    func fetch(from table: String, query: String) async throws -> [[String: Any]]
    func insert(into table: String, values: [String: Any?]) async throws -> [String: Any]?
    func upsert(into table: String, values: [String: Any?]) async throws -> [String: Any]?
    func patch(table: String, id: String, values: [String: Any?]) async throws
    func delete(from table: String, match: [String: String]) async throws
}

final class SupabaseConfig: NetworkClient, @unchecked Sendable {

    static let shared = SupabaseConfig() // Maintained for transition

    private let projectURL = AppConfig.supabaseURL
    private let anonKey = AppConfig.supabaseAnonKey
    
    // MARK: - Thread Safety
    /// Lock protecting all mutable token/session state to prevent data races (EXC_BAD_ACCESS)
    private let stateLock = NSLock()
    /// Guard against concurrent token refresh attempts
    private var _isRefreshing = false
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.httpMaximumConnectionsPerHost = 1
        config.httpShouldUsePipelining = false
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    /// A separate ephemeral session for storage tasks to avoid session-level protocol caching issues
    private let storageSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        config.httpMaximumConnectionsPerHost = 1
        config.httpShouldUsePipelining = false
        return URLSession(configuration: config)
    }()

    // MARK: - Secure Token Storage (Keychain)

    // MARK: - Thread-safe token storage (protected by stateLock)
    private var _accessToken: String?
    private var _refreshToken: String?
    private var _sessionUser: SupabaseUser?

    /// Thread-safe getter/setter for accessToken
    private var accessToken: String? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _accessToken
        }
        set {
            stateLock.lock()
            _accessToken = newValue
            stateLock.unlock()
            // Keychain writes are thread-safe themselves
            if let token = newValue {
                KeychainHelper.save(key: "sb_access_token", value: token)
            } else {
                KeychainHelper.delete(key: "sb_access_token")
            }
        }
    }
    /// Thread-safe getter/setter for refreshToken
    private var refreshToken: String? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _refreshToken
        }
        set {
            stateLock.lock()
            _refreshToken = newValue
            stateLock.unlock()
            if let token = newValue {
                KeychainHelper.save(key: "sb_refresh_token", value: token)
            } else {
                KeychainHelper.delete(key: "sb_refresh_token")
            }
        }
    }
    /// Thread-safe getter/setter for sessionUser
    private var sessionUser: SupabaseUser? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _sessionUser
        }
        set {
            stateLock.lock()
            _sessionUser = newValue
            stateLock.unlock()
            if let user = newValue {
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
            // Direct assignment to backing storage during init (no concurrency yet)
            self._accessToken = token
            self._refreshToken = KeychainHelper.load(key: "sb_refresh_token")
            let email = KeychainHelper.load(key: "sb_user_email")
            self._sessionUser = SupabaseUser(id: id, email: email)
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
        guard let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=password") else {
            throw SupabaseError.networkError("URL di autenticazione non valido")
        }
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
            guard let url = URL(string: "\(projectURL)/auth/v1/logout") else { return }
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

    private func tryAcquireRefresh() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        if _isRefreshing {
            return false
        }
        _isRefreshing = true
        return true
    }

    private func releaseRefresh() {
        stateLock.lock()
        _isRefreshing = false
        stateLock.unlock()
    }

    private func refreshSession() async throws {
        // Prevent concurrent refresh attempts (data race protection)
        guard tryAcquireRefresh() else {
            // Another refresh is already in progress — wait briefly then return
            try? await Task.sleep(for: .milliseconds(500))
            return
        }
        defer {
            releaseRefresh()
        }

        guard let rToken = refreshToken else {
            throw SupabaseError.authError("Nessun token di refresh disponibile")
        }

        guard let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=refresh_token") else {
            throw SupabaseError.networkError("URL di refresh non valido")
        }
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
        guard let url = URL(string: "\(projectURL)/rest/v1/rpc/\(functionName)") else {
            throw SupabaseError.networkError("URL RPC non valido per: \(functionName)")
        }
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
        request.httpBody = try SupabaseJSONSanitizer.data(from: params)

        let (data, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("RPC \(functionName) failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func invokeFunction(_ functionName: String, body: [String: Any?]) async throws -> [String: Any]? {
        guard let url = URL(string: "\(projectURL)/functions/v1/\(functionName)") else {
            throw SupabaseError.networkError("Invalid Edge Function URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try SupabaseJSONSanitizer.data(from: body)

        let (data, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("Edge Function \(functionName) failed (\(httpResponse.statusCode)): \(errorBody)")
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

    func insert(into table: String, values: [String: Any?]) async throws -> [String: Any]? {
        let urlString = "\(projectURL)/rest/v1/\(table)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try SupabaseJSONSanitizer.data(from: values)
        let (data, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("Insert into \(table) failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first
    }

    func upsert(into table: String, values: [String: Any?]) async throws -> [String: Any]? {
        let urlString = "\(projectURL)/rest/v1/\(table)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try SupabaseJSONSanitizer.data(from: values)
        let (data, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError("Upsert into \(table) failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first
    }

    func patch(table: String, id: String, values: [String: Any?]) async throws {
        let urlString = "\(projectURL)/rest/v1/\(table)?id=eq.\(id)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try SupabaseJSONSanitizer.data(from: values)
        let (_, httpResponse) = try await performRequestWithRetry(request)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.apiError("Patch \(table) failed (\(httpResponse.statusCode))")
        }
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
        guard !data.isEmpty else {
            throw SupabaseError.storageError("I dati dell'immagine da caricare sono vuoti.")
        }
        guard let url = URL(string: "\(projectURL)/storage/v1/object/\(bucket)/\(path)") else {
            throw SupabaseError.storageError("URL storage non valido per bucket: \(bucket), path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        
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
            if let token = accessToken {
                uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            // Make a contiguous copy of the data to avoid EXC_BAD_ACCESS / UnsafeBufferPointer
            // crashes when data is backed by non-thread-safe buffers (like CGImage/jpegData).
            let safeData = Data(data)
            let (d, r) = try await storageSession.upload(for: uploadRequest, from: safeData)
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
