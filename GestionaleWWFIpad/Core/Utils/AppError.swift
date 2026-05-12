//
//  AppError.swift
//  GestionaleWWFIpad
//

import Foundation

enum AppError: LocalizedError {
    case network(String)
    case storage(String)
    case database(String)
    case validation(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return "Errore di rete: \(msg)"
        case .storage(let msg): return "Errore salvataggio file: \(msg)"
        case .database(let msg): return "Errore database: \(msg)"
        case .validation(let msg): return "Dati non validi: \(msg)"
        case .unknown(let err): return "Errore sconosciuto: \(err.localizedDescription)"
        }
    }
}
