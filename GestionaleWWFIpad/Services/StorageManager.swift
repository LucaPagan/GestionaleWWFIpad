//
//  StorageService.swift
//  GestionaleWWFIpad
//

import Foundation

protocol StorageService: Sendable {
    func uploadImage(data: Data, path: String) async throws -> String
}

final class StorageManager: StorageService, @unchecked Sendable {
    static let shared = StorageManager()
    
    private init() {}
    
    func uploadImage(data: Data, path: String) async throws -> String {
        guard !data.isEmpty else {
            throw SupabaseError.storageError("Tentativo di caricare dati d'immagine vuoti.")
        }
        if path.hasPrefix("gamification/") {
            let storagePath = String(path.dropFirst("gamification/".count))
            return try await upload(data: data, path: storagePath, bucket: "gamification", contentType: "image/jpeg")
        }
        return try await upload(data: data, path: path, bucket: "media", contentType: "image/jpeg")
    }

    func upload(data: Data, path: String, bucket: String, contentType: String) async throws -> String {
        guard !data.isEmpty else {
            throw SupabaseError.storageError("Tentativo di caricare dati vuoti.")
        }
        return try await SupabaseConfig.shared.uploadFile(bucket: bucket, path: path, data: data, contentType: contentType)
    }
}
