import SwiftUI
import SwiftData

struct TrailDraftStep: Identifiable, Equatable {
    let id = UUID()
    var poi: POI?
    var instructions: String
    var distanceMeters: Int?
    var estimatedMinutes: Int?
    var pathGeometry: String?
    
    static func == (lhs: TrailDraftStep, rhs: TrailDraftStep) -> Bool {
        lhs.id == rhs.id
    }
}

struct TrailBuilderSidebar: View {
    let trail: Trail?
    @Binding var name: String
    @Binding var description: String
    @Binding var difficulty: TrailDifficulty
    @Binding var estimatedMinutes: Int
    @Binding var isActive: Bool
    @Binding var steps: [TrailDraftStep]
    @Binding var selectedStartPOI: POI?
    
    let allPOIs: [POI]
    let onSave: () -> Void
    let onCancel: () -> Void
    let isSyncing: Bool

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
    }
    
    var startPointPOIs: [POI] {
        allPOIs.filter { $0.isStartPoint }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(trail == nil ? "Nuovo percorso" : "Modifica percorso")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            
            Divider()
            
            List {
                Section("Informazioni generali") {
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
                
                Section("Parametri") {
                    Picker("Difficoltà", selection: $difficulty) {
                        ForEach(TrailDifficulty.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    Stepper("Durata: \(estimatedMinutes) min", value: $estimatedMinutes, in: 10...480, step: 10)
                    Toggle("Visibile ai visitatori", isOn: $isActive)
                        .tint(Color("WWFGreen"))
                }
                
                Section {
                    if startPointPOIs.isEmpty {
                        Label("Nessun punto di partenza disponibile. Creane uno.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Seleziona punto di partenza", selection: $selectedStartPOI) {
                            Text("Nessuno").tag(POI?.none)
                            ForEach(startPointPOIs) { poi in
                                Text(poi.name).tag(poi as POI?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color("WWFGreen"))
                    }
                } header: {
                    Text("Punto di partenza")
                }
                
                Section {
                    ForEach($steps) { $step in
                        TrailStepCard(step: $step, allPOIs: allPOIs)
                    }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { steps.remove(atOffsets: $0) }
                    
                    Button {
                        steps.append(TrailDraftStep(poi: nil, instructions: ""))
                    } label: {
                        Label("Aggiungi tappa vuota", systemImage: "plus.circle.fill")
                            .foregroundColor(Color("WWFGreen"))
                    }
                } header: {
                    Text("Tappe (\(steps.count))")
                } footer: {
                    Text("Puoi trascinare i POI dalla mappa qui, oppure riordinarli tenendo premuto sulle tre linee a destra.")
                        .font(.caption2)
                }
            }
            .listStyle(.insetGrouped)
            .dropDestination(for: String.self) { items, location in
                var itemsAdded = false
                for item in items {
                    if let uuid = UUID(uuidString: item), let poi = allPOIs.first(where: { $0.id == uuid }) {
                        steps.append(TrailDraftStep(poi: poi, instructions: ""))
                        itemsAdded = true
                    }
                }
                return itemsAdded
            }
            
            Divider()
            
            // Footer (Save button)
            HStack {
                if isSyncing {
                    ProgressView()
                } else {
                    Button(action: onSave) {
                        Text("Salva Percorso")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color("WWFGreen") : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
    }
}

// MARK: - Step Card Inline Editor

struct TrailStepCard: View {
    @Binding var step: TrailDraftStep
    let allPOIs: [POI]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let poi = step.poi {
                    Image(systemName: poi.type.icon)
                        .foregroundColor(poi.type.color)
                        .font(.title3)
                    Text(poi.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                } else {
                    Text("Seleziona POI...")
                        .foregroundColor(.secondary)
                        .italic()
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                Divider()
                
                Picker("Punto di interesse", selection: $step.poi) {
                    Text("Nessuno").tag(POI?.none)
                    ForEach(allPOIs) { p in
                        Text(p.name).tag(p as POI?)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color("WWFGreen"))
                
                TextField("Indicazioni (es. 'Vai dritto per 200m...')", text: $step.instructions, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Distanza (m)").font(.caption2).foregroundColor(.secondary)
                        TextField("0", value: $step.distanceMeters, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading) {
                        Text("Minuti stimati").font(.caption2).foregroundColor(.secondary)
                        TextField("0", value: $step.estimatedMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                if step.poi != nil {
                    Button {
                        // Action handled by parent via callback/binding
                        NotificationCenter.default.post(name: NSNotification.Name("TriggerPathTracing"), object: step.id)
                    } label: {
                        HStack {
                            Image(systemName: "scribble.variable")
                            Text(step.pathGeometry == nil ? "Traccia percorso per arrivare qui" : "Ridisegna percorso")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(step.pathGeometry == nil ? Color.blue : Color.orange)
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            if step.poi == nil && step.instructions.isEmpty {
                isExpanded = true
            }
        }
    }
}
