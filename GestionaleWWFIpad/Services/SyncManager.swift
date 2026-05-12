//
//  SyncManager.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import Combine

enum SyncState: Equatable {
    case idle
    case syncing(entity: String)
    case success(count: Int)
    case error(message: String)
}

@MainActor
final class SyncManager: ObservableObject {

    @Published var syncState: SyncState = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0

    private var modelContainer: ModelContainer?
    private let networkClient: NetworkClient
    private let storageService: StorageService

    init(networkClient: NetworkClient = SupabaseConfig.shared, storageService: StorageService = StorageManager.shared) {
        self.networkClient = networkClient
        self.storageService = storageService
    }

    func configure(with context: ModelContext) {
        self.modelContainer = context.container
        updatePendingCount()
    }

    func pushAllChanges() async {
        guard let container = modelContainer else { return }
        
        do {
            syncState = .syncing(entity: "Dati in background")
            
            let worker = SyncWorker(modelContainer: container, networkClient: networkClient, storageService: storageService)
            let resultCount = try await worker.performPush()
            
            syncState = .success(count: resultCount)
            lastSyncDate = Date()
            updatePendingCount()
        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    func pullLatestData() async {
        guard let container = modelContainer else { return }

        do {
            syncState = .syncing(entity: "Download dati")
            
            let worker = SyncWorker(modelContainer: container, networkClient: networkClient, storageService: storageService)
            let resultCount = try await worker.performPull()

            syncState = .success(count: resultCount)
            lastSyncDate = Date()
            updatePendingCount()
        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    func updatePendingCount() {
        guard let container = modelContainer else {
            pendingChanges = 0
            return
        }
        let context = ModelContext(container)
        
        let poisDesc = FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true })
        let trailsDesc = FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true })
        let eventsDesc = FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true })

        let pCount = (try? context.fetchCount(poisDesc)) ?? 0
        let tCount = (try? context.fetchCount(trailsDesc)) ?? 0
        let eCount = (try? context.fetchCount(eventsDesc)) ?? 0

        pendingChanges = pCount + tCount + eCount
    }
}

actor SyncWorker: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    let networkClient: NetworkClient
    let storageService: StorageService
    
    init(modelContainer: ModelContainer, networkClient: NetworkClient, storageService: StorageService) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.networkClient = networkClient
        self.storageService = storageService
    }

    func performPush() async throws -> Int {
        let dirtyPOIs = try modelContext.fetch(FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true }))
        for poi in dirtyPOIs {
            if let photoData = poi.photoData, poi.photoURL == nil {
                let url = try await storageService.uploadImage(data: photoData, path: "pois/\(poi.id.uuidString).jpg")
                poi.photoURL = url
            }
            _ = try await networkClient.rpc("upsert_poi", params: poi.toSupabaseParams())
            poi.needsSync = false
        }

        let dirtyTrails = try modelContext.fetch(FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true }))
        for trail in dirtyTrails {
            _ = try await networkClient.rpc("upsert_path", params: trail.toSupabaseParams())
            let stepsParams: [String: Any?] = [
                "p_path_id": trail.id.uuidString,
                "p_steps": trail.stepsToJSON()
            ]
            _ = try await networkClient.rpc("sync_path_steps", params: stepsParams)
            trail.needsSync = false
        }

        let dirtyEvents = try modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true }))
        for event in dirtyEvents {
            if let photoData = event.photoData, event.imageURL == nil {
                let url = try await storageService.uploadImage(data: photoData, path: "events/\(event.id.uuidString).jpg")
                event.imageURL = url
            }
            _ = try await networkClient.rpc("upsert_event", params: event.toSupabaseParams())
            event.needsSync = false
        }

        try modelContext.save()
        return dirtyPOIs.count + dirtyTrails.count + dirtyEvents.count
    }

    func performPull() async throws -> Int {
        var downloadedCount = 0
        
        let remotePOIs = try await networkClient.fetch(from: "pois", query: "select=*")
        for poiData in remotePOIs {
            guard let idStr = poiData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(poiData) }
            } else {
                if let newPOI = createPOIFromRemote(poiData) { modelContext.insert(newPOI) }
            }
            downloadedCount += 1
        }

        let remotePaths = try await networkClient.fetch(from: "paths", query: "select=*")
        for pathData in remotePaths {
            guard let idStr = pathData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(pathData) }
            } else {
                if let newTrail = createTrailFromRemote(pathData) { modelContext.insert(newTrail) }
            }
            downloadedCount += 1
        }

        try modelContext.save()
        return downloadedCount
    }
    
    private func createPOIFromRemote(_ data: [String: Any]) -> POI? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String,
              let desc = data["poi_description"] as? String,
              let x = data["x"] as? Double,
              let y = data["y"] as? Double else { return nil }

        let typeStr = data["type"] as? String ?? "landmark"
        let poiType = POIType.fromSupabase(typeStr) ?? .landmark

        let poi = POI(
            name: name,
            description: desc,
            x: x,
            y: y,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            type: poiType,
            photoURL: data["photo_data"] as? String,
            isStartPoint: data["is_start_point"] as? Bool ?? false,
            isActive: data["is_active"] as? Bool ?? true,
            fixedID: id
        )
        poi.qrPayload = data["qr_payload"] as? String ?? "ASTRONI_POI_\(id.uuidString)"
        poi.needsSync = false
        return poi
    }

    private func createTrailFromRemote(_ data: [String: Any]) -> Trail? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String else { return nil }

        let diffStr = data["difficulty"] as? String
        let difficulty = diffStr.flatMap { TrailDifficulty.fromSupabase($0) }

        let startPOIIdStr = data["start_poi_id"] as? String
        let startPOIId = startPOIIdStr.flatMap { UUID(uuidString: $0) }

        let trail = Trail(
            name: name,
            description: data["description"] as? String ?? "",
            isActive: data["is_active"] as? Bool ?? false,
            difficulty: difficulty,
            estimatedMinutes: data["estimated_minutes"] as? Int,
            coverImageURL: data["cover_image_url"] as? String,
            startPOIId: startPOIId,
            fixedID: id
        )
        trail.needsSync = false
        return trail
    }
}
