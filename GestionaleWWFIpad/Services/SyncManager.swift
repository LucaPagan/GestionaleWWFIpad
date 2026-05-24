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

struct AdminSyncError: LocalizedError {
    let messages: [String]

    var errorDescription: String? {
        messages.joined(separator: "\n")
    }
}

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

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
            let pushedCount = try await worker.performPush()
            let pulledCount = try await worker.performPull()
            
            syncState = .success(count: pushedCount + pulledCount)
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
        let contentsDesc = FetchDescriptor<Content>(predicate: #Predicate { $0.needsSync == true })

        let pCount = (try? context.fetchCount(poisDesc)) ?? 0
        let tCount = (try? context.fetchCount(trailsDesc)) ?? 0
        let eCount = (try? context.fetchCount(eventsDesc)) ?? 0
        let cCount = (try? context.fetchCount(contentsDesc)) ?? 0

        pendingChanges = pCount + tCount + eCount + cCount
    }
    
    // MARK: - Deletions
    
    func delete(_ poi: POI, in context: ModelContext) async {
        do {
            try await networkClient.delete(from: "pois", match: ["id": poi.id.uuidString])
        } catch {
            print("Failed to delete POI remotely: \(error)")
        }
        context.delete(poi)
        try? context.save()
    }
    
    func delete(_ trail: Trail, in context: ModelContext) async {
        do {
            try await networkClient.delete(from: "paths", match: ["id": trail.id.uuidString])
        } catch {
            print("Failed to delete Trail remotely: \(error)")
        }
        context.delete(trail)
        try? context.save()
    }
    
    func delete(_ event: Event, in context: ModelContext) async {
        do {
            try await networkClient.delete(from: "events", match: ["id": event.id.uuidString])
        } catch {
            print("Failed to delete Event remotely: \(error)")
        }
        context.delete(event)
        try? context.save()
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
        var changedCount = 0
        var bundleCandidates = Set<UUID>()

        let dirtyPOIs = try modelContext.fetch(FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true }))
        for poi in dirtyPOIs {
            let issues = AdminValidationService.poiIssues(poi)
            if issues.contains(where: { $0.severity == .error }) {
                throw AdminSyncError(messages: issues.map(\.message))
            }

            if let photoData = poi.photoData, poi.photoURL == nil {
                let url = try await storageService.uploadImage(data: photoData, path: "pois/\(poi.id.uuidString).jpg")
                poi.photoURL = url
            }
            _ = try await networkClient.rpc("upsert_poi", params: poi.toSupabaseParams())
            
            // Auto-generate translations for POI name and description
            await pushTranslations(table: "pois", recordId: poi.id, fields: [
                "name": poi.name,
                "poi_description": poi.poiDescription
            ])
            
            poi.needsSync = false
            changedCount += 1
            bundleCandidates.formUnion(try activeTrailIds(containingPOI: poi.id))
        }

        let dirtyContents = try modelContext.fetch(FetchDescriptor<Content>(predicate: #Predicate { $0.needsSync == true }))
        for content in dirtyContents {
            let issues = AdminValidationService.contentIssues(content)
            if issues.contains(where: { $0.severity == .error }) {
                throw AdminSyncError(messages: issues.map(\.message))
            }

            _ = try await networkClient.rpc("upsert_content", params: content.toSupabaseParams())
            content.needsSync = false
            changedCount += 1
            bundleCandidates.formUnion(try activeTrailIds(containingPOI: content.poiId))
        }

        let dirtyTrails = try modelContext.fetch(FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true }))
        for trail in dirtyTrails {
            try await syncTrailWithPublishGate(trail)
            changedCount += 1
            if trail.isActive { bundleCandidates.insert(trail.id) }
        }

        for trailId in bundleCandidates {
            let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == trailId })
            guard let trail = try modelContext.fetch(descriptor).first, trail.isActive, !trail.needsSync else { continue }
            let contents = try allContents()
            let issues = AdminValidationService.trailIssues(trail: trail, contents: contents)
            if issues.contains(where: { $0.severity == .error }) {
                throw AdminSyncError(messages: issues.map(\.message))
            }
            try await regenerateAndVerifyBundles(for: trail)
        }

        let dirtyEvents = try modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true }))
        for event in dirtyEvents {
            let issues = AdminValidationService.eventIssues(event)
            if issues.contains(where: { $0.severity == .error }) {
                throw AdminSyncError(messages: issues.map(\.message))
            }

            if let photoData = event.photoData, event.imageURL == nil {
                let url = try await storageService.uploadImage(data: photoData, path: "events/\(event.id.uuidString).jpg")
                event.imageURL = url
            }
            _ = try await networkClient.rpc("upsert_event", params: event.toSupabaseParams())
            event.needsSync = false
            changedCount += 1
        }

        try? modelContext.save()
        return changedCount
    }

    private func syncTrailWithPublishGate(_ trail: Trail) async throws {
        let desiredActive = trail.isActive
        let contents = try allContents()
        let issues = AdminValidationService.trailIssues(trail: trail, contents: contents)
        if issues.contains(where: { $0.severity == .error }) {
            throw AdminSyncError(messages: issues.map(\.message))
        }

        if desiredActive {
            trail.isActive = false
            try await pushTrail(trail)
            try await regenerateAndVerifyBundles(for: trail)
            trail.isActive = true
            try await pushTrail(trail)
            try await regenerateAndVerifyBundles(for: trail)
        } else {
            try await pushTrail(trail)
        }

        trail.needsSync = false
    }

    private func pushTrail(_ trail: Trail) async throws {
        _ = try await networkClient.rpc("upsert_path", params: trail.toSupabaseParams())
        let stepsParams: [String: Any?] = [
            "p_path_id": trail.id.uuidString,
            "p_steps": trail.stepsToJSON()
        ]
        _ = try await networkClient.rpc("sync_path_steps", params: stepsParams)

        await pushTranslations(table: "paths", recordId: trail.id, fields: [
            "name": trail.name,
            "description": trail.trailDescription
        ])

        for step in trail.steps {
            if let hint = step.directionHint {
                await pushTranslations(table: "path_steps", recordId: step.id, fields: [
                    "direction_hint": hint
                ])
            }
        }
    }

    private func regenerateAndVerifyBundles(for trail: Trail) async throws {
        for tier in ContentTier.allCases {
            _ = try await networkClient.invokeFunction("generate-bundle", body: [
                "path_id": trail.id.uuidString,
                "tier": tier.rawValue
            ])
        }

        let readiness = try await fetchBundleReadiness(pathId: trail.id)
        let bundleIssues = AdminValidationService.bundleIssues(for: readiness, localUpdatedAt: trail.updatedAt)
        if bundleIssues.contains(where: { $0.severity == .error }) {
            throw AdminSyncError(messages: bundleIssues.map(\.message))
        }
    }

    private func fetchBundleReadiness(pathId: UUID) async throws -> [BundleReadiness] {
        let query = "select=tier,is_ready,manifest_sha256,generated_at,updated_at,size_bytes,generation_status&path_id=eq.\(pathId.uuidString)"
        let rows = try await networkClient.fetch(from: "download_packages", query: query)
        return rows.compactMap { row in
            guard let tierRaw = row["tier"] as? String, let tier = ContentTier(rawValue: tierRaw) else { return nil }
            return BundleReadiness(
                tier: tier,
                isReady: row["is_ready"] as? Bool ?? false,
                manifestSHA256: row["manifest_sha256"] as? String,
                generatedAt: Self.parseDate(row["generated_at"] as? String),
                updatedAt: Self.parseDate(row["updated_at"] as? String),
                sizeBytes: Self.int64Value(row["size_bytes"]),
                generationStatus: row["generation_status"] as? String
            )
        }
    }

    private func activeTrailIds(containingPOI poiId: UUID) throws -> Set<UUID> {
        let trails = try modelContext.fetch(FetchDescriptor<Trail>())
        return Set(trails.filter { trail in
            trail.isActive && trail.steps.contains { $0.poi?.id == poiId }
        }.map(\.id))
    }

    private func allContents() throws -> [Content] {
        try modelContext.fetch(FetchDescriptor<Content>())
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return number.int64Value }
        if let int = value as? Int { return Int64(int) }
        if let string = value as? String, let parsed = Int64(string) { return parsed }
        return 0
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func pushTranslations(table: String, recordId: UUID, fields: [String: String]) async {
        // Automatically translate from Italian to English, German, and French
        let targetLanguages = ["en", "de", "fr"]
        for lang in targetLanguages {
            for (fieldName, text) in fields {
                let translated = await TranslationService.shared.translate(text, to: lang)
                let params: [String: Any?] = [
                    "p_id": UUID().uuidString,
                    "p_table_name": table,
                    "p_record_id": recordId.uuidString,
                    "p_field_name": fieldName,
                    "p_language_code": lang,
                    "p_translated_text": translated
                ]
                _ = try? await networkClient.rpc("upsert_translation", params: params)
            }
        }
    }


    func performPull() async throws -> Int {
        var downloadedCount = 0
        
        // Pull POIs
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
        try removeDuplicatePOIs()

        // Pull Paths
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
        try removeDuplicateTrails()

        // Pull PathSteps (con path_geometry per i sentieri disegnati)
        let remoteSteps = try await networkClient.fetch(
            from: "path_steps",
            query: "select=*&order=step_order.asc"
        )
        for data in remoteSteps {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            guard let pathIdStr = data["path_id"] as? String, let pathId = UUID(uuidString: pathIdStr) else { continue }
            guard let poiIdStr = data["poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) else { continue }

            let stepDescriptor = FetchDescriptor<TrailStep>(predicate: #Predicate { $0.id == remoteId })
            if let existingStep = try modelContext.fetch(stepDescriptor).first {
                // Update from remote data
                existingStep.stepOrder = data["step_order"] as? Int ?? existingStep.stepOrder
                existingStep.directionHint = data["direction_hint"] as? String
                existingStep.distanceMeters = data["distance_meters"] as? Int
                existingStep.estimatedMinutes = data["estimated_minutes"] as? Int
                existingStep.pathGeometry = data["path_geometry"] as? String
                downloadedCount += 1
                continue
            }

            // Find parent trail and POI
            let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })

            guard let trail = try modelContext.fetch(trailDescriptor).first,
                  let poi = try modelContext.fetch(poiDescriptor).first else { continue }

            let step = TrailStep(
                stepOrder: data["step_order"] as? Int ?? 0,
                directionHint: data["direction_hint"] as? String,
                distanceMeters: data["distance_meters"] as? Int,
                estimatedMinutes: data["estimated_minutes"] as? Int,
                pathGeometry: data["path_geometry"] as? String,
                poi: poi,
                fixedID: remoteId
            )
            trail.steps.append(step)
            downloadedCount += 1
        }

        // Pull Events (enables multi-manager collaboration)
        let remoteEvents = try await networkClient.fetch(from: "events", query: "select=*")
        for eventData in remoteEvents {
            guard let idStr = eventData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(eventData) }
            } else {
                if let newEvent = createEventFromRemote(eventData) { modelContext.insert(newEvent) }
            }
            downloadedCount += 1
        }

        // Pull Contents
        let remoteContents = try await networkClient.fetch(from: "contents", query: "select=*")
        for contentData in remoteContents {
            guard let idStr = contentData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<Content>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(contentData) }
            } else {
                if let newContent = createContentFromRemote(contentData) { modelContext.insert(newContent) }
            }
            downloadedCount += 1
        }

        try modelContext.save()
        return downloadedCount
    }

    private func removeDuplicatePOIs() throws {
        var canonicalById: [UUID: POI] = [:]
        let pois = try modelContext.fetch(FetchDescriptor<POI>())

        for poi in pois {
            if let canonical = canonicalById[poi.id] {
                if canonical.needsSync && !poi.needsSync {
                    modelContext.delete(poi)
                } else if !canonical.needsSync && poi.needsSync {
                    modelContext.delete(canonical)
                    canonicalById[poi.id] = poi
                } else {
                    modelContext.delete(poi)
                }
            } else {
                canonicalById[poi.id] = poi
            }
        }
    }

    private func removeDuplicateTrails() throws {
        var canonicalById: [UUID: Trail] = [:]
        let trails = try modelContext.fetch(FetchDescriptor<Trail>())

        for trail in trails {
            if let canonical = canonicalById[trail.id] {
                if canonical.needsSync && !trail.needsSync {
                    modelContext.delete(trail)
                } else if !canonical.needsSync && trail.needsSync {
                    modelContext.delete(canonical)
                    canonicalById[trail.id] = trail
                } else {
                    modelContext.delete(trail)
                }
            } else {
                canonicalById[trail.id] = trail
            }
        }
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
            photoURL: data["photo_url"] as? String,
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

    private func createEventFromRemote(_ data: [String: Any]) -> Event? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String else { return nil }

        let catStr = data["category"] as? String ?? "other"
        let category = EventCategory.fromSupabase(catStr) ?? .other
        let audienceStr = data["target_audience"] as? String ?? "all"
        let audience = EventAudience.fromSupabase(audienceStr) ?? .all

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss"

        let dateStr = data["date"] as? String ?? ""
        let eventDate = dateFmt.date(from: dateStr) ?? Date()

        let startStr = data["time_start"] as? String ?? "09:00:00"
        let endStr = data["time_end"] as? String ?? "17:00:00"
        let startTime = timeFmt.date(from: startStr) ?? Date()
        let endTime = timeFmt.date(from: endStr) ?? Date()

        let event = Event(
            name: name,
            description: data["description"] as? String ?? "",
            category: category,
            date: eventDate,
            startTime: startTime,
            endTime: endTime,
            maxParticipants: data["max_participants"] as? Int,
            organizerName: data["organizer_name"] as? String,
            contactInfo: data["contact_info"] as? String,
            requirements: data["requirements"] as? String,
            targetAudience: audience,
            price: data["price"] as? Double ?? 0,
            imageURL: data["image_url"] as? String,
            fixedID: id
        )
        event.isActive = data["is_active"] as? Bool ?? false
        event.needsSync = false

        if let pathIdStr = data["path_id"] as? String, let pathId = UUID(uuidString: pathIdStr) {
            let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
            event.trail = try? modelContext.fetch(trailDescriptor).first
        }
        if let poiIdStr = data["event_poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) {
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })
            event.eventPOI = try? modelContext.fetch(poiDescriptor).first
        }

        return event
    }

    private func createContentFromRemote(_ data: [String: Any]) -> Content? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let poiIdStr = data["poi_id"] as? String,
              let poiId = UUID(uuidString: poiIdStr) else { return nil }

        let content = Content(
            poiId: poiId,
            fixedID: id
        )
        content.updateFromRemote(data)
        content.needsSync = false
        return content
    }
}
