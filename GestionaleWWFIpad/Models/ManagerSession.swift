//
//  ManagerSession.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import Foundation
import Combine   // ← aggiunge questo

class ManagerSession: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var loginError: String? = nil

    private let validEmail    = "gestore@wwf.it"
    private let validPassword = "Astroni"

    func login(email: String, password: String) {
        if email == validEmail && password == validPassword {
            isLoggedIn = true
            loginError = nil
        } else {
            loginError = "Credenziali non valide."
        }
    }

    func logout() {
        isLoggedIn = false
    }
}
