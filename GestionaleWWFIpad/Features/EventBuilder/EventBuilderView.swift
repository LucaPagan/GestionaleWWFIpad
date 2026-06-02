//
//  EventBuilderView.swift
//  GestionaleWWFIpad
//
//  Created by Luca Pagano on 06/05/26.
//  Refactored to use new model layer mirroring Supabase schema.
//

import SwiftUI
import SwiftData

struct EventBuilderView: View {
    let event: Event?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPOIs: [POI]
    @Query private var allTrails: [Trail]
    @EnvironmentObject private var syncManager: SyncManager

    @State private var name = ""
    @State private var description = ""
    @State private var category: EventCategory = .other
    @State private var isActive = false
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var maxParticipants = 30
    @State private var organizerName = ""
    @State private var contactInfo = ""
    @State private var requirements = ""
    @State private var targetAudience: EventAudience = .all
    @State private var price: Double = 0
    @State private var selectedTrailId: UUID? = nil
    @State private var selectedPOIId: UUID? = nil
    @State private var errorMessage: String?
    @State private var isSaving = false

    var validationIssues: [AdminValidationIssue] {
        AdminValidationService.eventIssues(
            name: name,
            isActive: isActive,
            startTime: startTime,
            endTime: endTime,
            maxParticipants: maxParticipants,
            price: price,
            trail: selectedTrail,
            eventPOI: selectedPOI
        )
    }

    var isFormValid: Bool {
        !validationIssues.contains { $0.severity == .error }
    }

    var body: some View {
        NavigationStack {
            Form {
                infoSection
                dateSection
                detailsSection
                requirementsSection
                locationSection
                trailSection
                visibilitySection
                validationSection
            }
            .navigationTitle(event == nil ? "Nuovo evento" : "Modifica evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Salvataggio..." : "Salva") { saveEvent() }
                        .disabled(!isFormValid || isSaving)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadExistingData()
            }
            .alert("Evento non valido", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section("Informazioni evento") {
            TextField("Nome evento", text: $name)
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Descrizione dell'evento...").foregroundColor(.secondary).padding(.top, 8)
                }
                TextEditor(text: $description).frame(minHeight: 80)
            }
            Picker("Categoria", selection: $category) {
                ForEach(EventCategory.allCases, id: \.self) { cat in
                    Label(cat.displayName, systemImage: cat.icon).tag(cat)
                }
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Data", selection: $eventDate, displayedComponents: .date).tint(Color("WWFGreen"))
            DatePicker("Ora inizio", selection: $startTime, displayedComponents: .hourAndMinute).tint(Color("WWFGreen"))
            DatePicker("Ora fine", selection: $endTime, displayedComponents: .hourAndMinute).tint(Color("WWFGreen"))
        } header: { Text("Data e Orario") }
    }

