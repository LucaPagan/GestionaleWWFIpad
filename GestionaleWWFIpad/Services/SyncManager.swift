//
//  SyncManager.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import Combine
import Network

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
    @Published var isOnline: Bool = true

    private var modelContainer: ModelContainer?
    private let networkClient: NetworkClient
    private let storageService: StorageService
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SyncManager.NetworkMonitor")
    private var syncTask: Task<Void, Never>?

    init(networkClient: NetworkClient? = nil, storageService: StorageService? = nil) {
        self.networkClient = networkClient ?? SupabaseConfig.shared
        self.storageService = storageService ?? StorageManager.shared
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let online = path.status == .satisfied
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    func configure(with context: ModelContext) {
        self.modelContainer = context.container
        updatePendingCount(autoSync: false)
    }
    
    func autoSyncIfNeeded() {
        guard isOnline, pendingChanges > 0 else { return }
        if case .syncing = syncState { return }
        
        syncTask?.cancel()
        syncTask = Task {
            await pushAllChanges()
        }
    }

    func schedulePushPendingChanges(delay: Duration = .seconds(1)) {
        guard isOnline else { return }
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await pushPendingChanges()
        }
    }

    func pushAllChanges() async {
        guard let container = modelContainer else { return }
        if case .syncing = syncState { return }
        
        do {
            print("DEBUG: Starting pushAllChanges"); syncState = .syncing(entity: "Dati in background")
            
            let worker = SyncWorker(modelContainer: container, networkClient: networkClient, storageService: storageService)
            print("DEBUG: Calling performPush"); let pushedCount = try await worker.performPush(); print("DEBUG: performPush finished, pushed: \(pushedCount)")
            print("DEBUG: Calling performPull"); let pulledCount = try await worker.performPull(); print("DEBUG: performPull finished, pulled: \(pulledCount)")
            
            syncState = .success(count: pushedCount + pulledCount)
            lastSyncDate = Date()
            updatePendingCount()
        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    func pushPendingChanges() async {
        guard let container = modelContainer else { return }
        if case .syncing = syncState { return }

        do {
            syncState = .syncing(entity: "Invio modifiche")

            let worker = SyncWorker(modelContainer: container, networkClient: networkClient, storageService: storageService)
            print("DEBUG: Calling performPush"); let pushedCount = try await worker.performPush(); print("DEBUG: performPush finished, pushed: \(pushedCount)")

            syncState = .success(count: pushedCount)
            lastSyncDate = Date()
            updatePendingCount(autoSync: false)
        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    /// Invia solo le entità gamification con `needsSync` (stesso flusso dei POI, senza pull).
    func pushGamificationPendingChanges() async throws {
        guard let container = modelContainer else { return }
        if case .syncing = syncState { return }

        syncState = .syncing(entity: "Gamification")
        let worker = SyncWorker(modelContainer: container, networkClient: networkClient, storageService: storageService)
        let pushedCount = try await worker.performGamificationPush()
        syncState = .success(count: pushedCount)
        lastSyncDate = Date()
        updatePendingCount(autoSync: false)
    }

    func pullLatestData() async {
        guard let container = modelContainer else { return }
        if case .syncing = syncState { return }

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

    func updatePendingCount(autoSync: Bool = true) {
        guard let container = modelContainer else {
            pendingChanges = 0
            return
        }
        let context = ModelContext(container)
        
        let poisDesc = FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true })
        let trailsDesc = FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true })
        let eventsDesc = FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true })
        let contentsDesc = FetchDescriptor<Content>(predicate: #Predicate { $0.needsSync == true })
        let badgesDesc = FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.needsSync == true })
        let speciesDesc = FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.needsSync == true })
        let levelsDesc = FetchDescriptor<GamificationLevel>(predicate: #Predicate { $0.needsSync == true })
        let rulesDesc = FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.needsSync == true })
        let campaignsDesc = FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.needsSync == true })
        
        let pCount = (try? context.fetchCount(poisDesc)) ?? 0
        let tCount = (try? context.fetchCount(trailsDesc)) ?? 0
        let eCount = (try? context.fetchCount(eventsDesc)) ?? 0
        let cCount = (try? context.fetchCount(contentsDesc)) ?? 0
        let gCount = (try? context.fetchCount(badgesDesc)) ?? 0
            + ((try? context.fetchCount(speciesDesc)) ?? 0)
            + ((try? context.fetchCount(levelsDesc)) ?? 0)
            + ((try? context.fetchCount(rulesDesc)) ?? 0)
            + ((try? context.fetchCount(campaignsDesc)) ?? 0)

        pendingChanges = pCount + tCount + eCount + cCount + gCount
        
        if autoSync && pendingChanges > 0 && isOnline {
            autoSyncIfNeeded()
        }
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
        print("DEBUG: performPush started")
        var changedCount = 0
        var bundleCandidates = Set<UUID>()

        defer {
            try? modelContext.save()
            if modelContext.hasChanges {
                modelContext.rollback()
            }
        }

        print("DEBUG: Removing duplicates"); try removeDuplicatePOIs()
        try removeDuplicateTrails()
        try removeDuplicateEvents()

        print("DEBUG: Fetching POIs"); let dirtyPOIs = try modelContext.fetch(FetchDescriptor<POI>(predicate: #Predicate { $0.needsSync == true }))
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

        print("DEBUG: Fetching Contents"); let dirtyContents = try modelContext.fetch(FetchDescriptor<Content>(predicate: #Predicate { $0.needsSync == true }))
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

        print("DEBUG: Fetching Trails"); let dirtyTrails = try modelContext.fetch(FetchDescriptor<Trail>(predicate: #Predicate { $0.needsSync == true }))
                for trail in dirtyTrails {
            print("DEBUG: Syncing trail \(trail.id)")
            try await syncTrailWithPublishGate(trail)
            changedCount += 1
            if trail.isActive { bundleCandidates.insert(trail.id) }
        }

                print("DEBUG: Starting bundle candidates \(bundleCandidates.count)")
        for trailId in bundleCandidates {
            print("DEBUG: Bundle for trail \(trailId)")
            let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == trailId })
            guard let trail = try modelContext.fetch(descriptor).first, trail.isActive, !trail.needsSync else { continue }
            let contents = try allContents()
            let issues = AdminValidationService.trailIssues(trail: trail, contents: contents)
            if issues.contains(where: { $0.severity == .error }) {
                throw AdminSyncError(messages: issues.map(\.message))
            }
            print("DEBUG: Generating bundles for \(trail.id)"); try await regenerateAndVerifyBundles(for: trail); print("DEBUG: Finished generating bundles for \(trail.id)")
        }

        print("DEBUG: Fetching Events"); let dirtyEvents = try modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.needsSync == true }))
        try await refreshReferencesForDirtyEvents(dirtyEvents)
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
        
        print("DEBUG: Starting gamification push"); changedCount += try await performGamificationPush(); print("DEBUG: Finished gamification push")
        try? modelContext.save()
        return changedCount
    }

    func performGamificationPush() async throws -> Int {
        var changedCount = 0

        defer {
            try? modelContext.save()
            if modelContext.hasChanges {
                modelContext.rollback()
            }
        }

        let dirtyBadges = try modelContext.fetch(FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.needsSync == true }))
        for badge in dirtyBadges {
            var payload = stablePayload(from: badge.toSupabaseParams())
            if let photoData = stableImageData(from: badge.photoData), badge.imageURL == nil || badge.imageURL?.isEmpty == true {
                let uploadedURL = try await storageService.uploadImage(
                    data: photoData,
                    path: "gamification/badges/\(badge.id.uuidString).jpg"
                )
                badge.imageURL = uploadedURL
                payload["image_url"] = uploadedURL
            }
            _ = try await networkClient.upsert(into: "badges", values: payload)
            badge.needsSync = false
            badge.updatedAt = Date()
            changedCount += 1
        }

        let dirtySpecies = try modelContext.fetch(FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.needsSync == true }))
        for species in dirtySpecies {
            var payload = stablePayload(from: species.toSupabaseParams())
            if let photoData = stableImageData(from: species.photoData), species.imageURL == nil || species.imageURL?.isEmpty == true {
                let uploadedURL = try await storageService.uploadImage(
                    data: photoData,
                    path: "gamification/species/\(species.id.uuidString).jpg"
                )
                species.imageURL = uploadedURL
                payload["image_url"] = uploadedURL
            }
            _ = try await networkClient.upsert(into: "species", values: payload)
            species.needsSync = false
            species.updatedAt = Date()
            changedCount += 1
        }

        let dirtyLevels = try modelContext.fetch(FetchDescriptor<GamificationLevel>(predicate: #Predicate { $0.needsSync == true }))
        for level in dirtyLevels {
            var payload = stablePayload(from: level.toSupabaseParams())
            if let photoData = stableImageData(from: level.photoData), level.imageURL == nil || level.imageURL?.isEmpty == true {
                let uploadedURL = try await storageService.uploadImage(
                    data: photoData,
                    path: "gamification/levels/\(level.id.uuidString).jpg"
                )
                level.imageURL = uploadedURL
                payload["image_url"] = uploadedURL
            }
            _ = try await networkClient.upsert(into: "gamification_levels", values: payload)
            level.needsSync = false
            level.updatedAt = Date()
            changedCount += 1
        }

        let dirtyRules = try modelContext.fetch(FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.needsSync == true }))
        for rule in dirtyRules {
            let payload = stablePayload(from: rule.toSupabaseParams())
            _ = try await networkClient.upsert(into: "gamification_rules", values: payload)
            rule.needsSync = false
            rule.updatedAt = Date()
            changedCount += 1
        }

        let dirtyCampaigns = try modelContext.fetch(FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.needsSync == true }))
        for campaign in dirtyCampaigns {
            var payload = stablePayload(from: campaign.toSupabaseParams())
            if let photoData = stableImageData(from: campaign.photoData), campaign.imageURL == nil || campaign.imageURL?.isEmpty == true {
                let uploadedURL = try await storageService.uploadImage(
                    data: photoData,
                    path: "gamification/campaigns/\(campaign.id.uuidString).jpg"
                )
                campaign.imageURL = uploadedURL
                payload["image_url"] = uploadedURL
            }
            _ = try await networkClient.upsert(into: "gamification_campaigns", values: payload)
            campaign.needsSync = false
            campaign.updatedAt = Date()
            changedCount += 1
        }

        try? modelContext.save()
        return changedCount
    }

    private func stablePayload(from params: [String: Any?]) -> [String: Any?] {
        SupabaseJSONSanitizer.object(from: params).mapValues { $0 as Any? }
    }

    private func stableImageData(from data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        return Data(data)
    }

    private func syncTrailWithPublishGate(_ trail: Trail) async throws {
        print("DEBUG: syncTrailWithPublishGate start")
        let desiredActive = trail.isActive
        defer {
            trail.isActive = desiredActive
        }
        let contents = try allContents()
        let issues = AdminValidationService.trailIssues(trail: trail, contents: contents)
        if issues.contains(where: { $0.severity == .error }) {
            throw AdminSyncError(messages: issues.map(\.message))
        }

        if desiredActive {
            // STEP 1: Salva come bozza (isActive = false) per superare i controlli del database
            // che impediscono di aggiornare un percorso pubblicato se i bundle sono obsoleti.
            trail.isActive = false
            try await pushTrail(trail)
            
            // STEP 2: Genera i bundle per i dati appena salvati in bozza.
            print("DEBUG: Generating initial bundles for \(trail.id)")
            try await regenerateAndVerifyBundles(for: trail)
            
            // STEP 3: Ora che i bundle sono pronti, possiamo pubblicare ufficialmente il percorso.
            trail.isActive = true
            try await pushTrail(trail)
            
            // STEP 4: Rigenera i bundle un'ultima volta per includere il nuovo stato "isActive = true" nel JSON.
            print("DEBUG: Generating final bundles for \(trail.id)")
            try await regenerateAndVerifyBundles(for: trail)
        } else {
            try deactivateLocalEvents(referencing: trail)
            try await pushTrail(trail)
        }

        trail.needsSync = false
    }

        private func pushTrail(_ trail: Trail) async throws {
        print("DEBUG: pushTrail start")
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
        print("DEBUG: Regenerating bundles concurrently for \(trail.id)")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for tier in ContentTier.allCases {
                group.addTask {
                    print("DEBUG: Triggering generate-bundle for tier: \(tier.rawValue)")
                    _ = try await self.networkClient.invokeFunction("generate-bundle", body: [
                        "path_id": trail.id.uuidString,
                        "tier": tier.rawValue
                    ])
                    print("DEBUG: Finished generate-bundle for tier: \(tier.rawValue)")
                }
            }
            try await group.waitForAll()
        }
        print("DEBUG: All tiers generated, fetching readiness")

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

    private func deactivateLocalEvents(referencing trail: Trail) throws {
        let events = try modelContext.fetch(FetchDescriptor<Event>())
        for event in events where event.trail?.id == trail.id && event.isActive {
            event.isActive = false
            event.needsSync = true
            event.updatedAt = Date()
        }
    }

    private func refreshReferencesForDirtyEvents(_ events: [Event]) async throws {
        var refreshedTrailIds = Set<UUID>()
        var refreshedPOIIds = Set<UUID>()

        for event in events where event.isActive {
            if let trail = event.trail, !trail.isActive, !refreshedTrailIds.contains(trail.id) {
                try await refreshTrailFromRemote(id: trail.id)
                refreshedTrailIds.insert(trail.id)
            }

            if let poi = event.eventPOI, !poi.isActive, !refreshedPOIIds.contains(poi.id) {
                try await refreshPOIFromRemote(id: poi.id)
                refreshedPOIIds.insert(poi.id)
            }
        }
    }

    private func refreshTrailFromRemote(id: UUID) async throws {
        let rows = try await networkClient.fetch(from: "paths", query: "select=*&id=eq.\(id.uuidString)")
        guard let data = rows.first else { return }
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        if let trail = try modelContext.fetch(descriptor).first, !trail.needsSync {
            trail.updateFromRemote(data)
        } else if let trail = try modelContext.fetch(descriptor).first,
                  (data["is_active"] as? Bool) == true {
            trail.isActive = true
        }
    }

    private func refreshPOIFromRemote(id: UUID) async throws {
        let rows = try await networkClient.fetch(from: "pois", query: "select=*&id=eq.\(id.uuidString)")
        guard let data = rows.first else { return }
        let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
        if let poi = try modelContext.fetch(descriptor).first, !poi.needsSync {
            poi.updateFromRemote(data)
        } else if let poi = try modelContext.fetch(descriptor).first,
                  (data["is_active"] as? Bool) == true {
            poi.isActive = true
        }
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
        let targetLanguages = ["en", "de", "fr"]
        let client = networkClient
        let recordIdString = recordId.uuidString
        await withTaskGroup(of: Void.self) { group in
            for lang in targetLanguages {
                for (fieldName, text) in fields {
                    group.addTask {
                        let translated = await TranslationService.shared.translate(text, to: lang)
                        let params: [String: Any?] = [
                            "p_id": UUID().uuidString,
                            "p_table_name": table,
                            "p_record_id": recordIdString,
                            "p_field_name": fieldName,
                            "p_language_code": lang,
                            "p_translated_text": translated
                        ]
                        _ = try? await client.rpc("upsert_translation", params: params)
                    }
                }
            }
        }
    }


    func performPull() async throws -> Int {
        var downloadedCount = 0
        let remoteFactory = AdminRemoteEntityFactory(modelContext: modelContext)
        
        defer {
            try? modelContext.save()
            if modelContext.hasChanges {
                modelContext.rollback()
            }
        }

        // Pull POIs
        let remotePOIs = try await networkClient.fetch(from: "pois", query: "select=*")
        for poiData in remotePOIs {
            guard let idStr = poiData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(poiData) }
            } else {
                if let newPOI = remoteFactory.makePOI(from: poiData) { modelContext.insert(newPOI) }
            }
            downloadedCount += 1
        }
        print("DEBUG: Removing duplicates"); try removeDuplicatePOIs()

        // Pull Paths
        let remotePaths = try await networkClient.fetch(from: "paths", query: "select=*")
        for pathData in remotePaths {
            guard let idStr = pathData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(pathData) }
            } else {
                if let newTrail = remoteFactory.makeTrail(from: pathData) { modelContext.insert(newTrail) }
            }
            downloadedCount += 1
        }
        try removeDuplicateTrails()

        // Pull PathSteps (con path_geometry per i sentieri disegnati)
        let remoteSteps = try await networkClient.fetch(
            from: "path_steps",
            query: "select=*&order=step_order.asc"
        )
        var remoteStepIds = Set<UUID>()
        for data in remoteSteps {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            guard let pathIdStr = data["path_id"] as? String, let pathId = UUID(uuidString: pathIdStr) else { continue }
            guard let poiIdStr = data["poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) else { continue }
            remoteStepIds.insert(remoteId)

            let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })
            guard let trail = try modelContext.fetch(trailDescriptor).first,
                  let poi = try modelContext.fetch(poiDescriptor).first else { continue }

            let stepDescriptor = FetchDescriptor<TrailStep>(predicate: #Predicate { $0.id == remoteId })
            if let existingStep = try modelContext.fetch(stepDescriptor).first {
                existingStep.stepOrder = data["step_order"] as? Int ?? existingStep.stepOrder
                existingStep.directionHint = data["direction_hint"] as? String
                existingStep.distanceMeters = data["distance_meters"] as? Int
                existingStep.estimatedMinutes = data["estimated_minutes"] as? Int
                existingStep.pathGeometry = data["path_geometry"] as? String
                existingStep.poi = poi
                if !trail.steps.contains(where: { $0.id == existingStep.id }) {
                    trail.steps.append(existingStep)
                }
                downloadedCount += 1
                continue
            }

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
        try removeLocalStepsMissingRemotely(remoteStepIds)

        // Pull Events (enables multi-manager collaboration)
        let remoteEvents = try await networkClient.fetch(from: "events", query: "select=*")
        var remoteEventIds = Set<UUID>()
        for eventData in remoteEvents {
            guard let idStr = eventData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteEventIds.insert(remoteId)
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync {
                    existing.updateFromRemote(eventData)
                    try updateEventRelationships(existing, from: eventData)
                }
            } else {
                if let newEvent = remoteFactory.makeEvent(from: eventData) { modelContext.insert(newEvent) }
            }
            downloadedCount += 1
        }
        try removeDuplicateEvents()
        try removeLocalEventsMissingRemotely(remoteEventIds)

        // Pull Contents
        let remoteContents = try await networkClient.fetch(from: "contents", query: "select=*")
        var remoteContentIds = Set<UUID>()
        for contentData in remoteContents {
            guard let idStr = contentData["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteContentIds.insert(remoteId)
            let descriptor = FetchDescriptor<Content>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(contentData) }
            } else {
                if let newContent = remoteFactory.makeContent(from: contentData) { modelContext.insert(newContent) }
            }
            downloadedCount += 1
        }
        try removeLocalContentsMissingRemotely(remoteContentIds)

        downloadedCount += try await pullGamificationDefinitions()

        try modelContext.save()
        return downloadedCount
    }

    private func pullGamificationDefinitions() async throws -> Int {
        var downloadedCount = 0
        downloadedCount += try await pullBadges()
        downloadedCount += try await pullSpecies()
        downloadedCount += try await pullLevels()
        downloadedCount += try await pullRules()
        downloadedCount += try await pullCampaigns()
        return downloadedCount
    }

    private func pullBadges() async throws -> Int {
        let rows = try await networkClient.fetch(from: "badges", query: "select=*&order=sort_order.asc")
        var remoteIds = Set<UUID>()
        var count = 0

        for row in rows {
            guard let id = Self.uuidValue(row["id"]) else { continue }
            remoteIds.insert(id)
            let descriptor = FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.id == id })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(row) }
            } else {
                let badge = GamificationBadge(id: id, needsSync: false)
                badge.updateFromRemote(row)
                modelContext.insert(badge)
            }
            count += 1
        }

        try removeLocalBadgesMissingRemotely(remoteIds)
        return count
    }

    private func pullSpecies() async throws -> Int {
        let rows = try await networkClient.fetch(from: "species", query: "select=*&order=name.asc")
        var remoteIds = Set<UUID>()
        var count = 0

        for row in rows {
            guard let id = Self.uuidValue(row["id"]) else { continue }
            remoteIds.insert(id)
            let descriptor = FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.id == id })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(row) }
            } else {
                let species = GamificationSpecies(id: id, needsSync: false)
                species.updateFromRemote(row)
                modelContext.insert(species)
            }
            count += 1
        }

        try removeLocalSpeciesMissingRemotely(remoteIds)
        return count
    }

    private func pullLevels() async throws -> Int {
        let rows = try await networkClient.fetch(from: "gamification_levels", query: "select=*&order=level_number.asc")
        var remoteIds = Set<UUID>()
        var count = 0

        for row in rows {
            guard let id = Self.uuidValue(row["id"]) else { continue }
            remoteIds.insert(id)
            let descriptor = FetchDescriptor<GamificationLevel>(predicate: #Predicate { $0.id == id })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(row) }
            } else {
                let level = GamificationLevel(id: id, needsSync: false)
                level.updateFromRemote(row)
                modelContext.insert(level)
            }
            count += 1
        }

        try removeLocalLevelsMissingRemotely(remoteIds)
        return count
    }

    private func pullRules() async throws -> Int {
        let rows = try await networkClient.fetch(from: "gamification_rules", query: "select=*&order=priority.desc")
        var remoteIds = Set<UUID>()
        var count = 0

        for row in rows {
            guard let id = Self.uuidValue(row["id"]) else { continue }
            remoteIds.insert(id)
            let descriptor = FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.id == id })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(row) }
            } else {
                let rule = GamificationRule(id: id, needsSync: false)
                rule.updateFromRemote(row)
                modelContext.insert(rule)
            }
            count += 1
        }

        try removeLocalRulesMissingRemotely(remoteIds)
        return count
    }

    private func pullCampaigns() async throws -> Int {
        let rows = try await networkClient.fetch(from: "gamification_campaigns", query: "select=*&order=starts_at.desc")
        var remoteIds = Set<UUID>()
        var count = 0

        for row in rows {
            guard let id = Self.uuidValue(row["id"]) else { continue }
            remoteIds.insert(id)
            let descriptor = FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.id == id })
            if let existing = try modelContext.fetch(descriptor).first {
                if !existing.needsSync { existing.updateFromRemote(row) }
            } else {
                let campaign = GamificationCampaign(id: id, needsSync: false)
                campaign.updateFromRemote(row)
                modelContext.insert(campaign)
            }
            count += 1
        }

        try removeLocalCampaignsMissingRemotely(remoteIds)
        return count
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

    private func removeDuplicateEvents() throws {
        var canonicalById: [UUID: Event] = [:]
        let events = try modelContext.fetch(FetchDescriptor<Event>())

        for event in events {
            if let canonical = canonicalById[event.id] {
                if canonical.needsSync && !event.needsSync {
                    modelContext.delete(event)
                } else if !canonical.needsSync && event.needsSync {
                    modelContext.delete(canonical)
                    canonicalById[event.id] = event
                } else {
                    modelContext.delete(event)
                }
            } else {
                canonicalById[event.id] = event
            }
        }
    }

    private func removeLocalStepsMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let steps = try modelContext.fetch(FetchDescriptor<TrailStep>())
        for step in steps where !remoteIds.contains(step.id) {
            modelContext.delete(step)
        }
    }

    private func removeLocalContentsMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let contents = try modelContext.fetch(FetchDescriptor<Content>())
        for content in contents where !content.needsSync && !remoteIds.contains(content.id) {
            modelContext.delete(content)
        }
    }

    private func removeLocalEventsMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let events = try modelContext.fetch(FetchDescriptor<Event>())
        for event in events where !event.needsSync && !remoteIds.contains(event.id) {
            modelContext.delete(event)
        }
    }

    private func removeLocalBadgesMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let badges = try modelContext.fetch(FetchDescriptor<GamificationBadge>())
        for badge in badges where !badge.needsSync && !remoteIds.contains(badge.id) {
            modelContext.delete(badge)
        }
    }

    private func removeLocalSpeciesMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let species = try modelContext.fetch(FetchDescriptor<GamificationSpecies>())
        for item in species where !item.needsSync && !remoteIds.contains(item.id) {
            modelContext.delete(item)
        }
    }

    private func removeLocalLevelsMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let levels = try modelContext.fetch(FetchDescriptor<GamificationLevel>())
        for level in levels where !level.needsSync && !remoteIds.contains(level.id) {
            modelContext.delete(level)
        }
    }

    private func removeLocalRulesMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let rules = try modelContext.fetch(FetchDescriptor<GamificationRule>())
        for rule in rules where !rule.needsSync && !remoteIds.contains(rule.id) {
            modelContext.delete(rule)
        }
    }

    private func removeLocalCampaignsMissingRemotely(_ remoteIds: Set<UUID>) throws {
        let campaigns = try modelContext.fetch(FetchDescriptor<GamificationCampaign>())
        for campaign in campaigns where !campaign.needsSync && !remoteIds.contains(campaign.id) {
            modelContext.delete(campaign)
        }
    }

    private func updateEventRelationships(_ event: Event, from data: [String: Any]) throws {
        event.trail = try fetchTrail(id: Self.uuidValue(data["path_id"]))
        event.eventPOI = try fetchPOI(id: Self.uuidValue(data["event_poi_id"]))
    }

    private func fetchTrail(id: UUID?) throws -> Trail? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private func fetchPOI(id: UUID?) throws -> POI? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private nonisolated static func uuidValue(_ value: Any?) -> UUID? {
        guard let value, !(value is NSNull) else { return nil }
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }
}
