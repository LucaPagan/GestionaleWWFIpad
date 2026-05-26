import Combine
import SwiftData
import PhotosUI
import Security
import SwiftUI
import UIKit

enum GamificationAdminTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case badges = "Badge"
    case species = "Specie"
    case levels = "Livelli"
    case rules = "Regole"
    case campaigns = "Campagne"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.xaxis"
        case .badges: "rosette"
        case .species: "leaf.fill"
        case .levels: "seal.fill"
        case .rules: "slider.horizontal.3"
        case .campaigns: "calendar.badge.clock"
        }
    }
}

private enum AdminEditor: Identifiable {
    case badge(GamificationBadgeDraft)
    case species(GamificationSpeciesDraft)
    case level(GamificationLevelDraft)
    case rule(GamificationRuleDraft)
    case campaign(GamificationCampaignDraft)

    var id: String {
        switch self {
        case .badge(let draft): "badge-\(draft.id)"
        case .species(let draft): "species-\(draft.id)"
        case .level(let draft): "level-\(draft.id)"
        case .rule(let draft): "rule-\(draft.id)"
        case .campaign(let draft): "campaign-\(draft.id)"
        }
    }
}

private enum GamificationID {
    static func make() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for index in bytes.indices {
                bytes[index] = UInt8.random(in: UInt8.min...UInt8.max)
            }
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return String(
            format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
    }

    static func fromRow(_ row: [String: Any]) -> String {
        (row["id"] as? String) ?? make()
    }
}

private enum BadgeCategory: String, CaseIterable, Identifiable {
    case exploration
    case nature
    case events
    case seasonal
    case kids
    case special
    case loyalty

    var id: String { rawValue }
    var title: String {
        switch self {
        case .exploration: "Esplorazione"
        case .nature: "Natura"
        case .events: "Eventi"
        case .seasonal: "Stagionali"
        case .kids: "Kids"
        case .special: "Speciali"
        case .loyalty: "Fedelta"
        }
    }
}

private enum SpeciesCategory: String, CaseIterable, Identifiable {
    case fauna
    case flora
    case habitat
    case geology
    case conservation
    case history

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fauna: "Fauna"
        case .flora: "Flora"
        case .habitat: "Habitat"
        case .geology: "Geologia"
        case .conservation: "Conservazione"
        case .history: "Storia"
        }
    }
}

private enum GamificationRarity: String, CaseIterable, Identifiable {
    case common
    case uncommon
    case rare
    case legendary

    var id: String { rawValue }
    var title: String {
        switch self {
        case .common: "Comune"
        case .uncommon: "Non comune"
        case .rare: "Rara"
        case .legendary: "Leggendaria"
        }
    }
}

private enum RuleTriggerType: String, CaseIterable, Identifiable {
    case poiScanned = "poi_scanned"
    case trailStarted = "trail_started"
    case trailCompleted = "trail_completed"
    case allPOIsInTrailCompleted = "all_pois_in_trail_completed"
    case eventRegistered = "event_registered"
    case eventCompleted = "event_completed"
    case audioGuideListened = "audio_guide_listened"
    case speciesUnlocked = "species_unlocked"
    case badgeUnlocked = "badge_unlocked"
    case dailyVisit = "daily_visit"
    case seasonalCampaign = "seasonal_campaign"
    case manualAdminGrant = "manual_admin_grant"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .poiScanned: "POI scansionato"
        case .trailStarted: "Percorso iniziato"
        case .trailCompleted: "Percorso completato"
        case .allPOIsInTrailCompleted: "Tutti i POI del percorso"
        case .eventRegistered: "Evento prenotato"
        case .eventCompleted: "Evento completato"
        case .audioGuideListened: "Audio guida ascoltata"
        case .speciesUnlocked: "Specie scoperta"
        case .badgeUnlocked: "Badge sbloccato"
        case .dailyVisit: "Visita giornaliera"
        case .seasonalCampaign: "Campagna stagionale"
        case .manualAdminGrant: "Assegnazione manuale"
        }
    }
}

private enum RuleConditionType: String, CaseIterable, Identifiable {
    case none
    case poiCountTotalGTE
    case path
    case poi
    case event
    case species
    case completionPercent
    case audioPercent

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Nessuna condizione"
        case .poiCountTotalGTE: "Numero POI visitati"
        case .path: "Percorso specifico"
        case .poi: "POI specifico"
        case .event: "Evento specifico"
        case .species: "Specie specifica"
        case .completionPercent: "Completamento percorso"
        case .audioPercent: "Percentuale audio"
        }
    }
}

private enum GamificationAudience: String, CaseIterable, Identifiable {
    case all
    case kids
    case adults
    case registered
    case anonymous

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Tutti"
        case .kids: "Kids"
        case .adults: "Adulti"
        case .registered: "Registrati"
        case .anonymous: "Ospiti"
        }
    }
}

private struct AdminReference: Identifiable, Hashable {
    let id: String
    let title: String
}

private struct AnalyticsMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

private struct AnalyticsRankRow: Identifiable {
    let id: String
    let title: String
    let count: Int
}

private struct GamificationAnalytics {
    var metrics: [AnalyticsMetric] = []
    var badges: [AnalyticsRankRow] = []
    var species: [AnalyticsRankRow] = []
    var trails: [AnalyticsRankRow] = []
    var events: [AnalyticsRankRow] = []
    var suspiciousLogs: [[String: Any]] = []
}

private enum GamificationError: LocalizedError {
    case network(String)
    case permissionRLS(String)
    case databaseViolation(String)
    case dataCorruption(String)
    case storage(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network(let detail):
            return "Errore di rete: controlla la tua connessione internet. Dettagli: \(detail)"
        case .permissionRLS(let detail):
            return "Errore di autorizzazione (RLS): non hai i permessi necessari per completare l'operazione. Dettagli: \(detail)"
        case .databaseViolation(let detail):
            return "Errore database: l'operazione viola le regole di validazione o i vincoli del database. Dettagli: \(detail)"
        case .dataCorruption(let detail):
            return "Errore dati: i dati o l'immagine caricati sono corrotti o non validi. Dettagli: \(detail)"
        case .storage(let detail):
            return "Errore di archiviazione: impossibile salvare l'immagine. Dettagli: \(detail)"
        case .unknown(let detail):
            return "Errore imprevisto: \(detail)"
        }
    }

    static func map(_ error: Error) -> GamificationError {
        if let sbError = error as? SupabaseError {
            switch sbError {
            case .networkError(let msg):
                return .network(msg)
            case .authError(let msg):
                return .permissionRLS(msg)
            case .apiError(let msg):
                let lowerMsg = msg.lowercased()
                if lowerMsg.contains("row-level security") || lowerMsg.contains("policy") || lowerMsg.contains("permission denied") || lowerMsg.contains("403") || lowerMsg.contains("401") {
                    return .permissionRLS(msg)
                } else if lowerMsg.contains("violates") || lowerMsg.contains("constraint") || lowerMsg.contains("null") || lowerMsg.contains("400") {
                    return .databaseViolation(msg)
                }
                return .unknown(msg)
            case .storageError(let msg):
                return .storage(msg)
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(error.localizedDescription)
        }

        return .unknown(error.localizedDescription)
    }
}

@MainActor
private final class GamificationAdminViewModel: ObservableObject {
    @Published var selectedTab: GamificationAdminTab = .dashboard
    @Published var badges: [[String: Any]] = []
    @Published var species: [[String: Any]] = []
    @Published var levels: [[String: Any]] = []
    @Published var rules: [[String: Any]] = []
    @Published var campaigns: [[String: Any]] = []
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

    var rowsForSelectedTab: [[String: Any]] {
        switch selectedTab {
        case .dashboard: []
        case .badges: badges
        case .species: species
        case .levels: levels
        case .rules: rules
        case .campaigns: campaigns
        }
    }

