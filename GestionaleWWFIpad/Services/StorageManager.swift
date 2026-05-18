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
        return try await upload(data: data, path: path, bucket: "media", contentType: "image/jpeg")
    }

    func upload(data: Data, path: String, bucket: String, contentType: String) async throws -> String {
        return try await SupabaseConfig.shared.uploadFile(bucket: bucket, path: path, data: data, contentType: contentType)
    }
}
