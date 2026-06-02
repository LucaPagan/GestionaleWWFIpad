import SwiftData
import SwiftUI

struct GamificationAdminView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = GamificationAdminViewModel()
    @State private var editor: AdminEditor?
    @State private var deleteTarget: (model: Any, title: String)?

    @Query(sort: \GamificationBadge.sortOrder) private var badges: [GamificationBadge]
    @Query(sort: \GamificationSpecies.name) private var species: [GamificationSpecies]
    @Query(sort: \GamificationLevel.levelNumber) private var levels: [GamificationLevel]
    @Query(sort: \GamificationRule.priority, order: .reverse) private var rules: [GamificationRule]
    @Query(sort: \GamificationCampaign.startsAt, order: .reverse) private var campaigns: [GamificationCampaign]

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
                    if let model = target.model as? GamificationBadge { Task { @MainActor in await viewModel.delete(model: model, context: modelContext) } }
                    if let model = target.model as? GamificationSpecies { Task { @MainActor in await viewModel.delete(model: model, context: modelContext) } }
                    if let model = target.model as? GamificationLevel { Task { @MainActor in await viewModel.delete(model: model, context: modelContext) } }
                    if let model = target.model as? GamificationRule { Task { @MainActor in await viewModel.delete(model: model, context: modelContext) } }
                    if let model = target.model as? GamificationCampaign { Task { @MainActor in await viewModel.delete(model: model, context: modelContext) } }
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
        if viewModel.isLoading && badges.isEmpty && species.isEmpty {
            ProgressView("Caricamento...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.selectedTab == .dashboard {
            GamificationDashboardView(analytics: viewModel.analytics)
                .refreshable { await viewModel.loadAll(context: modelContext) }
        } else {
            List {
                Section {
                    switch viewModel.selectedTab {
                    case .dashboard: EmptyView()
                    case .badges:
                        ForEach(badges) { badge in
                            GamificationBadgeRow(badge: badge, onEdit: { editor = .badge(badge) }, onDelete: { deleteTarget = (badge, badge.title) })
                        }
                    case .species:
                        ForEach(species) { spec in
                            GamificationSpeciesRow(species: spec, onEdit: { editor = .species(spec) }, onDelete: { deleteTarget = (spec, spec.name) })
                        }
                    case .levels:
                        ForEach(levels) { level in
                            GamificationLevelRow(level: level, onEdit: { editor = .level(level) }, onDelete: { deleteTarget = (level, level.title) })
                        }
                    case .rules:
                        ForEach(rules) { rule in
                            GamificationRuleRow(rule: rule, onEdit: { editor = .rule(rule) }, onDelete: { deleteTarget = (rule, rule.title) })
                        }
                    case .campaigns:
                        ForEach(campaigns) { campaign in
                            GamificationCampaignRow(campaign: campaign, onEdit: { editor = .campaign(campaign) }, onDelete: { deleteTarget = (campaign, campaign.title) })
                        }
                    }
                } header: {
                    Text(headerText)
                } footer: {
                    Text("Le definizioni sono salvate nel backend, validate da RLS e scaricate dall'app visitatore per il funzionamento offline.")
                }
            }
            .refreshable { await viewModel.loadAll(context: modelContext) }
        }
    }

    private var headerText: String {
        switch viewModel.selectedTab {
        case .dashboard: return ""
        case .badges: return "\(badges.count) elementi"
        case .species: return "\(species.count) elementi"
        case .levels: return "\(levels.count) elementi"
        case .rules: return "\(rules.count) elementi"
        case .campaigns: return "\(campaigns.count) elementi"
        }
    }

    @ViewBuilder
    private func editorView(for item: AdminEditor) -> some View {
        switch item {
        case .badge(let badge):
            BadgeEditorView(
                badge: badge,
                pois: viewModel.pois,
                paths: viewModel.paths,
                events: viewModel.events,
                species: species.map { AdminReference(id: $0.id.uuidString, title: $0.name) },
                isSaving: viewModel.isSaving,
                onSave: { await viewModel.saveModel(context: modelContext) }
            )
        case .species(let spec):
            SpeciesEditorView(
                species: spec,
                pois: viewModel.pois,
                paths: viewModel.paths,
                isSaving: viewModel.isSaving,
                onSave: { await viewModel.saveModel(context: modelContext) }
            )
        case .level(let level):
            LevelEditorView(
                level: level,
                isSaving: viewModel.isSaving,
                onSave: { await viewModel.saveModel(context: modelContext) }
            )
        case .rule(let rule):
            RuleEditorView(
                rule: rule,
                badges: badges.map { AdminReference(id: $0.id.uuidString, title: $0.title) },
                species: species.map { AdminReference(id: $0.id.uuidString, title: $0.name) },
                pois: viewModel.pois,
                paths: viewModel.paths,
                events: viewModel.events,
                isSaving: viewModel.isSaving,
                onSave: { await viewModel.saveModel(context: modelContext) }
            )
        case .campaign(let campaign):
            CampaignEditorView(
                campaign: campaign,
                rules: rules.map { AdminReference(id: $0.id.uuidString, title: $0.title) },
                isSaving: viewModel.isSaving,
                onSave: { await viewModel.saveModel(context: modelContext) }
            )
        }
    }

    private func newEditor(for tab: GamificationAdminTab) -> AdminEditor? {
        switch tab {
        case .dashboard: return nil
        case .badges:
            let b = GamificationBadge()
            modelContext.insert(b)
            return .badge(b)
        case .species:
            let s = GamificationSpecies()
            modelContext.insert(s)
            return .species(s)
        case .levels:
            let l = GamificationLevel(levelNumber: (levels.map(\.levelNumber).max() ?? 0) + 1)
            modelContext.insert(l)
            return .level(l)
        case .rules:
            let r = GamificationRule()
            modelContext.insert(r)
            return .rule(r)
        case .campaigns:
            let c = GamificationCampaign()
            modelContext.insert(c)
            return .campaign(c)
        }
    }
}