    func loadAll(context: ModelContext) async {
        isLoading = true
        errorMessage = nil
        do {
            async let remoteBadges = client.fetch(from: "badges", query: "select=*&order=sort_order.asc")
            async let remoteSpecies = client.fetch(from: "species", query: "select=*&order=name.asc")
            async let remoteLevels = client.fetch(from: "gamification_levels", query: "select=*&order=required_xp.asc")
            async let remoteRules = client.fetch(from: "gamification_rules", query: "select=*&order=priority.desc")
            async let remoteCampaigns = client.fetch(from: "gamification_campaigns", query: "select=*&order=starts_at.desc")

            try reloadReferences(context: context)
            badges = try await remoteBadges
            species = try await remoteSpecies
            levels = try await remoteLevels
            rules = try await remoteRules
            campaigns = try await remoteCampaigns

            if SyncManager.shared.isOnline {
                analytics = try await loadAnalytics()
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

    /// Converte i parametri Supabase in riga UI (copia JSON sicura, no riferimenti NSDictionary).
    private func displayRow(from params: [String: Any?]) throws -> [String: Any] {
        let data = try SupabaseJSONSanitizer.data(from: params)
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseError.apiError("Risposta gamification non valida")
        }
        return row
    }

    private func replaceRow(_ row: [String: Any], in rows: inout [[String: Any]]) {
        guard let id = row["id"] as? String else { return }
        if let index = rows.firstIndex(where: { $0["id"] as? String == id }) {
            rows[index] = row
        } else {
            rows.insert(row, at: 0)
        }
    }

    private func removeRow(id: String, from rows: inout [[String: Any]]) {
        rows.removeAll { $0["id"] as? String == id }
    }

    private func rowFor(table: String, id: String) -> [String: Any]? {
        switch table {
        case "badges": badges.first { $0["id"] as? String == id }
        case "species": species.first { $0["id"] as? String == id }
        case "gamification_levels": levels.first { $0["id"] as? String == id }
        case "gamification_rules": rules.first { $0["id"] as? String == id }
        case "gamification_campaigns": campaigns.first { $0["id"] as? String == id }
        default: nil
        }
    }

    private func replaceRowFor(table: String, row: [String: Any]) {
        switch table {
        case "badges": replaceRow(row, in: &badges)
        case "species": replaceRow(row, in: &species)
        case "gamification_levels": replaceRow(row, in: &levels)
        case "gamification_rules": replaceRow(row, in: &rules)
        case "gamification_campaigns": replaceRow(row, in: &campaigns)
        default: break
        }
    }

    private func removeRowFor(table: String, id: String) {
        switch table {
        case "badges": removeRow(id: id, from: &badges)
        case "species": removeRow(id: id, from: &species)
        case "gamification_levels": removeRow(id: id, from: &levels)
        case "gamification_rules": removeRow(id: id, from: &rules)
        case "gamification_campaigns": removeRow(id: id, from: &campaigns)
        default: break
        }
    }

    func saveBadge(_ draft: GamificationBadgeDraft, context: ModelContext) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let badge = try draft.persist(in: context)
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
            replaceRow(try displayRow(from: badge.toSupabaseParams()), in: &badges)
            isSaving = false
            return true
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
            isSaving = false
            return false
        }
    }

