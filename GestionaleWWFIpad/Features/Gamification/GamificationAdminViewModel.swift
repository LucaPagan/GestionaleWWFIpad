import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class GamificationAdminViewModel: ObservableObject {
    @Published var selectedTab: GamificationAdminTab = .dashboard
    @Published var pois: [AdminReference] = []
    @Published var paths: [AdminReference] = []
    @Published var events: [AdminReference] = []
    @Published var analytics = GamificationAnalytics()
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let client: NetworkClient
    private let syncManager: SyncManager

    init(client: NetworkClient? = nil, syncManager: SyncManager? = nil) {
        self.client = client ?? SupabaseConfig.shared
        self.syncManager = syncManager ?? SyncManager.shared
    }

    func loadAll(context: ModelContext) async {
        isLoading = true
        errorMessage = nil
        do {
            if syncManager.isOnline {
                await syncManager.pullLatestData()
            }

            try reloadReferences(context: context)

            if syncManager.isOnline {
                analytics = try await loadAnalytics(context: context)
            } else {
                analytics = localAnalytics(context: context)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func reloadReferences(context: ModelContext) throws {
        let pDesc = FetchDescriptor<POI>(sortBy: [SortDescriptor(\.name)])
        let pathDesc = FetchDescriptor<Trail>(sortBy: [SortDescriptor(\.name)])
        let eDesc = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date, order: .reverse)])

        pois = try context.fetch(pDesc).map { AdminReference(id: $0.id.uuidString, title: $0.name) }
            .reduce(into: [AdminReference]()) { if !$0.contains($1) { $0.append($1) } }
        paths = try context.fetch(pathDesc).map { AdminReference(id: $0.id.uuidString, title: $0.name) }
            .reduce(into: [AdminReference]()) { if !$0.contains($1) { $0.append($1) } }
        events = try context.fetch(eDesc).map { AdminReference(id: $0.id.uuidString, title: $0.name) }
            .reduce(into: [AdminReference]()) { if !$0.contains($1) { $0.append($1) } }
    }

    func saveModel(context: ModelContext) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
            isSaving = false
            return true
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
            isSaving = false
            return false
        }
    }

    func delete<T: PersistentModel>(model: T, context: ModelContext) async {
        isSaving = true
        errorMessage = nil
        do {
            context.delete(model)
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
        }
        isSaving = false
    }

    private func loadAnalytics(context: ModelContext) async throws -> GamificationAnalytics {
        async let userBadges = client.fetch(from: "user_badges", query: "select=badge_id&limit=10000")
        async let userSpecies = client.fetch(from: "user_species", query: "select=species_id&limit=10000")
        async let completedTrails = client.fetch(from: "user_path_progresses", query: "select=path_id,status&status=eq.completed&limit=10000")
        async let completedEvents = client.fetch(from: "user_event_completions", query: "select=event_id&limit=10000")
        async let validationLogs = client.fetch(from: "gamification_validation_logs", query: "select=event_type,entity_type,entity_id,status,reason,created_at&status=in.(rejected,warning)&order=created_at.desc&limit=30")

        let badgeRows = try await userBadges
        let speciesRows = try await userSpecies
        let trailRows = try await completedTrails
        let eventRows = try await completedEvents
        let logs = try await validationLogs

        let rDesc = FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.isActive == true })
        let cDesc = FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.isActive == true })
        let bDesc = FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.isActive == true })
        let sDesc = FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.isActive == true })

        let activeRuleCount = (try? context.fetch(rDesc).count) ?? 0
        let activeCampaignCount = (try? context.fetch(cDesc).count) ?? 0
        let activeBadgeCount = (try? context.fetch(bDesc).count) ?? 0
        let activeSpeciesCount = (try? context.fetch(sDesc).count) ?? 0

        // Build Title Maps for Analytics Ranking
        let allBadges = try? context.fetch(FetchDescriptor<GamificationBadge>())
        let badgeTitles = Dictionary((allBadges ?? []).map { ($0.id.uuidString, $0.title) }, uniquingKeysWith: { first, _ in first })

        let allSpecies = try? context.fetch(FetchDescriptor<GamificationSpecies>())
        let speciesTitles = Dictionary((allSpecies ?? []).map { ($0.id.uuidString, $0.name) }, uniquingKeysWith: { first, _ in first })

        return GamificationAnalytics(
            metrics: [
                AnalyticsMetric(title: "Regole attive", value: "\(activeRuleCount)", icon: "slider.horizontal.3"),
                AnalyticsMetric(title: "Badge pubblicati", value: "\(activeBadgeCount)", icon: "rosette"),
                AnalyticsMetric(title: "Specie pubblicate", value: "\(activeSpeciesCount)", icon: "leaf.fill"),
                AnalyticsMetric(title: "Campagne attive", value: "\(activeCampaignCount)", icon: "calendar.badge.clock")
            ],
            badges: ranked(rows: badgeRows, key: "badge_id", titles: badgeTitles),
            species: ranked(rows: speciesRows, key: "species_id", titles: speciesTitles),
            trails: ranked(rows: trailRows, key: "path_id", titles: Dictionary(paths.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })),
            events: ranked(rows: eventRows, key: "event_id", titles: Dictionary(events.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })),
            suspiciousLogs: logs
        )
    }

    private func localAnalytics(context: ModelContext) -> GamificationAnalytics {
        let activeRuleCount = ((try? context.fetch(FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.isActive == true }))) ?? []).count
        let activeCampaignCount = ((try? context.fetch(FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.isActive == true }))) ?? []).count
        let activeBadgeCount = ((try? context.fetch(FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.isActive == true }))) ?? []).count
        let activeSpeciesCount = ((try? context.fetch(FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.isActive == true }))) ?? []).count

        return GamificationAnalytics(metrics: [
            AnalyticsMetric(title: "Regole attive", value: "\(activeRuleCount)", icon: "slider.horizontal.3"),
            AnalyticsMetric(title: "Badge pubblicati", value: "\(activeBadgeCount)", icon: "rosette"),
            AnalyticsMetric(title: "Specie pubblicate", value: "\(activeSpeciesCount)", icon: "leaf.fill"),
            AnalyticsMetric(title: "Campagne attive", value: "\(activeCampaignCount)", icon: "calendar.badge.clock")
        ])
    }

    private func ranked(rows: [[String: Any]], key: String, titles: [String: String]) -> [AnalyticsRankRow] {
        let counts = rows.reduce(into: [String: Int]()) { partial, row in
            guard let id = rowString(row, key) else { return }
            partial[id, default: 0] += 1
        }
        return counts
            .map { AnalyticsRankRow(id: $0.key, title: titles[$0.key] ?? "Elemento rimosso", count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
}
