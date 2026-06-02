import PhotosUI
import SwiftUI
import SwiftData

struct BadgeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var badge: GamificationBadge
    let pois: [AdminReference]
    let paths: [AdminReference]
    let events: [AdminReference]
    let species: [AdminReference]
    let isSaving: Bool
    let onSave: () async -> Void

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    var body: some View {
        DefinitionEditorScaffold(
            title: badge.title.isEmpty ? "Nuovo badge" : "Modifica badge",
            canSave: !badge.title.isEmpty && !badge.badgeDescription.isEmpty,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Informazioni") {
                TextField("Titolo", text: $badge.title)
                TextField("Descrizione", text: $badge.badgeDescription, axis: .vertical)
                    .lineLimit(3...6)
                Picker("Categoria", selection: categoryBinding) {
                    ForEach(BadgeCategory.allCases) { Text($0.title).tag($0) }
                }
                Picker("Rarita", selection: rarityBinding) {
                    ForEach(GamificationRarity.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Badge segreto", isOn: $badge.isHidden)
                Toggle("Attivo", isOn: $badge.isActive)
                Stepper("Ordine: \(badge.sortOrder)", value: $badge.sortOrder, in: 0...999)
            }
            imageSection(imageURL: Binding(get: { badge.imageURL ?? "" }, set: { badge.imageURL = $0 }), imageData: $badge.photoData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Ricompensa") {
                Stepper("XP extra: \(badge.xpReward)", value: $badge.xpReward, in: 0...5000, step: 5)
                TextField("Indizio di sblocco", text: $badge.unlockHint, axis: .vertical)
                    .lineLimit(2...4)
            }
            relationSection(title: "Collegamenti", poiId: $badge.relatedPOIId, pathId: $badge.relatedPathId, eventId: $badge.relatedEventId, speciesId: $badge.relatedSpeciesId, pois: pois, paths: paths, events: events, species: species)
            criteriaSection(title: "Criteri badge", conditionType: conditionBinding, conditionValue: $badge.criteriaValue, selectedPOI: $badge.relatedPOIId, selectedPath: $badge.relatedPathId, selectedEvent: $badge.relatedEventId, pois: pois, paths: paths, events: events)
            BadgePreviewCard(title: badge.title, description: badge.badgeDescription, category: BadgeCategory(rawValue: badge.categoryRawValue)?.title ?? "Sconosciuta", rarity: GamificationRarity(rawValue: badge.rarityRawValue)?.title ?? "Sconosciuta", imageData: previewData ?? badge.photoData, imageURL: badge.imageURL ?? "", isHidden: badge.isHidden)
        }
    }

    private var categoryBinding: Binding<BadgeCategory> {
        Binding(
            get: { BadgeCategory(rawValue: badge.categoryRawValue) ?? .exploration },
            set: { badge.categoryRawValue = $0.rawValue }
        )
    }

    private var rarityBinding: Binding<GamificationRarity> {
        Binding(
            get: { GamificationRarity(rawValue: badge.rarityRawValue) ?? .common },
            set: { badge.rarityRawValue = $0.rawValue }
        )
    }

    private var conditionBinding: Binding<RuleConditionType> {
        Binding(
            get: { RuleConditionType(rawValue: badge.criteriaConditionRawValue) ?? .none },
            set: { badge.criteriaConditionRawValue = $0.rawValue }
        )
    }

    private func save() {
        badge.needsSync = true
        badge.updatedAt = Date()
        Task { @MainActor in
            await onSave()
            dismiss()
        }
    }
}