    func saveSpecies(_ draft: GamificationSpeciesDraft, context: ModelContext) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let speciesEntity = try draft.persist(in: context)
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
            replaceRow(try displayRow(from: speciesEntity.toSupabaseParams()), in: &species)
            isSaving = false
            return true
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
            isSaving = false
            return false
        }
    }

    func saveLevel(_ draft: GamificationLevelDraft, context: ModelContext) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let level = try draft.persist(in: context)
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
            replaceRow(try displayRow(from: level.toSupabaseParams()), in: &levels)
            isSaving = false
            return true
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
            isSaving = false
            return false
        }
    }

    func saveRule(_ draft: GamificationRuleDraft, context: ModelContext) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let rule = try draft.persist(in: context)
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
            replaceRow(try displayRow(from: rule.toSupabaseParams()), in: &rules)
            isSaving = false
            return true
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
            isSaving = false
            return false
        }
    }

    func saveCampaign(_ draft: GamificationCampaignDraft, context: ModelContext) async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            let campaign = try draft.persist(in: context)
            try context.save()
            try await syncManager.pushGamificationPendingChanges()
            replaceRow(try displayRow(from: campaign.toSupabaseParams()), in: &campaigns)
            isSaving = false
            return true
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
            isSaving = false
            return false
        }
    }

    func delete(table: String, id: String) async {
        isSaving = true
        errorMessage = nil
        do {
            try await client.delete(from: table, match: ["id": id])
            removeRowFor(table: table, id: id)
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
        }
        isSaving = false
    }

    func setActive(table: String, id: String, active: Bool, context: ModelContext) async {
        isSaving = true
        errorMessage = nil
        do {
            guard let uuid = UUID(uuidString: id) else {
                isSaving = false
                return
            }
            let patchedLocally = try patchLocalGamificationActive(table: table, id: uuid, active: active, context: context)
            if patchedLocally {
                try context.save()
                try await syncManager.pushGamificationPendingChanges()
            } else {
                try await client.patch(table: table, id: id, values: ["is_active": active])
            }
            guard var row = rowFor(table: table, id: id) else {
                isSaving = false
                return
            }
            row["is_active"] = active
            replaceRowFor(table: table, row: row)
        } catch {
            errorMessage = GamificationError.map(error).localizedDescription
        }
        isSaving = false
    }

    @discardableResult
    private func patchLocalGamificationActive(table: String, id: UUID, active: Bool, context: ModelContext) throws -> Bool {
        switch table {
        case "badges":
            let descriptor = FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.id == id })
            guard let item = try context.fetch(descriptor).first else { return false }
            item.isActive = active
            item.needsSync = true
            item.updatedAt = Date()
            return true
        case "species":
            let descriptor = FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.id == id })
            guard let item = try context.fetch(descriptor).first else { return false }
            item.isActive = active
            item.needsSync = true
            item.updatedAt = Date()
            return true
        case "gamification_levels":
            let descriptor = FetchDescriptor<GamificationLevel>(predicate: #Predicate { $0.id == id })
            guard let item = try context.fetch(descriptor).first else { return false }
            item.isActive = active
            item.needsSync = true
            item.updatedAt = Date()
            return true
        case "gamification_rules":
            let descriptor = FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.id == id })
            guard let item = try context.fetch(descriptor).first else { return false }
            item.isActive = active
            item.needsSync = true
            item.updatedAt = Date()
            return true
        case "gamification_campaigns":
            let descriptor = FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.id == id })
            guard let item = try context.fetch(descriptor).first else { return false }
            item.isActive = active
            item.needsSync = true
            item.updatedAt = Date()
            return true
        default:
            return false
        }
    }

    private func loadAnalytics() async throws -> GamificationAnalytics {
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

        let activeRuleCount = rules.filter { ($0["is_active"] as? Bool) ?? true }.count
        let activeCampaignCount = campaigns.filter { ($0["is_active"] as? Bool) ?? true }.count
        return GamificationAnalytics(
            metrics: [
                AnalyticsMetric(title: "Regole attive", value: "\(activeRuleCount)", icon: "slider.horizontal.3"),
                AnalyticsMetric(title: "Badge pubblicati", value: "\(badges.filter { ($0["is_active"] as? Bool) ?? true }.count)", icon: "rosette"),
                AnalyticsMetric(title: "Specie pubblicate", value: "\(species.filter { ($0["is_active"] as? Bool) ?? true }.count)", icon: "leaf.fill"),
                AnalyticsMetric(title: "Campagne attive", value: "\(activeCampaignCount)", icon: "calendar.badge.clock")
            ],
            badges: ranked(rows: badgeRows, key: "badge_id", titles: titleMap(rows: badges, titleKey: "title")),
            species: ranked(rows: speciesRows, key: "species_id", titles: titleMap(rows: species, titleKey: "name")),
            trails: ranked(rows: trailRows, key: "path_id", titles: Dictionary(paths.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })),
            events: ranked(rows: eventRows, key: "event_id", titles: Dictionary(events.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })),
            suspiciousLogs: logs
        )
    }

    private func reference(from row: [String: Any], titleKey: String) -> AdminReference? {
        guard let id = row["id"] as? String else { return nil }
        return AdminReference(id: id, title: row[titleKey] as? String ?? "Senza titolo")
    }

    private func titleMap(rows: [[String: Any]], titleKey: String) -> [String: String] {
        Dictionary(rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return (id, row[titleKey] as? String ?? "Senza titolo")
        }, uniquingKeysWith: { first, _ in first })
    }

    private func ranked(rows: [[String: Any]], key: String, titles: [String: String]) -> [AnalyticsRankRow] {
        let counts = rows.reduce(into: [String: Int]()) { partial, row in
            guard let id = row[key] as? String else { return }
            partial[id, default: 0] += 1
        }
        return counts
            .map { AnalyticsRankRow(id: $0.key, title: titles[$0.key] ?? "Elemento rimosso", count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
}

struct GamificationAdminView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = GamificationAdminViewModel()
    @State private var editor: AdminEditor?
    @State private var deleteTarget: (table: String, id: String, title: String)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Sezione", selection: $viewModel.selectedTab) {
                    ForEach(GamificationAdminTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                content
            }
            .navigationTitle("Gamification")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.selectedTab != .dashboard {
                        Button { editor = newEditor(for: viewModel.selectedTab) } label: {
                            Label("Nuovo", systemImage: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { @MainActor in await viewModel.loadAll(context: modelContext) } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Aggiorna")
                }
            }
            .task { await viewModel.loadAll(context: modelContext) }
            .sheet(item: $editor) { item in
                editorView(for: item)
            }
            .confirmationDialog(
                "Eliminare elemento?",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Elimina definitivamente", role: .destructive) {
                    guard let target = deleteTarget else { return }
                    Task { @MainActor in await viewModel.delete(table: target.table, id: target.id) }
                    deleteTarget = nil
                }
                Button("Annulla", role: .cancel) { deleteTarget = nil }
            } message: {
                Text(deleteTarget?.title ?? "")
            }
            .alert("Errore", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Caricamento...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.selectedTab == .dashboard {
            GamificationDashboardView(analytics: viewModel.analytics)
                .refreshable { await viewModel.loadAll(context: modelContext) }
        } else {
            List {
                Section {
                    ForEach(Array(viewModel.rowsForSelectedTab.enumerated()), id: \.offset) { _, row in
                        GamificationDefinitionRow(
                            tab: viewModel.selectedTab,
                            row: row,
                            onEdit: { editor = editEditor(for: viewModel.selectedTab, row: row) },
                            onDelete: {
                                guard let id = row["id"] as? String else { return }
                                deleteTarget = (tableName(for: viewModel.selectedTab), id, rowTitle(row))
                            },
                            onActiveChange: { active in
                                guard let id = row["id"] as? String else { return }
                                Task { @MainActor in
                                    await viewModel.setActive(
                                        table: tableName(for: viewModel.selectedTab),
                                        id: id,
                                        active: active,
                                        context: modelContext
                                    )
                                }
                            }
                        )
                    }
                } header: {
                    Text("\(viewModel.rowsForSelectedTab.count) elementi")
                } footer: {
                    Text("Le definizioni sono salvate nel backend, validate da RLS e scaricate dall'app visitatore per il funzionamento offline.")
                }
            }
            .refreshable { await viewModel.loadAll(context: modelContext) }
        }
    }

    @ViewBuilder
    private func editorView(for item: AdminEditor) -> some View {
        switch item {
        case .badge(let draft):
            BadgeEditorView(
                draft: draft,
                pois: viewModel.pois,
                paths: viewModel.paths,
                events: viewModel.events,
                species: viewModel.species.compactMap { reference(row: $0, titleKey: "name") },
                isSaving: viewModel.isSaving,
                onSave: { draft in await viewModel.saveBadge(draft, context: modelContext) }
            )
        case .species(let draft):
            SpeciesEditorView(
                draft: draft,
                pois: viewModel.pois,
                paths: viewModel.paths,
                isSaving: viewModel.isSaving,
                onSave: { draft in await viewModel.saveSpecies(draft, context: modelContext) }
            )
        case .level(let draft):
            LevelEditorView(
                draft: draft,
                isSaving: viewModel.isSaving,
                onSave: { draft in await viewModel.saveLevel(draft, context: modelContext) }
            )
        case .rule(let draft):
            RuleEditorView(
                draft: draft,
                badges: viewModel.badges.compactMap { reference(row: $0, titleKey: "title") },
                species: viewModel.species.compactMap { reference(row: $0, titleKey: "name") },
                pois: viewModel.pois,
                paths: viewModel.paths,
                events: viewModel.events,
                isSaving: viewModel.isSaving,
                onSave: { draft in await viewModel.saveRule(draft, context: modelContext) }
            )
        case .campaign(let draft):
            CampaignEditorView(
                draft: draft,
                rules: viewModel.rules.compactMap { reference(row: $0, titleKey: "title") },
                isSaving: viewModel.isSaving,
                onSave: { draft in await viewModel.saveCampaign(draft, context: modelContext) }
            )
        }
    }

    private func newEditor(for tab: GamificationAdminTab) -> AdminEditor? {
        switch tab {
        case .dashboard: nil
        case .badges: .badge(GamificationBadgeDraft())
        case .species: .species(GamificationSpeciesDraft())
        case .levels: .level(GamificationLevelDraft(nextNumber: (viewModel.levels.compactMap { $0["level_number"] as? Int }.max() ?? 0) + 1))
        case .rules: .rule(GamificationRuleDraft())
        case .campaigns: .campaign(GamificationCampaignDraft())
        }
    }

    private func editEditor(for tab: GamificationAdminTab, row: [String: Any]) -> AdminEditor? {
        switch tab {
        case .dashboard: nil
        case .badges: .badge(GamificationBadgeDraft(row: row))
        case .species: .species(GamificationSpeciesDraft(row: row))
        case .levels: .level(GamificationLevelDraft(row: row))
        case .rules: .rule(GamificationRuleDraft(row: row))
        case .campaigns: .campaign(GamificationCampaignDraft(row: row))
        }
    }
}

private struct GamificationDashboardView: View {
    let analytics: GamificationAnalytics

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                ForEach(analytics.metrics) { metric in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: metric.icon)
                            .font(.title2)
                            .foregroundColor(Color("WWFGreen"))
                        Text(metric.value)
                            .font(.largeTitle.bold())
                        Text(metric.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
            }
            .padding()

            VStack(spacing: 14) {
                rankingSection("Badge piu sbloccati", rows: analytics.badges, icon: "rosette")
                rankingSection("Specie piu scoperte", rows: analytics.species, icon: "leaf.fill")
                rankingSection("Percorsi piu completati", rows: analytics.trails, icon: "figure.hiking")
                rankingSection("Eventi completati", rows: analytics.events, icon: "calendar.badge.checkmark")
                suspiciousSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func rankingSection(_ title: String, rows: [AnalyticsRankRow], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            if rows.isEmpty {
                Text("Nessun dato disponibile.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text("\(row.count)")
                            .font(.headline)
                            .foregroundColor(Color("WWFGreen"))
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var suspiciousSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Log sospetti recenti", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            if analytics.suspiciousLogs.isEmpty {
                Text("Nessun log warning o rejected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(analytics.suspiciousLogs.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row["event_type"] as? String ?? "Evento")
                            .font(.subheadline.weight(.semibold))
                        Text(row["reason"] as? String ?? row["status"] as? String ?? "Controllo automatico")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct GamificationDefinitionRow: View {
    let tab: GamificationAdminTab
    let row: [String: Any]
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onActiveChange: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tab.icon)
                .foregroundColor(Color("WWFGreen"))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(rowTitle(row))
                        .font(.headline)
                    if !(row["is_active"] as? Bool ?? true) {
                        Text("Inattivo")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                Text(rowSubtitle(row, tab: tab))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                Text(rowDetail(row, tab: tab))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("Attivo", isOn: Binding(
                get: { row["is_active"] as? Bool ?? true },
                set: onActiveChange
            ))
            .labelsHidden()
            Menu {
                Button("Modifica", systemImage: "pencil", action: onEdit)
                Button("Elimina", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Azioni")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

private struct BadgeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GamificationBadgeDraft
    let pois: [AdminReference]
    let paths: [AdminReference]
    let events: [AdminReference]
    let species: [AdminReference]
    let isSaving: Bool
    let onSave: (GamificationBadgeDraft) async -> Bool

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    init(
        draft: GamificationBadgeDraft,
        pois: [AdminReference],
        paths: [AdminReference],
        events: [AdminReference],
        species: [AdminReference],
        isSaving: Bool,
        onSave: @escaping (GamificationBadgeDraft) async -> Bool
    ) {
        _draft = State(initialValue: draft)
        self.pois = pois
        self.paths = paths
        self.events = events
        self.species = species
        self.isSaving = isSaving
        self.onSave = onSave
    }

    var body: some View {
        DefinitionEditorScaffold(
            title: draft.isNew ? "Nuovo badge" : "Modifica badge",
            canSave: draft.isValid,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Informazioni") {
                TextField("Titolo", text: $draft.title)
                TextField("Descrizione", text: $draft.description, axis: .vertical)
                    .lineLimit(3...6)
                Picker("Categoria", selection: $draft.category) {
                    ForEach(BadgeCategory.allCases) { Text($0.title).tag($0) }
                }
                Picker("Rarita", selection: $draft.rarity) {
                    ForEach(GamificationRarity.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Badge segreto", isOn: $draft.isHidden)
                Toggle("Attivo", isOn: $draft.isActive)
                Stepper("Ordine: \(draft.sortOrder)", value: $draft.sortOrder, in: 0...999)
            }
            imageSection(imageURL: $draft.imageURL, imageData: $draft.imageData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Ricompensa") {
                Stepper("XP extra: \(draft.xpReward)", value: $draft.xpReward, in: 0...5000, step: 5)
                TextField("Indizio di sblocco", text: $draft.unlockHint, axis: .vertical)
                    .lineLimit(2...4)
            }
            relationSection(title: "Collegamenti", draft: $draft, pois: pois, paths: paths, events: events, species: species)
            criteriaSection(title: "Criteri badge", conditionType: $draft.criteriaCondition, conditionValue: $draft.criteriaValue, selectedPOI: $draft.relatedPOIId, selectedPath: $draft.relatedPathId, selectedEvent: $draft.relatedEventId, pois: pois, paths: paths, events: events)
            BadgePreviewCard(title: draft.title, description: draft.description, category: draft.category.title, rarity: draft.rarity.title, imageData: previewData, imageURL: draft.imageURL, isHidden: draft.isHidden)
        }
    }

    private func save() {
        Task { @MainActor in
            if await onSave(draft) { dismiss() }
        }
    }
}

private struct SpeciesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GamificationSpeciesDraft
    let pois: [AdminReference]
    let paths: [AdminReference]
    let isSaving: Bool
    let onSave: (GamificationSpeciesDraft) async -> Bool

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    init(
        draft: GamificationSpeciesDraft,
        pois: [AdminReference],
        paths: [AdminReference],
        isSaving: Bool,
        onSave: @escaping (GamificationSpeciesDraft) async -> Bool
    ) {
        _draft = State(initialValue: draft)
        self.pois = pois
        self.paths = paths
        self.isSaving = isSaving
        self.onSave = onSave
    }

    var body: some View {
        DefinitionEditorScaffold(
            title: draft.isNew ? "Nuova specie" : "Modifica specie",
            canSave: draft.isValid,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Informazioni") {
                TextField("Nome", text: $draft.name)
                TextField("Nome scientifico", text: $draft.scientificName)
                Picker("Categoria", selection: $draft.category) {
                    ForEach(SpeciesCategory.allCases) { Text($0.title).tag($0) }
                }
                Picker("Rarita", selection: $draft.rarity) {
                    ForEach(GamificationRarity.allCases) { Text($0.title).tag($0) }
                }
                TextField("Habitat", text: $draft.habitat)
                Toggle("Attiva", isOn: $draft.isActive)
            }
            Section("Testi visitatore") {
                TextField("Descrizione", text: $draft.description, axis: .vertical)
                    .lineLimit(4...8)
                TextField("Descrizione Kids", text: $draft.descriptionKids, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Descrizione Easy Read", text: $draft.descriptionEasyRead, axis: .vertical)
                    .lineLimit(3...6)
            }
            imageSection(imageURL: $draft.imageURL, imageData: $draft.imageData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Collegamenti e sblocco") {
                ReferencePicker(title: "POI collegato", selection: $draft.relatedPOIId, options: pois)
                ReferencePicker(title: "Percorso collegato", selection: $draft.relatedPathId, options: paths)
                criteriaSection(title: "Criteri sblocco", conditionType: $draft.unlockCondition, conditionValue: $draft.unlockValue, selectedPOI: $draft.relatedPOIId, selectedPath: $draft.relatedPathId, selectedEvent: .constant(nil), pois: pois, paths: paths, events: [])
            }
            SpeciesPreviewCard(draft: draft, imageData: previewData)
        }
    }

    private func save() {
        Task { @MainActor in
            if await onSave(draft) { dismiss() }
        }
    }
}

private struct LevelEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GamificationLevelDraft
    let isSaving: Bool
    let onSave: (GamificationLevelDraft) async -> Bool

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    init(draft: GamificationLevelDraft, isSaving: Bool, onSave: @escaping (GamificationLevelDraft) async -> Bool) {
        _draft = State(initialValue: draft)
        self.isSaving = isSaving
        self.onSave = onSave
    }

    var body: some View {
        DefinitionEditorScaffold(
            title: draft.isNew ? "Nuovo livello" : "Modifica livello",
            canSave: draft.isValid,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Livello") {
                Stepper("Numero livello: \(draft.levelNumber)", value: $draft.levelNumber, in: 1...99)
                TextField("Titolo narrativo", text: $draft.title)
                TextField("Descrizione", text: $draft.description, axis: .vertical)
                    .lineLimit(2...5)
                Stepper("XP richiesti: \(draft.requiredXP)", value: $draft.requiredXP, in: 0...100000, step: 25)
                Picker("Icona", selection: $draft.iconName) {
                    Label("Sigillo", systemImage: "seal.fill").tag("seal.fill")
                    Label("Stella", systemImage: "star.fill").tag("star.fill")
                    Label("Foglia", systemImage: "leaf.fill").tag("leaf.fill")
                    Label("Medaglia", systemImage: "medal.fill").tag("medal.fill")
                }
                Toggle("Attivo", isOn: $draft.isActive)
            }
            imageSection(imageURL: $draft.imageURL, imageData: $draft.imageData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Preview") {
                HStack(spacing: 14) {
                    Image(systemName: draft.iconName.isEmpty ? "seal.fill" : draft.iconName)
                        .font(.largeTitle)
                        .foregroundColor(Color("WWFGreen"))
                    VStack(alignment: .leading) {
                        Text("Livello \(draft.levelNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(draft.title.isEmpty ? "Titolo livello" : draft.title)
                            .font(.headline)
                        Text("\(draft.requiredXP) XP")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func save() {
        Task { @MainActor in
            if await onSave(draft) { dismiss() }
        }
    }
}

private struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GamificationRuleDraft
    let badges: [AdminReference]
    let species: [AdminReference]
    let pois: [AdminReference]
    let paths: [AdminReference]
    let events: [AdminReference]
    let isSaving: Bool
    let onSave: (GamificationRuleDraft) async -> Bool

    init(
        draft: GamificationRuleDraft,
        badges: [AdminReference],
        species: [AdminReference],
        pois: [AdminReference],
        paths: [AdminReference],
        events: [AdminReference],
        isSaving: Bool,
        onSave: @escaping (GamificationRuleDraft) async -> Bool
    ) {
        _draft = State(initialValue: draft)
        self.badges = badges
        self.species = species
        self.pois = pois
        self.paths = paths
        self.events = events
        self.isSaving = isSaving
        self.onSave = onSave
    }

    var body: some View {
        DefinitionEditorScaffold(
            title: draft.isNew ? "Nuova regola" : "Modifica regola",
            canSave: draft.isValid,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Descrizione regola") {
                TextField("Titolo", text: $draft.title)
                TextField("Descrizione", text: $draft.description, axis: .vertical)
                    .lineLimit(2...5)
                Toggle("Attiva", isOn: $draft.isActive)
                Toggle("Nascosta", isOn: $draft.isHidden)
                Toggle("Ripetibile", isOn: $draft.isRepeatable)
                Picker("Pubblico", selection: $draft.audience) {
                    ForEach(GamificationAudience.allCases) { Text($0.title).tag($0) }
                }
                Stepper("Priorita: \(draft.priority)", value: $draft.priority, in: -100...100)
            }
            Section("Quando succede") {
                Picker("Trigger", selection: $draft.triggerType) {
                    ForEach(RuleTriggerType.allCases) { Text($0.title).tag($0) }
                }
                Picker("Condizione", selection: $draft.conditionType) {
                    ForEach(RuleConditionType.allCases) { Text($0.title).tag($0) }
                }
                conditionFields
            }
            Section("Premio") {
                Stepper("XP: \(draft.xpReward)", value: $draft.xpReward, in: 0...10000, step: 5)
                ReferencePicker(title: "Badge premio", selection: $draft.rewardBadgeId, options: badges)
                ReferencePicker(title: "Specie premio", selection: $draft.rewardSpeciesId, options: species)
                TextField("Titolo profilo", text: $draft.profileTitle)
                TextField("Oggetto collezione", text: $draft.collectionItemKey)
                Toggle("Solo controllo livello", isOn: $draft.levelCheckOnly)
            }
            Section("Finestra e cooldown") {
                Toggle("Usa date attive", isOn: $draft.hasDateRange)
                if draft.hasDateRange {
                    DatePicker("Inizio", selection: $draft.startsAt)
                    DatePicker("Fine", selection: $draft.endsAt)
                }
                Toggle("Usa cooldown", isOn: $draft.hasCooldown)
                if draft.hasCooldown {
                    Stepper("Cooldown: \(draft.cooldownSeconds) sec", value: $draft.cooldownSeconds, in: 0...604800, step: 300)
                }
            }
            Section("Preview copy") {
                Label(rulePreview, systemImage: "sparkles")
                    .font(.subheadline)
                Text("Kids: \(kidsPreview)")
                    .font(.caption)
                Text("Easy Read: \(easyReadPreview)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var conditionFields: some View {
        switch draft.conditionType {
        case .none:
            Text("La regola si applica a ogni evento di questo trigger.")
                .font(.caption)
                .foregroundColor(.secondary)
        case .poiCountTotalGTE:
            Stepper("Almeno \(draft.conditionCount) POI", value: $draft.conditionCount, in: 1...500)
        case .path:
            ReferencePicker(title: "Percorso", selection: $draft.conditionPathId, options: paths)
        case .poi:
            ReferencePicker(title: "POI", selection: $draft.conditionPOIId, options: pois)
        case .event:
            ReferencePicker(title: "Evento", selection: $draft.conditionEventId, options: events)
        case .species:
            ReferencePicker(title: "Specie", selection: $draft.conditionSpeciesId, options: species)
        case .completionPercent:
            ReferencePicker(title: "Percorso", selection: $draft.conditionPathId, options: paths)
            Stepper("Completamento: \(draft.requiredCompletionPercent)%", value: $draft.requiredCompletionPercent, in: 1...100)
            Stepper("Durata minima: \(draft.minimumDurationMinutes) min", value: $draft.minimumDurationMinutes, in: 0...240)
            Toggle("Richiedi ordine scansioni", isOn: $draft.requireOrderedScans)
        case .audioPercent:
            Stepper("Ascolto minimo: \(draft.audioPercent)%", value: $draft.audioPercent, in: 1...100)
            ReferencePicker(title: "POI opzionale", selection: $draft.conditionPOIId, options: pois)
        }
    }

    private var rulePreview: String {
        if draft.title.isEmpty { return "Quando \(draft.triggerType.title.lowercased()), assegna il premio configurato." }
        return draft.title
    }

    private var kidsPreview: String {
        "Hai trovato qualcosa di speciale: \(draft.rewardSummary)."
    }

    private var easyReadPreview: String {
        "Completa l'attivita. Ricevi: \(draft.rewardSummary)."
    }

    private func save() {
        Task { @MainActor in
            if await onSave(draft) { dismiss() }
        }
    }
}

private struct CampaignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GamificationCampaignDraft
    let rules: [AdminReference]
    let isSaving: Bool
    let onSave: (GamificationCampaignDraft) async -> Bool

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    init(
        draft: GamificationCampaignDraft,
        rules: [AdminReference],
        isSaving: Bool,
        onSave: @escaping (GamificationCampaignDraft) async -> Bool
    ) {
        _draft = State(initialValue: draft)
        self.rules = rules
        self.isSaving = isSaving
        self.onSave = onSave
    }

    var body: some View {
        DefinitionEditorScaffold(
            title: draft.isNew ? "Nuova campagna" : "Modifica campagna",
            canSave: draft.isValid,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Campagna") {
                TextField("Titolo", text: $draft.title)
                TextField("Descrizione", text: $draft.description, axis: .vertical)
                    .lineLimit(3...6)
                DatePicker("Inizio", selection: $draft.startsAt)
                DatePicker("Fine", selection: $draft.endsAt)
                Toggle("Attiva", isOn: $draft.isActive)
            }
            imageSection(imageURL: $draft.imageURL, imageData: $draft.imageData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Regole incluse") {
                if rules.isEmpty {
                    Text("Crea prima almeno una regola.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(rules) { rule in
                        Toggle(rule.title, isOn: Binding(
                            get: { draft.ruleIds.contains(rule.id) },
                            set: { selected in
                                if selected {
                                    draft.ruleIds.insert(rule.id)
                                } else {
                                    draft.ruleIds.remove(rule.id)
                                }
                            }
                        ))
                    }
                }
            }
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.title.isEmpty ? "Titolo campagna" : draft.title)
                        .font(.headline)
                    Text(draft.description.isEmpty ? "Descrizione campagna" : draft.description)
                        .font(.caption)
                    Text("\(draft.ruleIds.count) regole collegate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func save() {
        Task { @MainActor in
            if await onSave(draft) { dismiss() }
        }
    }
}

private struct DefinitionEditorScaffold<Content: View>: View {
    let title: String
    let canSave: Bool
    let isSaving: Bool
    let onSave: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form { content }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Salvataggio..." : "Salva", action: onSave)
                            .fontWeight(.semibold)
                            .disabled(!canSave || isSaving)
                    }
                }
        }
    }
}

private struct ReferencePicker: View {
    let title: String
    @Binding var selection: String?
    let options: [AdminReference]

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Nessuno").tag(String?.none)
            ForEach(options) { option in
                Text(option.title).tag(Optional(option.id))
            }
        }
        .pickerStyle(.menu)
    }
}

private struct BadgePreviewCard: View {
    let title: String
    let description: String
    let category: String
    let rarity: String
    let imageData: Data?
    let imageURL: String
    let isHidden: Bool

    var body: some View {
        Section("Preview badge") {
            HStack(spacing: 14) {
                previewImage
                VStack(alignment: .leading, spacing: 5) {
                    Text(isHidden ? "Badge segreto" : (title.isEmpty ? "Titolo badge" : title))
                        .font(.headline)
                    Text(isHidden ? "Sbloccalo esplorando l'oasi." : (description.isEmpty ? "Descrizione badge" : description))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(category) - \(rarity)")
                        .font(.caption2)
                        .foregroundColor(Color("WWFGreen"))
                }
            }
            Text("Kids: Che scoperta! Hai trovato un nuovo badge.")
                .font(.caption)
            Text("Easy Read: Hai ricevuto un badge.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: isHidden ? "questionmark.circle.fill" : "rosette")
                .font(.largeTitle)
                .foregroundColor(Color("WWFGreen"))
                .frame(width: 64, height: 64)
                .background(Color("WWFGreen").opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct SpeciesPreviewCard: View {
    let draft: GamificationSpeciesDraft
    let imageData: Data?

    var body: some View {
        Section("Preview album") {
            HStack(spacing: 14) {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color("WWFGreen"))
                        .frame(width: 72, height: 72)
                        .background(Color("WWFGreen").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.name.isEmpty ? "Nome specie" : draft.name)
                        .font(.headline)
                    if !draft.scientificName.isEmpty {
                        Text(draft.scientificName)
                            .font(.caption.italic())
                            .foregroundColor(.secondary)
                    }
                    Text("\(draft.category.title) - \(draft.rarity.title)")
                        .font(.caption2)
                        .foregroundColor(Color("WWFGreen"))
                }
            }
            Text("Kids: Nuova pagina dell'album natura.")
                .font(.caption)
            Text("Easy Read: Hai scoperto una specie.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@ViewBuilder
private func imageSection(
    imageURL: Binding<String>,
    imageData: Binding<Data?>,
    selectedImage: Binding<PhotosPickerItem?>,
    previewData: Binding<Data?>
) -> some View {
    Section("Immagine") {
        PhotosPicker(selection: selectedImage, matching: .images) {
            Label(imageURL.wrappedValue.isEmpty ? "Carica immagine" : "Cambia immagine", systemImage: "photo.badge.plus")
                .foregroundColor(Color("WWFGreen"))
        }
        .onChange(of: selectedImage.wrappedValue) { _, item in
            Task { @MainActor in
                guard let item else { return }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                        print("[Gamification] Immagine selezionata vuota o non caricabile")
                        return
                    }
                    guard let image = UIImage(data: data) else {
                        print("[Gamification] Dati immagine corrotti, impossibile creare UIImage")
                        return
                    }
                    guard let normalizedData = image.jpegData(compressionQuality: 0.85),
                          !normalizedData.isEmpty else {
                        print("[Gamification] Conversione JPEG fallita")
                        return
                    }
                    previewData.wrappedValue = normalizedData
                    imageData.wrappedValue = normalizedData
                    imageURL.wrappedValue = ""
                } catch {
                    print("[Gamification] Errore nel caricamento dell'immagine: \(error)")
                }
            }
        }
        if let data = previewData.wrappedValue, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if !imageURL.wrappedValue.isEmpty {
            Label("Immagine remota configurata", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(Color("WWFGreen"))
        }
    }
}

@ViewBuilder
private func relationSection(
    title: String,
    draft: Binding<GamificationBadgeDraft>,
    pois: [AdminReference],
    paths: [AdminReference],
    events: [AdminReference],
    species: [AdminReference]
) -> some View {
    Section(title) {
        ReferencePicker(title: "POI collegato", selection: draft.relatedPOIId, options: pois)
        ReferencePicker(title: "Percorso collegato", selection: draft.relatedPathId, options: paths)
        ReferencePicker(title: "Evento collegato", selection: draft.relatedEventId, options: events)
        ReferencePicker(title: "Specie collegata", selection: draft.relatedSpeciesId, options: species)
    }
}

@ViewBuilder
private func criteriaSection(
    title: String,
    conditionType: Binding<RuleConditionType>,
    conditionValue: Binding<Int>,
    selectedPOI: Binding<String?>,
    selectedPath: Binding<String?>,
    selectedEvent: Binding<String?>,
    pois: [AdminReference],
    paths: [AdminReference],
    events: [AdminReference]
) -> some View {
    Section(title) {
        Picker("Tipo criterio", selection: conditionType) {
            ForEach(RuleConditionType.allCases) { Text($0.title).tag($0) }
        }
        switch conditionType.wrappedValue {
        case .none:
            Text("Nessun criterio aggiuntivo.")
                .font(.caption)
                .foregroundColor(.secondary)
        case .poiCountTotalGTE:
            Stepper("Almeno \(conditionValue.wrappedValue) POI", value: conditionValue, in: 1...500)
        case .path, .completionPercent:
            ReferencePicker(title: "Percorso", selection: selectedPath, options: paths)
        case .poi, .audioPercent:
            ReferencePicker(title: "POI", selection: selectedPOI, options: pois)
        case .event:
            ReferencePicker(title: "Evento", selection: selectedEvent, options: events)
        case .species:
            Text("Usa una regola per collegare criteri specie specifici.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct GamificationBadgeDraft {
    var id = GamificationID.make()
    var isNew = true
    var title = ""
    var description = ""
    var imageURL = ""
    var imageData: Data?
    var category: BadgeCategory = .exploration
    var rarity: GamificationRarity = .common
    var isHidden = false
    var unlockHint = ""
    var sortOrder = 0
    var xpReward = 0
    var relatedPOIId: String?
    var relatedPathId: String?
    var relatedEventId: String?
    var relatedSpeciesId: String?
    var criteriaCondition: RuleConditionType = .none
    var criteriaValue = 1
    var isActive = true

    init() {}

    init(row: [String: Any]) {
        id = GamificationID.fromRow(row)
        isNew = false
        title = row["title"] as? String ?? ""
        description = row["description"] as? String ?? ""
        imageURL = row["image_url"] as? String ?? ""
        category = BadgeCategory(rawValue: row["category"] as? String ?? "") ?? .exploration
        rarity = GamificationRarity(rawValue: row["rarity"] as? String ?? "") ?? .common
        isHidden = row["is_hidden"] as? Bool ?? false
        unlockHint = row["unlock_hint"] as? String ?? ""
        sortOrder = row["sort_order"] as? Int ?? 0
        xpReward = row["xp_reward"] as? Int ?? 0
        relatedPathId = row["related_path_id"] as? String
        relatedPOIId = row["related_poi_id"] as? String
        relatedEventId = row["related_event_id"] as? String
        relatedSpeciesId = row["related_species_id"] as? String
        let parsed = conditionDraft(from: row["criteria"] as? [String: Any] ?? [:], fallbackPOIId: relatedPOIId, fallbackPathId: relatedPathId, fallbackEventId: relatedEventId)
        criteriaCondition = parsed.type
        criteriaValue = parsed.count
        relatedPOIId = parsed.poiId
        relatedPathId = parsed.pathId
        relatedEventId = parsed.eventId
        isActive = row["is_active"] as? Bool ?? true
    }

    var isValid: Bool {
        !title.trimmed.isEmpty &&
        !description.trimmed.isEmpty &&
        xpReward >= 0
    }

    func values() -> [String: Any?] {
        [
            "title": title.trimmed,
            "description": description.trimmed,
            "image_url": imageURL.trimmed,
            "category": category.rawValue,
            "criteria": criteriaObject,
            "is_active": isActive,
            "rarity": rarity.rawValue,
            "is_hidden": isHidden,
            "unlock_hint": unlockHint.trimmed.nilIfEmpty,
            "sort_order": sortOrder,
            "xp_reward": xpReward,
            "related_poi_id": relatedPOIId,
            "related_path_id": relatedPathId,
            "related_event_id": relatedEventId,
            "related_species_id": relatedSpeciesId
        ]
    }

    private var criteriaObject: [String: Any] {
        return conditionJSON(type: criteriaCondition, count: criteriaValue, poiId: relatedPOIId, pathId: relatedPathId, eventId: relatedEventId)
    }
}

private struct GamificationSpeciesDraft {
    var id = GamificationID.make()
    var isNew = true
    var name = ""
    var scientificName = ""
    var description = ""
    var descriptionKids = ""
    var descriptionEasyRead = ""
    var category: SpeciesCategory = .fauna
    var rarity: GamificationRarity = .common
    var habitat = ""
    var imageURL = ""
    var imageData: Data?
    var iconName = "leaf.fill"
    var relatedPOIId: String?
    var relatedPathId: String?
    var unlockCondition: RuleConditionType = .none
    var unlockValue = 1
    var isActive = true

    init() {}

    init(row: [String: Any]) {
        id = GamificationID.fromRow(row)
        isNew = false
        name = row["name"] as? String ?? ""
        scientificName = row["scientific_name"] as? String ?? ""
        description = row["description"] as? String ?? ""
        descriptionKids = row["description_kids"] as? String ?? ""
        descriptionEasyRead = row["description_easy_read"] as? String ?? ""
        category = SpeciesCategory(rawValue: row["category"] as? String ?? "") ?? .fauna
        rarity = GamificationRarity(rawValue: row["rarity"] as? String ?? "") ?? .common
        habitat = row["habitat"] as? String ?? ""
        imageURL = row["image_url"] as? String ?? ""
        iconName = row["icon_name"] as? String ?? "leaf.fill"
        relatedPOIId = row["related_poi_id"] as? String
        relatedPathId = row["related_path_id"] as? String
        let parsed = conditionDraft(from: row["unlock_criteria_json"] as? [String: Any] ?? [:], fallbackPOIId: relatedPOIId, fallbackPathId: relatedPathId, fallbackEventId: nil)
        unlockCondition = parsed.type
        unlockValue = parsed.count
        relatedPOIId = parsed.poiId
        relatedPathId = parsed.pathId
        isActive = row["is_active"] as? Bool ?? true
    }

    var isValid: Bool {
        !name.trimmed.isEmpty &&
        !description.trimmed.isEmpty
    }

    func values() -> [String: Any?] {
        [
            "name": name.trimmed,
            "scientific_name": scientificName.trimmed.nilIfEmpty,
            "description": description.trimmed,
            "description_kids": descriptionKids.trimmed.nilIfEmpty,
            "description_easy_read": descriptionEasyRead.trimmed.nilIfEmpty,
            "category": category.rawValue,
            "rarity": rarity.rawValue,
            "habitat": habitat.trimmed.nilIfEmpty,
            "image_url": imageURL.trimmed.nilIfEmpty,
            "icon_name": iconName.trimmed.nilIfEmpty,
            "related_poi_id": relatedPOIId,
            "related_path_id": relatedPathId,
            "unlock_criteria_json": unlockCriteriaObject,
            "is_active": isActive
        ]
    }

    private var unlockCriteriaObject: [String: Any]? {
        let object = conditionJSON(type: unlockCondition, count: unlockValue, poiId: relatedPOIId, pathId: relatedPathId, eventId: nil)
        return object.isEmpty ? nil : object
    }
}

private struct GamificationLevelDraft {
    var id = GamificationID.make()
    var isNew = true
    var levelNumber = 1
    var title = ""
    var description = ""
    var requiredXP = 0
    var iconName = "seal.fill"
    var imageURL = ""
    var imageData: Data?
    var isActive = true

    init(nextNumber: Int) {
        levelNumber = nextNumber
    }

    init(row: [String: Any]) {
        id = GamificationID.fromRow(row)
        isNew = false
        levelNumber = row["level_number"] as? Int ?? 1
        title = row["title"] as? String ?? ""
        description = row["description"] as? String ?? ""
        requiredXP = row["required_xp"] as? Int ?? 0
        iconName = row["icon_name"] as? String ?? "seal.fill"
        imageURL = row["image_url"] as? String ?? ""
        isActive = row["is_active"] as? Bool ?? true
    }

    var isValid: Bool {
        levelNumber > 0 && !title.trimmed.isEmpty && requiredXP >= 0
    }

    func values() -> [String: Any?] {
        [
            "level_number": levelNumber,
            "title": title.trimmed,
            "description": description.trimmed.nilIfEmpty,
            "required_xp": requiredXP,
            "icon_name": iconName.trimmed.nilIfEmpty,
            "image_url": imageURL.trimmed.nilIfEmpty,
            "is_active": isActive
        ]
    }
}

private struct GamificationRuleDraft {
    var id = GamificationID.make()
    var isNew = true
    var title = ""
    var description = ""
    var triggerType: RuleTriggerType = .poiScanned
    var conditionType: RuleConditionType = .none
    var conditionCount = 5
    var conditionPOIId: String?
    var conditionPathId: String?
    var conditionEventId: String?
    var conditionSpeciesId: String?
    var requiredCompletionPercent = 100
    var minimumDurationMinutes = 0
    var requireOrderedScans = false
    var audioPercent = 80
    var xpReward = 25
    var rewardBadgeId: String?
    var rewardSpeciesId: String?
    var profileTitle = ""
    var collectionItemKey = ""
    var levelCheckOnly = false
    var audience: GamificationAudience = .all
    var isHidden = false
    var isRepeatable = false
    var hasCooldown = false
    var cooldownSeconds = 86400
    var hasDateRange = false
    var startsAt = Date()
    var endsAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    var priority = 0
    var isActive = true

    init() {}

    init(row: [String: Any]) {
        id = GamificationID.fromRow(row)
        isNew = false
        title = row["title"] as? String ?? ""
        description = row["description"] as? String ?? ""
        triggerType = RuleTriggerType(rawValue: row["trigger_type"] as? String ?? "") ?? .poiScanned
        audience = GamificationAudience(rawValue: row["audience"] as? String ?? "") ?? .all
        isHidden = row["is_hidden"] as? Bool ?? false
        isRepeatable = row["is_repeatable"] as? Bool ?? false
        if let cooldown = row["cooldown_seconds"] as? Int {
            hasCooldown = true
            cooldownSeconds = cooldown
        }
        if let start = dateFromSupabase(row["starts_at"]) {
            hasDateRange = true
            startsAt = start
        }
        if let end = dateFromSupabase(row["ends_at"]) {
            hasDateRange = true
            endsAt = end
        }
        priority = row["priority"] as? Int ?? 0
        isActive = row["is_active"] as? Bool ?? true
        applyConditions(row["conditions"] as? [String: Any] ?? row["conditions_json"] as? [String: Any] ?? [:])
        applyReward(row["reward"] as? [String: Any] ?? row["reward_json"] as? [String: Any] ?? [:])
    }

    var conditionsObject: [String: Any] {
        var object = conditionJSON(type: conditionType, count: conditionCount, poiId: conditionPOIId, pathId: conditionPathId, eventId: conditionEventId)
        if let conditionSpeciesId, conditionType == .species { object["species_id"] = conditionSpeciesId }
        if conditionType == .completionPercent {
            object["required_completion_percent"] = requiredCompletionPercent
            if minimumDurationMinutes > 0 { object["minimum_duration_minutes"] = minimumDurationMinutes }
            object["require_ordered_scans"] = requireOrderedScans
        }
        if conditionType == .audioPercent {
            object["listened_percent_gte"] = audioPercent
        }
        return object
    }

    var rewardObject: [String: Any] {
        var object: [String: Any] = [:]
        if xpReward > 0 { object["xp"] = xpReward }
        if let rewardBadgeId { object["badge_id"] = rewardBadgeId }
        if let rewardSpeciesId { object["species_id"] = rewardSpeciesId }
        if !profileTitle.trimmed.isEmpty { object["profile_title"] = profileTitle.trimmed }
        if !collectionItemKey.trimmed.isEmpty { object["collection_item"] = collectionItemKey.trimmed }
        if levelCheckOnly { object["level_check"] = true }
        return object
    }

    var rewardSummary: String {
        var parts: [String] = []
        if xpReward > 0 { parts.append("\(xpReward) XP") }
        if rewardBadgeId != nil { parts.append("badge") }
        if rewardSpeciesId != nil { parts.append("specie") }
        if !profileTitle.trimmed.isEmpty { parts.append("titolo profilo") }
        if !collectionItemKey.trimmed.isEmpty { parts.append("oggetto collezione") }
        if levelCheckOnly { parts.append("controllo livello") }
        return parts.isEmpty ? "premio configurato" : parts.joined(separator: ", ")
    }

    var isValid: Bool {
        !title.trimmed.isEmpty &&
        startsAt <= endsAt &&
        !rewardObject.isEmpty
    }

    func values() -> [String: Any?] {
        [
            "title": title.trimmed,
            "description": description.trimmed.nilIfEmpty,
            "trigger_type": triggerType.rawValue,
            "conditions": conditionsObject,
            "reward": rewardObject,
            "audience": audience.rawValue,
            "is_hidden": isHidden,
            "is_repeatable": isRepeatable,
            "cooldown_seconds": hasCooldown ? cooldownSeconds : nil,
            "starts_at": hasDateRange ? isoString(startsAt) : nil,
            "ends_at": hasDateRange ? isoString(endsAt) : nil,
            "priority": priority,
            "is_active": isActive
        ]
    }

    mutating private func applyConditions(_ object: [String: Any]) {
        let parsed = conditionDraft(from: object, fallbackPOIId: conditionPOIId, fallbackPathId: conditionPathId, fallbackEventId: conditionEventId)
        conditionType = parsed.type
        conditionCount = parsed.count
        conditionPOIId = parsed.poiId
        conditionPathId = parsed.pathId
        conditionEventId = parsed.eventId
        if let speciesId = object["species_id"] as? String {
            conditionType = .species
            conditionSpeciesId = speciesId
        }
        if let completion = intValue(object["required_completion_percent"]) {
            conditionType = .completionPercent
            requiredCompletionPercent = completion
        }
        if let duration = intValue(object["minimum_duration_minutes"]) {
            minimumDurationMinutes = duration
        }
        if let ordered = object["require_ordered_scans"] as? Bool {
            requireOrderedScans = ordered
        }
        if let audio = intValue(object["listened_percent_gte"]) {
            conditionType = .audioPercent
            audioPercent = audio
        }
    }

    mutating private func applyReward(_ object: [String: Any]) {
        if let xp = intValue(object["xp"]) { xpReward = xp }
        rewardBadgeId = object["badge_id"] as? String
        rewardSpeciesId = object["species_id"] as? String
        profileTitle = object["profile_title"] as? String ?? ""
        collectionItemKey = object["collection_item"] as? String ?? ""
        levelCheckOnly = object["level_check"] as? Bool ?? false
    }
}

private struct GamificationCampaignDraft {
    var id = GamificationID.make()
    var isNew = true
    var title = ""
    var description = ""
    var startsAt = Date()
    var endsAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    var imageURL = ""
    var imageData: Data?
    var ruleIds = Set<String>()
    var isActive = true

    init() {}

    init(row: [String: Any]) {
        id = GamificationID.fromRow(row)
        isNew = false
        title = row["title"] as? String ?? ""
        description = row["description"] as? String ?? ""
        startsAt = dateFromSupabase(row["starts_at"]) ?? Date()
        endsAt = dateFromSupabase(row["ends_at"]) ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        imageURL = row["image_url"] as? String ?? ""
        if let rules = row["rule_ids"] as? [String] {
            ruleIds = Set(rules)
        } else if let rules = row["rule_ids"] as? [Any] {
            ruleIds = Set(rules.compactMap { $0 as? String })
        }
        isActive = row["is_active"] as? Bool ?? true
    }

    var isValid: Bool {
        !title.trimmed.isEmpty && startsAt <= endsAt
    }

    func values() -> [String: Any?] {
        [
            "title": title.trimmed,
            "description": description.trimmed.nilIfEmpty,
            "starts_at": isoString(startsAt),
            "ends_at": isoString(endsAt),
            "image_url": imageURL.trimmed.nilIfEmpty,
            "rule_ids": Array(ruleIds).sorted(),
            "is_active": isActive
        ]
    }
}

private func tableName(for tab: GamificationAdminTab) -> String {
    switch tab {
    case .dashboard: ""
    case .badges: "badges"
    case .species: "species"
    case .levels: "gamification_levels"
    case .rules: "gamification_rules"
    case .campaigns: "gamification_campaigns"
    }
}

private func rowTitle(_ row: [String: Any]) -> String {
    row["title"] as? String ?? row["name"] as? String ?? "Elemento"
}

private func rowSubtitle(_ row: [String: Any], tab: GamificationAdminTab) -> String {
    switch tab {
    case .dashboard: return ""
    case .badges: return row["description"] as? String ?? "Badge"
    case .species: return row["scientific_name"] as? String ?? row["description"] as? String ?? "Specie"
    case .levels: return row["description"] as? String ?? "Livello"
    case .rules: return row["description"] as? String ?? row["trigger_type"] as? String ?? "Regola"
    case .campaigns: return row["description"] as? String ?? "Campagna stagionale"
    }
}

private func rowDetail(_ row: [String: Any], tab: GamificationAdminTab) -> String {
    switch tab {
    case .dashboard:
        return ""
    case .badges:
        return "\(row["category"] as? String ?? "categoria") - \(row["rarity"] as? String ?? "rarity") - \(row["xp_reward"] as? Int ?? 0) XP"
    case .species:
        return "\(row["category"] as? String ?? "categoria") - \(row["rarity"] as? String ?? "rarity")"
    case .levels:
        return "Livello \(row["level_number"] as? Int ?? 0) - \(row["required_xp"] as? Int ?? 0) XP"
    case .rules:
        return "\(row["trigger_type"] as? String ?? "trigger") - audience \(row["audience"] as? String ?? "all")"
    case .campaigns:
        return "\(dateFromSupabase(row["starts_at"])?.formatted(date: .abbreviated, time: .omitted) ?? "Inizio aperto") - \(dateFromSupabase(row["ends_at"])?.formatted(date: .abbreviated, time: .omitted) ?? "Fine aperta")"
    }
}

private func reference(row: [String: Any], titleKey: String) -> AdminReference? {
    guard let id = row["id"] as? String else { return nil }
    return AdminReference(id: id, title: row[titleKey] as? String ?? "Senza titolo")
}

private func conditionJSON(type: RuleConditionType, count: Int, poiId: String?, pathId: String?, eventId: String?) -> [String: Any] {
    switch type {
    case .none:
        return [:]
    case .poiCountTotalGTE:
        return ["poi_count_total_gte": count]
    case .path:
        return pathId.map { ["path_id": $0] } ?? [:]
    case .poi:
        return poiId.map { ["poi_id": $0] } ?? [:]
    case .event:
        return eventId.map { ["event_id": $0] } ?? [:]
    case .species:
        return [:]
    case .completionPercent:
        var object: [String: Any] = ["required_completion_percent": 100]
        if let pathId { object["path_id"] = pathId }
        return object
    case .audioPercent:
        var object: [String: Any] = ["listened_percent_gte": 80]
        if let poiId { object["poi_id"] = poiId }
        return object
    }
}

private func conditionDraft(
    from object: [String: Any],
    fallbackPOIId: String?,
    fallbackPathId: String?,
    fallbackEventId: String?
) -> (type: RuleConditionType, count: Int, poiId: String?, pathId: String?, eventId: String?) {
    if let count = intValue(object["poi_count_total_gte"]) {
        return (.poiCountTotalGTE, max(1, count), fallbackPOIId, fallbackPathId, fallbackEventId)
    }
    if let pathId = object["path_id"] as? String {
        return (.path, 1, fallbackPOIId, pathId, fallbackEventId)
    }
    if let poiId = object["poi_id"] as? String {
        return (.poi, 1, poiId, fallbackPathId, fallbackEventId)
    }
    if let eventId = object["event_id"] as? String {
        return (.event, 1, fallbackPOIId, fallbackPathId, eventId)
    }
    if intValue(object["required_completion_percent"]) != nil {
        return (.completionPercent, 1, fallbackPOIId, object["path_id"] as? String ?? fallbackPathId, fallbackEventId)
    }
    if intValue(object["listened_percent_gte"]) != nil {
        return (.audioPercent, 1, object["poi_id"] as? String ?? fallbackPOIId, fallbackPathId, fallbackEventId)
    }
    return (.none, 1, fallbackPOIId, fallbackPathId, fallbackEventId)
}

private func intValue(_ value: Any?) -> Int? {
    if let int = value as? Int { return int }
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String { return Int(string) }
    return nil
}

private func isoString(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

private func dateFromSupabase(_ value: Any?) -> Date? {
    guard let string = value as? String else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
}

// MARK: - Draft → SwiftData (stesso flusso dei POI: persist locale + SyncManager)

private extension GamificationBadgeDraft {
    func persist(in context: ModelContext) throws -> GamificationBadge {
        let entityId = UUID(uuidString: id) ?? UUID()
        let descriptor = FetchDescriptor<GamificationBadge>(predicate: #Predicate { $0.id == entityId })
        let badge: GamificationBadge
        if let existing = try context.fetch(descriptor).first {
            badge = existing
        } else {
            badge = GamificationBadge(id: entityId)
            context.insert(badge)
        }
        badge.title = title.trimmed
        badge.badgeDescription = description.trimmed
        badge.imageURL = imageURL.trimmed.nilIfEmpty
        badge.photoData = imageData
        badge.categoryRawValue = category.rawValue
        badge.rarityRawValue = rarity.rawValue
        badge.isHidden = isHidden
        badge.unlockHint = unlockHint.trimmed
        badge.sortOrder = sortOrder
        badge.xpReward = xpReward
        badge.relatedPOIId = relatedPOIId.flatMap(UUID.init(uuidString:))
        badge.relatedPathId = relatedPathId.flatMap(UUID.init(uuidString:))
        badge.relatedEventId = relatedEventId.flatMap(UUID.init(uuidString:))
        badge.relatedSpeciesId = relatedSpeciesId.flatMap(UUID.init(uuidString:))
        badge.criteriaConditionRawValue = criteriaCondition.rawValue
        badge.criteriaValue = criteriaValue
        badge.isActive = isActive
        badge.needsSync = true
        badge.updatedAt = Date()
        return badge
    }
}

private extension GamificationSpeciesDraft {
    func persist(in context: ModelContext) throws -> GamificationSpecies {
        let entityId = UUID(uuidString: id) ?? UUID()
        let descriptor = FetchDescriptor<GamificationSpecies>(predicate: #Predicate { $0.id == entityId })
        let species: GamificationSpecies
        if let existing = try context.fetch(descriptor).first {
            species = existing
        } else {
            species = GamificationSpecies(id: entityId)
            context.insert(species)
        }
        species.name = name.trimmed
        species.scientificName = scientificName.trimmed
        species.speciesDescription = description.trimmed
        species.descriptionKids = descriptionKids.trimmed
        species.descriptionEasyRead = descriptionEasyRead.trimmed
        species.categoryRawValue = category.rawValue
        species.rarityRawValue = rarity.rawValue
        species.habitat = habitat.trimmed
        species.imageURL = imageURL.trimmed.nilIfEmpty
        species.photoData = imageData
        species.iconName = iconName.trimmed.nilIfEmpty ?? "leaf.fill"
        species.relatedPOIId = relatedPOIId.flatMap(UUID.init(uuidString:))
        species.relatedPathId = relatedPathId.flatMap(UUID.init(uuidString:))
        species.unlockConditionRawValue = unlockCondition.rawValue
        species.unlockValue = unlockValue
        species.isActive = isActive
        species.needsSync = true
        species.updatedAt = Date()
        return species
    }
}

private extension GamificationLevelDraft {
    func persist(in context: ModelContext) throws -> GamificationLevel {
        let entityId = UUID(uuidString: id) ?? UUID()
        let descriptor = FetchDescriptor<GamificationLevel>(predicate: #Predicate { $0.id == entityId })
        let level: GamificationLevel
        if let existing = try context.fetch(descriptor).first {
            level = existing
        } else {
            level = GamificationLevel(id: entityId)
            context.insert(level)
        }
        level.levelNumber = levelNumber
        level.title = title.trimmed
        level.levelDescription = description.trimmed
        level.requiredXP = requiredXP
        level.iconName = iconName.trimmed.nilIfEmpty ?? "seal.fill"
        level.imageURL = imageURL.trimmed.nilIfEmpty
        level.photoData = imageData
        level.isActive = isActive
        level.needsSync = true
        level.updatedAt = Date()
        return level
    }
}

private extension GamificationRuleDraft {
    func persist(in context: ModelContext) throws -> GamificationRule {
        let entityId = UUID(uuidString: id) ?? UUID()
        let descriptor = FetchDescriptor<GamificationRule>(predicate: #Predicate { $0.id == entityId })
        let rule: GamificationRule
        if let existing = try context.fetch(descriptor).first {
            rule = existing
        } else {
            rule = GamificationRule(id: entityId)
            context.insert(rule)
        }
        rule.title = title.trimmed
        rule.ruleDescription = description.trimmed
        rule.triggerTypeRawValue = triggerType.rawValue
        rule.conditionTypeRawValue = conditionType.rawValue
        rule.conditionCount = conditionCount
        rule.conditionPOIId = conditionPOIId.flatMap(UUID.init(uuidString:))
        rule.conditionPathId = conditionPathId.flatMap(UUID.init(uuidString:))
        rule.conditionEventId = conditionEventId.flatMap(UUID.init(uuidString:))
        rule.conditionSpeciesId = conditionSpeciesId.flatMap(UUID.init(uuidString:))
        rule.requiredCompletionPercent = requiredCompletionPercent
        rule.minimumDurationMinutes = minimumDurationMinutes
        rule.requireOrderedScans = requireOrderedScans
        rule.audioPercent = audioPercent
        rule.xpReward = xpReward
        rule.rewardBadgeId = rewardBadgeId.flatMap(UUID.init(uuidString:))
        rule.rewardSpeciesId = rewardSpeciesId.flatMap(UUID.init(uuidString:))
        rule.profileTitle = profileTitle.trimmed
        rule.collectionItemKey = collectionItemKey.trimmed
        rule.levelCheckOnly = levelCheckOnly
        rule.audienceRawValue = audience.rawValue
        rule.isHidden = isHidden
        rule.isRepeatable = isRepeatable
        rule.hasCooldown = hasCooldown
        rule.cooldownSeconds = cooldownSeconds
        rule.hasDateRange = hasDateRange
        rule.startsAt = startsAt
        rule.endsAt = endsAt
        rule.priority = priority
        rule.isActive = isActive
        rule.needsSync = true
        rule.updatedAt = Date()
        return rule
    }
}

private extension GamificationCampaignDraft {
    func persist(in context: ModelContext) throws -> GamificationCampaign {
        let entityId = UUID(uuidString: id) ?? UUID()
        let descriptor = FetchDescriptor<GamificationCampaign>(predicate: #Predicate { $0.id == entityId })
        let campaign: GamificationCampaign
        if let existing = try context.fetch(descriptor).first {
            campaign = existing
        } else {
            campaign = GamificationCampaign(id: entityId)
            context.insert(campaign)
        }
        campaign.title = title.trimmed
        campaign.campaignDescription = description.trimmed
        campaign.imageURL = imageURL.trimmed.nilIfEmpty
        campaign.photoData = imageData
        campaign.startsAt = startsAt
        campaign.endsAt = endsAt
        let sortedRuleIds = Array(ruleIds).sorted()
        campaign.ruleIdsRaw = (try? String(data: JSONSerialization.data(withJSONObject: sortedRuleIds), encoding: .utf8)) ?? "[]"
        campaign.isActive = isActive
        campaign.needsSync = true
        campaign.updatedAt = Date()
        return campaign
    }
}

private extension String {
    var trimmed: String {
        // Force a native Swift string buffer by interpolating.
        // This prevents EXC_BAD_ACCESS and "zombie" strings when bridged NSStrings cross async boundaries.
        let trimmedString = trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(trimmedString)"
    }

    var nilIfEmpty: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}
