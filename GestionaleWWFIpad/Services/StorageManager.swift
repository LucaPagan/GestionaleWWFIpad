//
//  StorageService.swift
//  GestionaleWWFIpad
//

import Foundation

protocol StorageService: Sendable {
    func uploadImage(data: Data, path: String) async throws -> String
}

final class StorageManager: StorageService {
    static let shared = StorageManager()
    
    private init() {}
    
    func uploadImage(data: Data, path: String) async throws -> String {
        return try await SupabaseConfig.shared.uploadFile(bucket: "media", path: path, data: data, contentType: "image/jpeg")
    }
}