struct SpeciesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var species: GamificationSpecies
    let pois: [AdminReference]
    let paths: [AdminReference]
    let isSaving: Bool
    let onSave: () async -> Void

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    var body: some View {
        DefinitionEditorScaffold(
            title: species.name.isEmpty ? "Nuova specie" : "Modifica specie",
            canSave: !species.name.isEmpty && !species.speciesDescription.isEmpty,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Informazioni") {
                TextField("Nome", text: $species.name)
                TextField("Nome scientifico", text: $species.scientificName)
                Picker("Categoria", selection: categoryBinding) {
                    ForEach(SpeciesCategory.allCases) { Text($0.title).tag($0) }
                }
                Picker("Rarita", selection: rarityBinding) {
                    ForEach(GamificationRarity.allCases) { Text($0.title).tag($0) }
                }
                TextField("Habitat", text: $species.habitat)
                Toggle("Attiva", isOn: $species.isActive)
            }
            Section("Testi visitatore") {
                TextField("Descrizione", text: $species.speciesDescription, axis: .vertical)
                    .lineLimit(4...8)
                TextField("Descrizione Kids", text: $species.descriptionKids, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Descrizione Easy Read", text: $species.descriptionEasyRead, axis: .vertical)
                    .lineLimit(3...6)
            }
            imageSection(imageURL: Binding(get: { species.imageURL ?? "" }, set: { species.imageURL = $0 }), imageData: $species.photoData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Collegamenti e sblocco") {
                ReferencePickerUUID(title: "POI collegato", selection: $species.relatedPOIId, options: pois)
                ReferencePickerUUID(title: "Percorso collegato", selection: $species.relatedPathId, options: paths)
                criteriaSection(title: "Criteri sblocco", conditionType: conditionBinding, conditionValue: $species.unlockValue, selectedPOI: $species.relatedPOIId, selectedPath: $species.relatedPathId, selectedEvent: .constant(nil), pois: pois, paths: paths, events: [])
            }
            SpeciesPreviewCard(name: species.name, scientificName: species.scientificName, category: SpeciesCategory(rawValue: species.categoryRawValue)?.title ?? "", rarity: GamificationRarity(rawValue: species.rarityRawValue)?.title ?? "", imageData: previewData ?? species.photoData)
        }
    }

    private var categoryBinding: Binding<SpeciesCategory> {
        Binding(
            get: { SpeciesCategory(rawValue: species.categoryRawValue) ?? .fauna },
            set: { species.categoryRawValue = $0.rawValue }
        )
    }

    private var rarityBinding: Binding<GamificationRarity> {
        Binding(
            get: { GamificationRarity(rawValue: species.rarityRawValue) ?? .common },
            set: { species.rarityRawValue = $0.rawValue }
        )
    }

    private var conditionBinding: Binding<RuleConditionType> {
        Binding(
            get: { RuleConditionType(rawValue: species.unlockConditionRawValue) ?? .none },
            set: { species.unlockConditionRawValue = $0.rawValue }
        )
    }

    private func save() {
        species.needsSync = true
        species.updatedAt = Date()
        Task { @MainActor in
            await onSave()
            dismiss()
        }
    }
}

