//
//  POIRepositoryImpl.swift
//  GestionaleWWFIpad
//

import SwiftData

@MainActor
final class POIRepositoryImpl: POIRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAll() throws -> [POI] {
        let descriptor = FetchDescriptor<POI>()
        return try modelContext.fetch(descriptor)
    }
    
    func save(_ poi: POI) throws {
        modelContext.insert(poi)
        try modelContext.save()
    }
    
    func delete(_ poi: POI) throws {
        modelContext.delete(poi)
        try modelContext.save()
    }
}
