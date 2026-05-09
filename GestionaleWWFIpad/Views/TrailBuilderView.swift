//
//  TrailBuilderView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import SwiftData

struct TrailBuilderView: View {
    let trail: Trail?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPOIs: [POI]

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var difficulty: TrailDifficulty = .easy
    @State private var estimatedMinutes: Int = 60
    @State private var isActive: Bool = false
    @State private var steps: [DraftStep] = []
    @State private var showAddStep = false
    @State private var qrPOI: POI? = nil
    
    @State private var startPointName: String = "Punto di partenza"
    @State private var startPointDescription: String = "Inizia qui il tuo percorso."
    @State private var startX: Double = 0.1
    @State private var startY: Double = 0.9
    @State private var selectedStartPOI: POI? = nil

    // Step draft (non ancora persistiti)
    struct DraftStep: Identifiable {
        let id = UUID()
        var poi: POI?
        var instructions: String
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
    }

    var startPointPOIs: [POI] {
    allPOIs.filter { $0.isStartPoint }
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Info base
                Section("Informazioni percorso") {
                    TextField("Nome percorso", text: $name)
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Descrizione...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 60)
                    }
                }

                // MARK: Parametri
                Section("Parametri") {
                    Picker("Difficoltà", selection: $difficulty) {
                        ForEach(TrailDifficulty.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    Stepper("Durata: \(estimatedMinutes) min", value: $estimatedMinutes, in: 10...480, step: 10)
                    Toggle("Visibile ai visitatori", isOn: $isActive)
                        .tint(Color("WWFGreen"))
                }
                
                // MARK: Punto di partenza
                Section {
    if startPointPOIs.isEmpty {
        Label("Nessun punto di partenza disponibile. Crea un POI e attiva 'Punto di partenza' nell'editor mappa.", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundColor(.secondary)
    } else {
        Picker("Seleziona punto di partenza", selection: $selectedStartPOI) {
            Text("Nessuno").tag(Optional<POI>(nil))
            ForEach(startPointPOIs) { poi in
                Label(poi.name, systemImage: poi.type.icon).tag(Optional(poi))
            }
        }
        .pickerStyle(.menu)
        .tint(Color("WWFGreen"))

        if let poi = selectedStartPOI {
            VStack(alignment: .leading, spacing: 4) {
                Text("Posizione: (\(String(format: "%.2f", poi.x)), \(String(format: "%.2f", poi.y)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if !poi.poiDescription.isEmpty {
                    Text(poi.poiDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
} header: {
    Text("Punto di partenza")
} footer: {
    Text("Il punto di partenza viene mostrato sulla mappa all'inizio del percorso.")
        .font(.caption2)
}

                // MARK: Tappe
                Section {
                    ForEach($steps) { $step in
                        StepEditorRow(
                            step: $step,
                            allPOIs: allPOIs,
                            onQRTap: { poi in qrPOI = poi }
                        )
                    }
                    .onMove { from, to in steps.move(fromOffsets: from, toOffset: to) }
                    .onDelete { steps.remove(atOffsets: $0) }

                    Button {
                        steps.append(DraftStep(poi: nil, instructions: ""))
                    } label: {
                        Label("Aggiungi tappa", systemImage: "plus.circle.fill")
                            .foregroundColor(Color("WWFGreen"))
                    }
                } header: {
                    Text("Tappe (\(steps.count))")
                } footer: {
                    Text("Tieni premuto e trascina per riordinare le tappe. Tocca il QR per scaricare il codice.")
                        .font(.caption2)
                }
            }
            .navigationTitle(trail == nil ? "Nuovo percorso" : "Modifica percorso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveTrail() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !steps.isEmpty { EditButton() }
                }
            }
            .onAppear { loadExistingData() }
            .environment(\.editMode, .constant(.active))
            .sheet(item: $qrPOI) { poi in
                QRDisplayView(poi: poi)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Helpers

    private func loadExistingData() {
        guard let t = trail else { return }
        name = t.name
        description = t.trailDescription
        difficulty = t.difficulty
        estimatedMinutes = t.estimatedMinutes
        isActive = t.isActive
        startPointName = t.startPointName
        startPointDescription = t.startPointDescription
        startX = t.startX
        startY = t.startY
        selectedStartPOI = allPOIs.first {
            $0.isStartPoint && abs($0.x - t.startX) < 0.001 && abs($0.y - t.startY) < 0.001
        }

        steps = t.sortedSteps.map { DraftStep(poi: $0.poi, instructions: $0.instructions) }
    }

    private func saveTrail() {
        let target = trail ?? Trail(name: "", description: "")
        target.name = name
        target.trailDescription = description
        target.difficulty = difficulty
        target.estimatedMinutes = estimatedMinutes
        target.isActive = isActive
        target.startPointName = startPointName
        target.startPointDescription = startPointDescription
        target.startX = startX
        target.startY = startY

if let poi = selectedStartPOI {
    target.startPointName        = poi.name
    target.startPointDescription = poi.poiDescription
    target.startX                = poi.x
    target.startY                = poi.y
}

        target.steps.forEach { context.delete($0) }
        target.steps = steps.enumerated().map { i, draft in
            let s = TrailStep(orderIndex: i, instructions: draft.instructions, poi: draft.poi)
            context.insert(s)
            return s
        }

        if trail == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}

// MARK: - Step row editor

struct StepEditorRow: View {
    @Binding var step: TrailBuilderView.DraftStep
    let allPOIs: [POI]
    var onQRTap: (POI) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Riga picker + bottone QR
            HStack(spacing: 8) {
                Picker("Punto di interesse", selection: $step.poi) {
                    Text("Nessun POI").tag(Optional<POI>(nil))
                    ForEach(allPOIs) { poi in
                        Label(poi.name, systemImage: poi.type.icon).tag(Optional(poi))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color("WWFGreen"))

                // Bottone QR — visibile solo se il POI è selezionato
                if let poi = step.poi {
                    Button {
                        onQRTap(poi)
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.title3)
                            .foregroundColor(Color("WWFGreen"))
                            .frame(width: 36, height: 36)
                            .background(Color("WWFGreen").opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: step.poi?.id)
                }
            }

            // Indicazioni testuali
            TextField("Indicazioni (es. 'Vai dritto 200m...')", text: $step.instructions, axis: .vertical)
                .font(.caption)
                .lineLimit(2...4)
        }
        .padding(.vertical, 4)
    }
}
