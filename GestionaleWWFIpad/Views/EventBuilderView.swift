//
//  EventBuilderView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//

import SwiftUI
import SwiftData

struct EventBuilderView: View {
    let event: Event?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPOIs: [POI]
    @Query private var allTrails: [Trail]

    @State private var name = ""
    @State private var description = ""
    @State private var category: EventCategory = .generic
    @State private var isActive = false
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var maxParticipants = 30
    @State private var organizerName = ""
    @State private var contactInfo = ""
    @State private var requirements = ""
    @State private var targetAudience = "Tutti"
    @State private var price = "Gratuito"
    @State private var selectedTrail: Trail? = nil
    @State private var selectedPOI: POI? = nil

    var isFormValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

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
            }
            .navigationTitle(event == nil ? "Nuovo evento" : "Modifica evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveEvent() }.disabled(!isFormValid).fontWeight(.semibold)
                }
            }
            .onAppear { loadExistingData() }
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
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
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
                ForEach(["Tutti", "Famiglie", "Adulti", "Bambini 6-12", "Ragazzi 12-18", "Esperti"], id: \.self) { Text($0).tag($0) }
            }
            TextField("Costo (es. Gratuito, €5.00)", text: $price)
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

    var startPointPOIs: [POI] {
        allPOIs.filter { $0.isStartPoint }
    }

    private var locationSection: some View {
        Section {
            if startPointPOIs.isEmpty {
                Label("Nessun punto di partenza disponibile. Crea un POI e attiva 'Punto di partenza' nell'editor mappa.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("Luogo dell'evento", selection: $selectedPOI) {
                    Text("Nessun luogo specifico").tag(Optional<POI>(nil))
                    ForEach(startPointPOIs) { poi in Label(poi.name, systemImage: poi.type.icon).tag(Optional(poi)) }
                }
                .pickerStyle(.menu).tint(Color("WWFGreen"))
            }
        } header: { Text("Luogo dell'evento") }
        footer: { Text("Seleziona il POI dove si svolge l'evento.").font(.caption2) }
    }

    private var trailSection: some View {
        Section {
            Picker("Percorso", selection: $selectedTrail) {
                Text("Nessun percorso").tag(Optional<Trail>(nil))
                ForEach(allTrails) { trail in Text(trail.name).tag(Optional(trail)) }
            }
            .pickerStyle(.menu).tint(Color("WWFGreen"))
            if let trail = selectedTrail {
                HStack(spacing: 12) {
                    Label(trail.difficulty.rawValue, systemImage: trail.difficulty.icon)
                        .font(.caption).foregroundColor(Color(hex: trail.difficulty.color) ?? .green)
                    Label("\(trail.estimatedMinutes) min", systemImage: "clock")
                        .font(.caption).foregroundColor(.secondary)
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

    // MARK: - Helpers

    private func loadExistingData() {
        guard let e = event else { return }
        name = e.name; description = e.eventDescription; category = e.category
        isActive = e.isActive; eventDate = e.date; startTime = e.startTime; endTime = e.endTime
        maxParticipants = e.maxParticipants; organizerName = e.organizerName
        contactInfo = e.contactInfo; requirements = e.requirements
        targetAudience = e.targetAudience; price = e.price
        selectedTrail = e.trail; selectedPOI = e.eventPOI
    }

    private func saveEvent() {
        let t = event ?? Event(name: "", description: "")
        t.name = name; t.eventDescription = description; t.category = category
        t.isActive = isActive; t.date = eventDate; t.startTime = startTime; t.endTime = endTime
        t.maxParticipants = maxParticipants; t.organizerName = organizerName
        t.contactInfo = contactInfo; t.requirements = requirements
        t.targetAudience = targetAudience; t.price = price
        t.trail = selectedTrail; t.eventPOI = selectedPOI
        if event == nil { context.insert(t) }
        try? context.save()
        dismiss()
    }
}