struct LevelEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var level: GamificationLevel
    let isSaving: Bool
    let onSave: () async -> Void

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    var body: some View {
        DefinitionEditorScaffold(
            title: level.title.isEmpty ? "Nuovo livello" : "Modifica livello",
            canSave: !level.title.isEmpty && level.levelNumber > 0,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Livello") {
                Stepper("Numero livello: \(level.levelNumber)", value: $level.levelNumber, in: 1...99)
                TextField("Titolo narrativo", text: $level.title)
                TextField("Descrizione", text: $level.levelDescription, axis: .vertical)
                    .lineLimit(2...5)
                Stepper("XP richiesti: \(level.requiredXP)", value: $level.requiredXP, in: 0...100000, step: 25)
                Picker("Icona", selection: $level.iconName) {
                    Label("Sigillo", systemImage: "seal.fill").tag("seal.fill")
                    Label("Stella", systemImage: "star.fill").tag("star.fill")
                    Label("Foglia", systemImage: "leaf.fill").tag("leaf.fill")
                    Label("Medaglia", systemImage: "medal.fill").tag("medal.fill")
                }
                Toggle("Attivo", isOn: $level.isActive)
            }
            imageSection(imageURL: Binding(get: { level.imageURL ?? "" }, set: { level.imageURL = $0 }), imageData: $level.photoData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Preview") {
                HStack(spacing: 14) {
                    Image(systemName: level.iconName.isEmpty ? "seal.fill" : level.iconName)
                        .font(.largeTitle)
                        .foregroundColor(Color("WWFGreen"))
                    VStack(alignment: .leading) {
                        Text("Livello \(level.levelNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(level.title.isEmpty ? "Titolo livello" : level.title)
                            .font(.headline)
                        Text("\(level.requiredXP) XP")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func save() {
        level.needsSync = true
        level.updatedAt = Date()
        Task { @MainActor in
            await onSave()
            dismiss()
        }
    }
}

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var rule: GamificationRule
    let badges: [AdminReference]
    let species: [AdminReference]
    let pois: [AdminReference]
    let paths: [AdminReference]
    let events: [AdminReference]
    let isSaving: Bool
    let onSave: () async -> Void

    var body: some View {
        DefinitionEditorScaffold(
            title: rule.title.isEmpty ? "Nuova regola" : "Modifica regola",
            canSave: !rule.title.isEmpty,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Descrizione regola") {
                TextField("Titolo", text: $rule.title)
                TextField("Descrizione", text: $rule.ruleDescription, axis: .vertical)
                    .lineLimit(2...5)
                Toggle("Attiva", isOn: $rule.isActive)
                Toggle("Nascosta", isOn: $rule.isHidden)
                Toggle("Ripetibile", isOn: $rule.isRepeatable)
                Picker("Pubblico", selection: audienceBinding) {
                    ForEach(GamificationAudience.allCases) { Text($0.title).tag($0) }
                }
                Stepper("Priorita: \(rule.priority)", value: $rule.priority, in: -100...100)
            }
            Section("Quando succede") {
                Picker("Trigger", selection: triggerBinding) {
                    ForEach(RuleTriggerType.allCases) { Text($0.title).tag($0) }
                }
                Picker("Condizione", selection: conditionBinding) {
                    ForEach(RuleConditionType.allCases) { Text($0.title).tag($0) }
                }
                conditionFields
            }
            Section("Premio") {
                Stepper("XP: \(rule.xpReward)", value: $rule.xpReward, in: 0...10000, step: 5)
                ReferencePickerUUID(title: "Badge premio", selection: $rule.rewardBadgeId, options: badges)
                ReferencePickerUUID(title: "Specie premio", selection: $rule.rewardSpeciesId, options: species)
                TextField("Titolo profilo", text: $rule.profileTitle)
                TextField("Oggetto collezione", text: $rule.collectionItemKey)
                Toggle("Solo controllo livello", isOn: $rule.levelCheckOnly)
            }
            Section("Finestra e cooldown") {
                Toggle("Usa date attive", isOn: $rule.hasDateRange)
                if rule.hasDateRange {
                    DatePicker("Inizio", selection: $rule.startsAt)
                    DatePicker("Fine", selection: $rule.endsAt)
                }
                Toggle("Usa cooldown", isOn: $rule.hasCooldown)
                if rule.hasCooldown {
                    Stepper("Cooldown: \(rule.cooldownSeconds) sec", value: $rule.cooldownSeconds, in: 0...604800, step: 300)
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

    private var audienceBinding: Binding<GamificationAudience> { Binding(get: { GamificationAudience(rawValue: rule.audienceRawValue) ?? .all }, set: { rule.audienceRawValue = $0.rawValue }) }
    private var triggerBinding: Binding<RuleTriggerType> { Binding(get: { RuleTriggerType(rawValue: rule.triggerTypeRawValue) ?? .poiScanned }, set: { rule.triggerTypeRawValue = $0.rawValue }) }
    private var conditionBinding: Binding<RuleConditionType> { Binding(get: { RuleConditionType(rawValue: rule.conditionTypeRawValue) ?? .none }, set: { rule.conditionTypeRawValue = $0.rawValue }) }

    @ViewBuilder
    private var conditionFields: some View {
        switch conditionBinding.wrappedValue {
        case .none:
            Text("La regola si applica a ogni evento di questo trigger.")
                .font(.caption)
                .foregroundColor(.secondary)
        case .poiCountTotalGTE:
            Stepper("Almeno \(rule.conditionCount) POI", value: $rule.conditionCount, in: 1...500)
        case .path:
            ReferencePickerUUID(title: "Percorso", selection: $rule.conditionPathId, options: paths)
        case .poi:
            ReferencePickerUUID(title: "POI", selection: $rule.conditionPOIId, options: pois)
        case .event:
            ReferencePickerUUID(title: "Evento", selection: $rule.conditionEventId, options: events)
        case .species:
            ReferencePickerUUID(title: "Specie", selection: $rule.conditionSpeciesId, options: species)
        case .completionPercent:
            ReferencePickerUUID(title: "Percorso", selection: $rule.conditionPathId, options: paths)
            Stepper("Completamento: \(rule.requiredCompletionPercent)%", value: $rule.requiredCompletionPercent, in: 1...100)
            Stepper("Durata minima: \(rule.minimumDurationMinutes) min", value: $rule.minimumDurationMinutes, in: 0...240)
            Toggle("Richiedi ordine scansioni", isOn: $rule.requireOrderedScans)
        case .audioPercent:
            Stepper("Ascolto minimo: \(rule.audioPercent)%", value: $rule.audioPercent, in: 1...100)
            ReferencePickerUUID(title: "POI opzionale", selection: $rule.conditionPOIId, options: pois)
        }
    }

    private var rulePreview: String {
        if rule.title.isEmpty { return "Quando \(triggerBinding.wrappedValue.title.lowercased()), assegna il premio configurato." }
        return rule.title
    }

    private var kidsPreview: String {
        "Hai trovato qualcosa di speciale: premio configurato."
    }

    private var easyReadPreview: String {
        "Completa l'attivita. Ricevi: premio configurato."
    }

    private func save() {
        rule.needsSync = true
        rule.updatedAt = Date()
        Task { @MainActor in
            await onSave()
            dismiss()
        }
    }
}

struct CampaignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var campaign: GamificationCampaign
    let rules: [AdminReference]
    let isSaving: Bool
    let onSave: () async -> Void

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewData: Data?

    var body: some View {
        DefinitionEditorScaffold(
            title: campaign.title.isEmpty ? "Nuova campagna" : "Modifica campagna",
            canSave: !campaign.title.isEmpty,
            isSaving: isSaving,
            onSave: save
        ) {
            Section("Campagna") {
                TextField("Titolo", text: $campaign.title)
                TextField("Descrizione", text: $campaign.campaignDescription, axis: .vertical)
                    .lineLimit(3...6)
                DatePicker("Inizio", selection: $campaign.startsAt)
                DatePicker("Fine", selection: $campaign.endsAt)
                Toggle("Attiva", isOn: $campaign.isActive)
            }
            imageSection(imageURL: Binding(get: { campaign.imageURL ?? "" }, set: { campaign.imageURL = $0 }), imageData: $campaign.photoData, selectedImage: $selectedImage, previewData: $previewData)
            Section("Regole incluse") {
                if rules.isEmpty {
                    Text("Crea prima almeno una regola.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(rules) { rule in
                        Toggle(rule.title, isOn: Binding(
                            get: {
                                let arr = (try? JSONSerialization.jsonObject(with: Data(campaign.ruleIdsRaw.utf8))) as? [String] ?? []
                                return arr.contains(rule.id)
                            },
                            set: { selected in
                                var arr = (try? JSONSerialization.jsonObject(with: Data(campaign.ruleIdsRaw.utf8))) as? [String] ?? []
                                if selected {
                                    if !arr.contains(rule.id) { arr.append(rule.id) }
                                } else {
                                    arr.removeAll { $0 == rule.id }
                                }
                                if let data = try? JSONSerialization.data(withJSONObject: arr), let str = String(data: data, encoding: .utf8) {
                                    campaign.ruleIdsRaw = str
                                }
                            }
                        ))
                    }
                }
            }
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(campaign.title.isEmpty ? "Titolo campagna" : campaign.title)
                        .font(.headline)
                    Text(campaign.campaignDescription.isEmpty ? "Descrizione campagna" : campaign.campaignDescription)
                        .font(.caption)
                    Text("\(((try? JSONSerialization.jsonObject(with: Data(campaign.ruleIdsRaw.utf8))) as? [String] ?? []).count) regole collegate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func save() {
        campaign.needsSync = true
        campaign.updatedAt = Date()
        Task { @MainActor in
            await onSave()
            dismiss()
        }
    }
}

struct DefinitionEditorScaffold<Content: View>: View {
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

struct ReferencePickerUUID: View {
    let title: String
    @Binding var selection: UUID?
    let options: [AdminReference]

    var body: some View {
        Picker(title, selection: Binding(
            get: { selection?.uuidString },
            set: { str in selection = str.flatMap { UUID(uuidString: $0) } }
        )) {
            Text("Nessuno").tag(String?.none)
            ForEach(options) { option in
                Text(option.title).tag(Optional(option.id))
            }
        }
        .pickerStyle(.menu)
    }
}

struct BadgePreviewCard: View {
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

struct SpeciesPreviewCard: View {
    let name: String
    let scientificName: String
    let category: String
    let rarity: String
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
                    Text(name.isEmpty ? "Nome specie" : name)
                        .font(.headline)
                    if !scientificName.isEmpty {
                        Text(scientificName)
                            .font(.caption.italic())
                            .foregroundColor(.secondary)
                    }
                    Text("\(category) - \(rarity)")
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
func imageSection(
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
                        return
                    }
                    guard let image = UIImage(data: data) else {
                        return
                    }
                    guard let normalizedData = image.jpegData(compressionQuality: 0.85),
                          !normalizedData.isEmpty else {
                        return
                    }
                    previewData.wrappedValue = normalizedData
                    imageData.wrappedValue = normalizedData
                    imageURL.wrappedValue = ""
                } catch {
                }
            }
        }
        if let data = previewData.wrappedValue ?? imageData.wrappedValue, let image = UIImage(data: data) {
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
func relationSection(
    title: String,
    poiId: Binding<UUID?>,
    pathId: Binding<UUID?>,
    eventId: Binding<UUID?>,
    speciesId: Binding<UUID?>,
    pois: [AdminReference],
    paths: [AdminReference],
    events: [AdminReference],
    species: [AdminReference]
) -> some View {
    Section(title) {
        ReferencePickerUUID(title: "POI collegato", selection: poiId, options: pois)
        ReferencePickerUUID(title: "Percorso collegato", selection: pathId, options: paths)
        ReferencePickerUUID(title: "Evento collegato", selection: eventId, options: events)
        ReferencePickerUUID(title: "Specie collegata", selection: speciesId, options: species)
    }
}

@ViewBuilder
func criteriaSection(
    title: String,
    conditionType: Binding<RuleConditionType>,
    conditionValue: Binding<Int>,
    selectedPOI: Binding<UUID?>,
    selectedPath: Binding<UUID?>,
    selectedEvent: Binding<UUID?>,
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
            ReferencePickerUUID(title: "Percorso", selection: selectedPath, options: paths)
        case .poi, .audioPercent:
            ReferencePickerUUID(title: "POI", selection: selectedPOI, options: pois)
        case .event:
            ReferencePickerUUID(title: "Evento", selection: selectedEvent, options: events)
        case .species:
            Text("Usa una regola per collegare criteri specie specifici.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
