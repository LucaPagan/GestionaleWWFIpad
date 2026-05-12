import SwiftUI
import SwiftData
import UIKit

// MARK: - MapEditorView

struct MapEditorView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var syncManager: SyncManager
    @Query private var allPOIs: [POI]

    // MARK: - States for POI Editor
    @State private var showPOIEditor    = false
    @State private var pendingPosition: CGPoint? = nil
    @State private var selectedPOI: POI? = nil
    @State private var isAddingPOI: Bool = false

    // MARK: - States for Trail Builder
    enum MapMode: Equatable {
        case defaultMode
        case buildingTrail(Trail?)
        
        var trail: Trail? {
            if case let .buildingTrail(t) = self { return t }
            return nil
        }
    }
    
    @State private var mapMode: MapMode = .defaultMode
    @State private var showTrailList = false
    
    // Trail form fields
    @State private var tbName: String = ""
    @State private var tbDescription: String = ""
    @State private var tbDifficulty: TrailDifficulty = .easy
    @State private var tbEstimatedMinutes: Int = 60
    @State private var tbIsActive: Bool = false
    @State private var tbSteps: [TrailDraftStep] = []
    @State private var tbSelectedStartPOI: POI? = nil
    @State private var tbIsSyncing: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    
                    // ── MAP AREA ──
                    ZStack {
                        Color.black.ignoresSafeArea()

                        TrailInteractiveMapView(
                            imageName: "astroni_map",
                            allPOIs: allPOIs,
                            trailSteps: mapMode == .defaultMode ? [] : tbSteps,
                            selectedPOIId: selectedPOI?.id,
                            onTapMap: { normalizedPoint in
                                if isAddingPOI {
                                    pendingPosition = normalizedPoint
                                    selectedPOI = nil
                                    showPOIEditor = true
                                    isAddingPOI = false
                                } else {
                                    selectedPOI = nil // Deseleziona se clicchi sul vuoto
                                }
                            },
                            onTapPOI: { poi in
                                if isAddingPOI {
                                    // Ignora i tap sui POI se stiamo cercando di aggiungere un nuovo POI
                                    return
                                }
                                
                                if mapMode != .defaultMode {
                                    // Aggiungi alla rotta
                                    withAnimation {
                                        tbSteps.append(TrailDraftStep(poi: poi, instructions: ""))
                                    }
                                } else {
                                    // Modalità base: modifica POI
                                    selectedPOI = poi
                                    showPOIEditor = true
                                }
                            }
                        )
                        .ignoresSafeArea()

                        // HUD Overlay
                        VStack(spacing: 0) {
                            hudTopBar
                            Spacer()
                            hudBottomBar
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // ── SIDEBAR AREA ──
                    if mapMode != .defaultMode {
                        Divider()
                        TrailBuilderSidebar(
                            trail: mapMode.trail,
                            name: $tbName,
                            description: $tbDescription,
                            difficulty: $tbDifficulty,
                            estimatedMinutes: $tbEstimatedMinutes,
                            isActive: $tbIsActive,
                            steps: $tbSteps,
                            selectedStartPOI: $tbSelectedStartPOI,
                            allPOIs: allPOIs,
                            onSave: saveTrail,
                            onCancel: closeTrailBuilder,
                            isSyncing: tbIsSyncing
                        )
                        .frame(width: max(350, geo.size.width * 0.35))
                        .transition(.move(edge: .trailing))
                    }
                }
            }
            .navigationTitle(mapMode == .defaultMode ? "Gestione Mappa e Percorsi" : "Editor Percorso")
            .navigationBarTitleDisplayMode(.inline)
            
            // ── SHEETS ──
            .sheet(isPresented: $showPOIEditor, onDismiss: {
                pendingPosition = nil
                selectedPOI = nil
            }) {
                if let existing = selectedPOI {
                    POIEditorView(
                        mode: .edit(existing),
                        onSave: { handleSavePOI($0) },
                        onDelete: { handleDeletePOI($0) }
                    )
                    .presentationDetents([.medium, .large])
                } else if let pos = pendingPosition {
                    POIEditorView(
                        mode: .create(x: pos.x, y: pos.y),
                        onSave: { handleSavePOI($0) },
                        onDelete: nil
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showTrailList) {
                // Il modale della lista dei percorsi
                TrailBuilderListView(onEdit: { trail in
                    showTrailList = false
                    openTrailBuilder(for: trail)
                })
            }
        }
        // Aggiungiamo un'animazione globale quando cambia la modalità
        .animation(.easeInOut(duration: 0.3), value: mapMode)
    }

    // MARK: - HUD Elements

    private var hudTopBar: some View {
        HStack(alignment: .top) {
            // Sezione Gestione Percorsi
            VStack(alignment: .leading, spacing: 8) {
                if mapMode == .defaultMode {
                    HStack(spacing: 12) {
                        Button {
                            openTrailBuilder(for: nil)
                        } label: {
                            Label("Crea Percorso", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color("WWFGreen"))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(radius: 2)
                        }
                        
                        Button {
                            withAnimation {
                                isAddingPOI.toggle()
                            }
                        } label: {
                            Label(isAddingPOI ? "Annulla" : "Aggiungi POI", systemImage: isAddingPOI ? "xmark.circle.fill" : "mappin.and.ellipse")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isAddingPOI ? Color.red : Color("WWFGreen"))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(radius: 2)
                        }
                    }
                    
                    if isAddingPOI {
                        Label("Tocca un punto sulla mappa per posizionare il POI", systemImage: "hand.tap.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.orange.opacity(0.9))
                            .clipShape(Capsule())
                    } else {
                        Button {
                            showTrailList = true
                        } label: {
                            Label("Visualizza Percorsi", systemImage: "list.bullet")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    Label("Seleziona i POI dalla mappa o trascinali a destra.", systemImage: "hand.tap.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            
            Spacer()
            
            // Contatore POI
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color("WWFGreen"))
                Text("\(allPOIs.count) POI")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
    }

    private var hudBottomBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(POIType.allCases, id: \.self) { type in
                    HStack(spacing: 5) {
                        Image(systemName: type.icon)
                            .font(.caption2)
                            .foregroundColor(type.color)
                        Text(type.displayName)
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Trail Logic

    private func openTrailBuilder(for trail: Trail?) {
        if let t = trail {
            tbName = t.name
            tbDescription = t.trailDescription
            tbDifficulty = t.difficulty ?? .easy
            tbEstimatedMinutes = t.estimatedMinutes ?? 60
            tbIsActive = t.isActive
            if let startId = t.startPOIId {
                tbSelectedStartPOI = allPOIs.first { $0.id == startId }
            }
            tbSteps = t.sortedSteps.map {
                TrailDraftStep(
                    poi: $0.poi,
                    instructions: $0.directionHint ?? "",
                    distanceMeters: $0.distanceMeters,
                    estimatedMinutes: $0.estimatedMinutes
                )
            }
        } else {
            tbName = ""
            tbDescription = ""
            tbDifficulty = .easy
            tbEstimatedMinutes = 60
            tbIsActive = false
            tbSelectedStartPOI = nil
            tbSteps = []
        }
        mapMode = .buildingTrail(trail)
    }

    private func closeTrailBuilder() {
        mapMode = .defaultMode
    }

    private func saveTrail() {
        tbIsSyncing = true
        let target = mapMode.trail ?? Trail(name: "", description: "")
        target.name = tbName
        target.trailDescription = tbDescription
        target.difficulty = tbDifficulty
        target.estimatedMinutes = tbEstimatedMinutes
        target.isActive = tbIsActive
        target.startPOIId = tbSelectedStartPOI?.id
        target.needsSync = true
        target.updatedAt = Date()

        target.steps.forEach { context.delete($0) }
        target.steps = tbSteps.enumerated().map { i, draft in
            let s = TrailStep(
                stepOrder: i,
                directionHint: draft.instructions,
                distanceMeters: draft.distanceMeters,
                estimatedMinutes: draft.estimatedMinutes,
                poi: draft.poi
            )
            context.insert(s)
            return s
        }

        if mapMode.trail == nil { context.insert(target) }
        try? context.save()

        Task {
            await syncManager.pushAllChanges()
            await MainActor.run {
                tbIsSyncing = false
                closeTrailBuilder()
            }
        }
    }

    // MARK: - POI Logic

    private func handleSavePOI(_ poi: POI) {
        let isNew = !allPOIs.contains(where: { $0.id == poi.id })
        if isNew { context.insert(poi) }
        try? context.save()

        Task {
            await syncManager.pushAllChanges()
        }

        showPOIEditor = false
        selectedPOI = nil
        pendingPosition = nil
    }

    private func handleDeletePOI(_ poi: POI) {
        context.delete(poi)
        try? context.save()
        showPOIEditor = false
        selectedPOI = nil
        pendingPosition = nil
    }
}
