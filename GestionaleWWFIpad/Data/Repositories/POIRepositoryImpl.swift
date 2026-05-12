//
//  POIRepositoryImpl.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData

@ModelActor
final actor POIRepositoryImpl: POIRepository {
    
    func fetchAll() async throws -> [POI] {
        let descriptor = FetchDescriptor<POI>()
        return try modelContext.fetch(descriptor)
    }
    
    func save(_ poi: POI) async throws {
        modelContext.insert(poi)
        try modelContext.save()
    }
    
    func delete(_ poi: POI) async throws {
        modelContext.delete(poi)
        try modelContext.save()
    }
}
