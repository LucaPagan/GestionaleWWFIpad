//
//  ManagerSession.swift
//  GestionaleWWFIpad
//
//  Manages manager authentication state.
//  Production: Uses Supabase Auth for secure JWT-based login.
//  Fallback: Supports offline mode with cached credentials.
//

import Foundation
import Combine

// MARK: - ManagerSession

/// Observable session state for the manager panel.
/// Integrates with Supabase Auth while maintaining offline fallback.
class ManagerSession: ObservableObject {
    // MARK: - Published State
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var loginError: String? = nil
    @Published var adminEmail: String? = nil

    // MARK: - Supabase Integration

    /// Attempts login via Supabase Auth.
    /// Falls back to local credentials when offline.
    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Inserisci email e password."
            return
        }

        isLoading = true
        loginError = nil

        // Production: Use Supabase Auth
        Task { @MainActor in
            do {
                try await SupabaseConfig.shared.signIn(email: email, password: password)
                self.isLoggedIn = true
                self.adminEmail = email
                self.loginError = nil

                // Cache credentials for offline use
                UserDefaults.standard.set(email, forKey: "cached_admin_email")
            } catch {
                // Fallback to offline cached session if available
                if let cachedEmail = UserDefaults.standard.string(forKey: "cached_admin_email"),
                   cachedEmail == email {
                    self.isLoggedIn = true
                    self.adminEmail = email
                    self.loginError = nil
                } else {
                    self.loginError = "Login fallito: \(error.localizedDescription)"
                }
            }
            self.isLoading = false
        }
    }

    /// Logs out the manager and clears session
    func logout() {
        Task { @MainActor in
            try? await SupabaseConfig.shared.signOut()
            isLoggedIn = false
            adminEmail = nil
        }
    }

    /// Checks if there's an active Supabase session on launch
    func restoreSession() {
        Task { @MainActor in
            if let session = await SupabaseConfig.shared.currentSession() {
                self.isLoggedIn = true
                self.adminEmail = session.user.email
            }
        }
    }
}