    private var detailsSection: some View {
        Section("Dettagli organizzativi") {
            Stepper("Max partecipanti: \(maxParticipants)", value: $maxParticipants, in: 1...500, step: 5)
            TextField("Organizzatore", text: $organizerName)
            TextField("Contatto (email o telefono)", text: $contactInfo).keyboardType(.emailAddress)
            Picker("Pubblico target", selection: $targetAudience) {
                ForEach(EventAudience.allCases, id: \.self) { audience in
                    Text(audience.displayName).tag(audience)
                }
            }
            HStack {
                Text("Prezzo")
                Spacer()
                TextField("0.00", value: $price, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("€")
                    .foregroundColor(.secondary)
            }
            if price == 0 {
                Text("Gratuito")
                    .font(.caption)
                    .foregroundColor(Color("WWFGreen"))
            }
        }
    }

    private var requirementsSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if requirements.isEmpty {
                    Text("Cosa portare, abbigliamento...").foregroundColor(.secondary).padding(.top, 8)
                }
                TextEditor(text: $requirements).frame(minHeight: 60)
            }
        } header: { Text("Requisiti e note") }
    }

    private var selectedTrail: Trail? {
        guard let selectedTrailId else { return nil }
        return dedupedTrails.first { $0.id == selectedTrailId }
    }

    private var selectedPOI: POI? {
        guard let selectedPOIId else { return nil }
        return dedupedPOIs.first { $0.id == selectedPOIId }
    }

    private var dedupedPOIs: [POI] {
        dedupe(allPOIs).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var dedupedTrails: [Trail] {
        dedupe(allTrails).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var eventLocationPOIs: [POI] {
        dedupedPOIs
    }

    private var locationSection: some View {
        Section {
            if eventLocationPOIs.isEmpty {
                Label("Nessun POI disponibile. Crea un POI nell'editor mappa per collegarlo all'evento.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("Luogo dell'evento", selection: $selectedPOIId) {
                    Text("Nessun luogo specifico").tag(UUID?.none)
                    if let selectedPOIId, !eventLocationPOIs.contains(where: { $0.id == selectedPOIId }) {
                        Text("Luogo non disponibile").tag(Optional(selectedPOIId))
                    }
                    ForEach(eventLocationPOIs, id: \.id) { poi in
                        Label(poi.name, systemImage: poi.type.icon).tag(Optional(poi.id))
                    }
                }
                .pickerStyle(.menu).tint(Color("WWFGreen"))
            }
        } header: { Text("Luogo dell'evento") }
        footer: { Text("Seleziona il POI dove si svolge l'evento.").font(.caption2) }
    }

    private var trailSection: some View {
        Section {
            Picker("Percorso", selection: $selectedTrailId) {
                Text("Nessun percorso").tag(UUID?.none)
                if let selectedTrailId, !dedupedTrails.contains(where: { $0.id == selectedTrailId }) {
                    Text("Percorso non disponibile").tag(Optional(selectedTrailId))
                }
                ForEach(dedupedTrails, id: \.id) { trail in
                    Text(trail.name).tag(Optional(trail.id))
                }
            }
            .pickerStyle(.menu).tint(Color("WWFGreen"))
            if let trail = selectedTrail, let difficulty = trail.difficulty {
                HStack(spacing: 12) {
                    Label(difficulty.displayName, systemImage: difficulty.icon)
                        .font(.caption).foregroundColor(difficulty.color)
                    if let mins = trail.estimatedMinutes {
                        Label("\(mins) min", systemImage: "clock")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Label("\(trail.steps.count) tappe", systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        } header: { Text("Percorso per raggiungere l'evento") }
        footer: { Text("Indica ai visitatori come arrivare al luogo dell'evento.").font(.caption2) }
    }

    private var visibilitySection: some View {
        Section {
            Toggle("Visibile ai visitatori", isOn: $isActive).tint(Color("WWFGreen"))
        }
    }

    private var validationSection: some View {
        Group {
            if !validationIssues.isEmpty {
                Section("Controlli pubblicazione") {
                    ForEach(validationIssues) { issue in
                        Label(issue.message, systemImage: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(issue.severity == .error ? .red : .orange)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadExistingData() {
        guard let e = event else { return }
        name = e.name; description = e.eventDescription; category = e.category
        isActive = e.isActive; eventDate = e.date; startTime = e.timeStart; endTime = e.timeEnd
        maxParticipants = e.maxParticipants ?? 30; organizerName = e.organizerName ?? ""
        contactInfo = e.contactInfo ?? ""; requirements = e.requirements ?? ""
        targetAudience = e.targetAudience; price = e.price
        selectedTrailId = e.trail?.id; selectedPOIId = e.eventPOI?.id
    }

    private func saveEvent() {
        let issues = validationIssues
        if issues.contains(where: { $0.severity == .error }) {
            errorMessage = issues.map(\.message).joined(separator: "\n")
            return
        }

        let t = event ?? Event(name: "", description: "")
        t.name = name; t.eventDescription = description; t.category = category
        t.isActive = isActive; t.date = Calendar.current.startOfDay(for: eventDate); t.timeStart = startTime; t.timeEnd = endTime
        t.maxParticipants = maxParticipants > 0 ? maxParticipants : nil
        t.organizerName = organizerName.isEmpty ? nil : organizerName
        t.contactInfo = contactInfo.isEmpty ? nil : contactInfo
        t.requirements = requirements.isEmpty ? nil : requirements
        t.targetAudience = targetAudience; t.price = price
        t.trail = selectedTrail; t.eventPOI = selectedPOI
        t.needsSync = true
        t.updatedAt = Date()
        if event == nil { context.insert(t) }

        do {
            try context.save()
        } catch {
            errorMessage = "Errore durante il salvataggio locale: \(error.localizedDescription)"
            return
        }

        isSaving = true
        Task { @MainActor in
            await syncManager.pushAllChanges()
            isSaving = false
            if case .error(let message) = syncManager.syncState {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }

    private func dedupe<T: Identifiable>(_ items: [T]) -> [T] where T.ID == UUID {
        var seen = Set<UUID>()
        return items.filter { item in
            seen.insert(item.id).inserted
        }
    }
}
