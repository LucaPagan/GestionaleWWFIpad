//
//  SyncManager.swift
//  GestionaleWWFIpad
//
//  Orchestrates bidirectional sync between SwiftData (local) and Supabase (remote).
//  Designed for offline-first: local writes always succeed, remote sync is best-effort.
//
//  SRS Reference: Chapter 7.4 — Persistenza Locale, Chapter 8 — Download Differenziato
//

import Foundation
import SwiftData
import Combine

// MARK: - SyncState

/// Represents the current state of a sync operation
enum SyncState: Equatable {
    case idle
    case syncing(entity: String)
    case success(count: Int)
    case error(message: String)
}

// MARK: - SyncManager

/// Manages all data synchronization between SwiftData and Supabase.
///
/// Architecture:
/// - Manager iPad → Supabase: Push changes (POIs, Trails, Events)
/// - Supabase → Manager iPad: Pull latest state (on launch, on demand)
/// - Photo uploads go to Supabase Storage
/// - Sync is always non-blocking and reports state via `syncState`
@MainActor
final class SyncManager: ObservableObject {

    // MARK: - Published State

    @Published var syncState: SyncState = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0

    // MARK: - Dependencies

    private let supabase = SupabaseConfig.shared
    private var modelContext: ModelContext?

    // MARK: - Init

    func configure(with context: ModelContext) {
        self.modelContext = context
        updatePendingCount()
    }

    // MARK: - Push Operations (Local → Supabase)

    /// Pushes all pending local changes to Supabase.
    /// Called when the manager saves content and has connectivity.
    func pushAllChanges() async {
        guard let context = modelContext else { return }

        do {
            // 1. Sync POIs
            syncState = .syncing(entity: "POI")
            let poisDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true })
            let dirtyPOIs = (try? context.fetch(poisDescriptor)) ?? []

            for poi in dirtyPOIs {
                try await pushPOI(poi)
            }

            // 2. Sync Trails
            syncState = .syncing(entity: "Percorsi")
            let trailsDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true })
            let dirtyTrails = (try? context.fetch(trailsDescriptor)) ?? []

            for trail in dirtyTrails {
                try await pushTrail(trail)
            }

            // 3. Sync Events
            syncState = .syncing(entity: "Eventi")
            let eventsDescriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true })
            let dirtyEvents = (try? context.fetch(eventsDescriptor)) ?? []

            for event in dirtyEvents {
                try await pushEvent(event)
            }

            let totalSynced = dirtyPOIs.count + dirtyTrails.count + dirtyEvents.count
            syncState = .success(count: totalSynced)
            lastSyncDate = Date()
            try? context.save()
            updatePendingCount()

        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    // MARK: - Individual Push Operations

    /// Pushes a single POI to Supabase, including photo upload if needed
    private func pushPOI(_ poi: POI) async throws {
        // Upload photo to Storage if local data exists and no remote URL
        if let photoData = poi.photoData, poi.photoURL == nil {
            let path = "pois/\(poi.id.uuidString).jpg"
            let url = try await supabase.uploadFile(
                bucket: "media",
                path: path,
                data: photoData,
                contentType: "image/jpeg"
            )
            poi.photoURL = url
        }

        // Upsert via RPC
        _ = try await supabase.rpc("upsert_poi", params: poi.toSupabaseParams())
        poi.needsSync = false
    }

    /// Pushes a Trail and its steps to Supabase
    private func pushTrail(_ trail: Trail) async throws {
        // 1. Upsert the trail itself
        _ = try await supabase.rpc("upsert_path", params: trail.toSupabaseParams())

        // 2. Sync all steps as a batch
        let stepsJSON = trail.stepsToJSON()
        let stepsParams: [String: Any?] = [
            "p_path_id": trail.id.uuidString,
            "p_steps": stepsJSON
        ]
        _ = try await supabase.rpc("sync_path_steps", params: stepsParams)

        trail.needsSync = false
    }

    /// Pushes an Event to Supabase
    private func pushEvent(_ event: Event) async throws {
        // Upload event photo if needed
        if let photoData = event.photoData, event.imageURL == nil {
            let path = "events/\(event.id.uuidString).jpg"
            let url = try await supabase.uploadFile(
                bucket: "media",
                path: path,
                data: photoData,
                contentType: "image/jpeg"
            )
            event.imageURL = url
        }

        _ = try await supabase.rpc("upsert_event", params: event.toSupabaseParams())
        event.needsSync = false
    }

    // MARK: - Pull Operations (Supabase → Local)

    /// Pulls all active content from Supabase and merges with local data.
    /// Used for initial sync or refresh.
    func pullLatestData() async {
        guard let context = modelContext else { return }

        do {
            syncState = .syncing(entity: "Download dati")

            // Fetch all POIs
            let remotePOIs = try await supabase.fetch(from: "pois", query: "select=*")
            for poiData in remotePOIs {
                guard let idStr = poiData["id"] as? String,
                      let remoteId = UUID(uuidString: idStr) else { continue }

                let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == remoteId })
                if let existing = (try? context.fetch(descriptor))?.first {
                    // Only update if local version doesn't have pending changes
                    if !existing.needsSync {
                        existing.updateFromRemote(poiData)
                    }
                } else {
                    // Create new local POI from remote data
                    let newPOI = createPOIFromRemote(poiData)
                    if let newPOI { context.insert(newPOI) }
                }
            }

            // Fetch all paths
            let remotePaths = try await supabase.fetch(from: "paths", query: "select=*")
            for pathData in remotePaths {
                guard let idStr = pathData["id"] as? String,
                      let remoteId = UUID(uuidString: idStr) else { continue }

                let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == remoteId })
                if let existing = (try? context.fetch(descriptor))?.first {
                    if !existing.needsSync {
                        existing.updateFromRemote(pathData)
                    }
                } else {
                    let newTrail = createTrailFromRemote(pathData)
                    if let newTrail { context.insert(newTrail) }
                }
            }

            try? context.save()
            syncState = .success(count: remotePOIs.count + remotePaths.count)
            lastSyncDate = Date()

        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    // MARK: - Factory Methods (Remote → Local)

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

    // MARK: - Helpers

    private func updatePendingCount() {
        guard let context = modelContext else {
            pendingChanges = 0
            return
        }

        let poisDesc = FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true })
        let trailsDesc = FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true })
        let eventsDesc = FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true })

        let pCount = (try? context.fetchCount(poisDesc)) ?? 0
        let tCount = (try? context.fetchCount(trailsDesc)) ?? 0
        let eCount = (try? context.fetchCount(eventsDesc)) ?? 0

        pendingChanges = pCount + tCount + eCount
    }
}
