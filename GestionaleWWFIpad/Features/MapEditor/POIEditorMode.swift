//
//  POIEditorMode.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers

enum POIEditorMode {
    case create(x: Double, y: Double)
    case edit(POI)
}

struct POIEditorView: View {
    let mode: POIEditorMode
    let onSave: (POI) -> Void
    let onDelete: ((POI) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var descriptionKids: String = ""
    @State private var descriptionEasyRead: String = ""
    @State private var type: POIType = .landmark
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var showDeleteConfirm = false
    @State private var showQR = false
    @State private var isStartPoint = false
    
    // Multimedia
    @Query private var allContents: [Content]
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var importContentType: ContentType = .audio
    @State private var importTier: ContentTier = .light
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var showARFileImporter = false
    @State private var pendingARModelData: Data?
    @State private var pendingARModelFileName: String?
    @State private var arModelURL: String = ""
    @State private var arModelTier: ContentTier = .full
    @State private var arConfig: ARAnimationConfig = .default
    @State private var shouldClearARModel = false
    
    private var poiContents: [Content] {
        guard let poi = existingPOI else { return [] }
        return allContents.filter { $0.poiId == poi.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var existingPOI: POI? {
        if case .edit(let p) = mode { return p }
        return nil
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        validationIssues.isEmpty
    }

    var validationIssues: [AdminValidationIssue] {
        var issues: [AdminValidationIssue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, message: "POI: nome mancante."))
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, message: "POI: descrizione mancante."))
        }

        let coordinates: (x: Double, y: Double)
        switch mode {
        case .create(let x, let y):
            coordinates = (x, y)
        case .edit(let poi):
            coordinates = (poi.x, poi.y)
            if poi.qrPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(severity: .error, message: "POI: QR payload mancante."))
            }
            if poi.numericCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(severity: .error, message: "POI: codice numerico mancante."))
            }
        }

        if coordinates.x < 0 || coordinates.y < 0 || !coordinates.x.isFinite || !coordinates.y.isFinite {
            issues.append(.init(severity: .error, message: "POI: coordinate mappa non valide."))
        }
        return issues
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Sezione info base
                Section("Informazioni") {
                    TextField("Nome del punto", text: $name)
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Descrizione per i visitatori...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                }

                Section("Testi Semplificati (Opzionali)") {
                    ZStack(alignment: .topLeading) {
                        if descriptionKids.isEmpty {
                            Text("Descrizione per Bambini...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $descriptionKids)
                            .frame(minHeight: 60)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if descriptionEasyRead.isEmpty {
                            Text("Descrizione Alta Comprensione...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $descriptionEasyRead)
                            .frame(minHeight: 60)
                    }
                }

                // MARK: Tipo
                Section("Tipo di punto") {
                    Picker("Tipo", selection: $type) {
                        ForEach(POIType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Punto di partenza", isOn: $isStartPoint)
                        .tint(Color("WWFGreen"))
                }

                // MARK: Foto
                Section("Foto (opzionale)") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                                .foregroundColor(Color("WWFGreen"))
                            Text(photoData == nil ? "Aggiungi foto" : "Cambia foto")
                        }
                    }
                    if let data = photoData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // MARK: Multimedia & Tiering
                Section("Realtà Aumentata") {
                    HStack {
                        Label("Modello 3D USDZ", systemImage: "arkit")
                        Spacer()
                        if !arModelURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("WWFGreen"))
                        }
                    }

                    if let fileName = pendingARModelFileName {
                        Text(fileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !arModelURL.isEmpty {
                        Text(arModelURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    Button {
                        showARFileImporter = true
                    } label: {
                        Label(arModelURL.isEmpty ? "Carica modello AR" : "Sostituisci modello AR", systemImage: "square.and.arrow.up")
                            .foregroundColor(Color("WWFGreen"))
                    }

                    Picker("Banda modello AR", selection: $arModelTier) {
                        ForEach(ContentTier.allCases, id: \.self) { tier in
                            Text(tier.displayName).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)

                    if !arModelURL.isEmpty || pendingARModelData != nil {
                        Button(role: .destructive) {
                            arModelURL = ""
                            pendingARModelData = nil
                            pendingARModelFileName = nil
                            shouldClearARModel = true
                        } label: {
                            Label("Rimuovi modello AR", systemImage: "trash")
                        }
                    }

                    Toggle("Rotazione continua", isOn: $arConfig.rotationEnabled)
                    Toggle("Fluttuazione verticale", isOn: $arConfig.floatingEnabled)
                    Toggle("Pulsazione scala", isOn: $arConfig.pulseEnabled)

                    VStack(alignment: .leading) {
                        Text("Velocità: \(arConfig.speed, specifier: "%.1f")x")
                            .font(.caption)
                        Slider(value: $arConfig.speed, in: 0.2...3.0, step: 0.1)
                    }

                    VStack(alignment: .leading) {
                        Text("Ampiezza fluttuazione: \(Int(arConfig.floatAmplitude * 100)) cm")
                            .font(.caption)
                        Slider(value: $arConfig.floatAmplitude, in: 0.02...0.25, step: 0.01)
                    }

                    VStack(alignment: .leading) {
                        Text("Scala pulsazione: \(arConfig.pulseScale, specifier: "%.2f")x")
                            .font(.caption)
                        Slider(value: $arConfig.pulseScale, in: 1.01...1.3, step: 0.01)
                    }
                }
                .fileImporter(
                    isPresented: $showARFileImporter,
                    allowedContentTypes: [UTType(filenameExtension: "usdz") ?? .data],
                    allowsMultipleSelection: false
                ) { result in
                    importARModel(result)
                }

                if let poi = existingPOI {
                    Section("Contenuti Multimediali (Tiered)") {
                        ForEach(poiContents) { content in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: content.contentType.icon)
                                        .foregroundColor(Color("WWFGreen"))
                                    VStack(alignment: .leading) {
                                        Text(content.contentType.displayName)
                                            .font(.subheadline)
                                        Text(content.fileURL ?? "Contenuto locale")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    if content.needsSync {
                                        Image(systemName: "icloud.and.arrow.up")
                                            .foregroundColor(.orange)
                                    }
                                }

                                Picker("Banda contenuto", selection: tierBinding(for: content)) {
                                    ForEach(ContentTier.allCases, id: \.self) { tier in
                                        Text(tier.displayName).tag(tier)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        if isUploading {
                            ProgressView("Caricamento e classificazione...")
                        } else {
                            Picker("Banda nuovo contenuto", selection: $importTier) {
                                ForEach(ContentTier.allCases, id: \.self) { tier in
                                    Text(tier.displayName).tag(tier)
                                }
                            }
                            .pickerStyle(.segmented)

                            PhotosPicker(selection: $selectedMedia, matching: .any(of: [.images, .videos])) {
                                Label("Aggiungi Foto/Video", systemImage: "plus.circle")
                                    .foregroundColor(Color("WWFGreen"))
                            }

                            Picker("Tipo file", selection: $importContentType) {
                                Text("Audio").tag(ContentType.audio)
                                Text("Modello 3D").tag(ContentType.model3d)
                            }
                            .pickerStyle(.segmented)

                            Button {
                                showFileImporter = true
                            } label: {
                                Label("Aggiungi Audio/3D", systemImage: "square.and.arrow.up")
                                    .foregroundColor(Color("WWFGreen"))
                            }
                        }
                    }
                    .onChange(of: selectedMedia) { _, items in
                        Task {
                            await processAndUploadMedia(items, for: poi)
                        }
                    }
                    .fileImporter(
                        isPresented: $showFileImporter,
                        allowedContentTypes: importContentType == .audio ? [.audio] : [UTType(filenameExtension: "usdz") ?? .data, .item],
                        allowsMultipleSelection: false
                    ) { result in
                        Task { await importFile(result, for: poi) }
                    }
                }

                if !validationIssues.isEmpty {
                    Section("Controlli") {
                        ForEach(validationIssues) { issue in
                            Label(issue.message, systemImage: "xmark.octagon.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // MARK: QR code (solo in edit)
                if let poi = existingPOI {
                    Section("QR Code") {
                        Button {
                            showQR = true
                        } label: {
                            Label("Visualizza QR da stampare", systemImage: "qrcode")
                                .foregroundColor(Color("WWFGreen"))
                        }
                        Text(poi.qrPayload)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // MARK: Elimina (solo in edit)
                if existingPOI != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Elimina punto di interesse", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existingPOI == nil ? "Nuovo POI" : "Modifica POI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task { await savePOI() }
                    }
                    .disabled(!isFormValid || isUploading)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear { loadExistingData() }
            .confirmationDialog(
                "Eliminare questo punto di interesse?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Elimina", role: .destructive) {
                    if let poi = existingPOI { onDelete?(poi) }
                }
                Button("Annulla", role: .cancel) {}
            }
            .sheet(isPresented: $showQR) {
                if let poi = existingPOI {
                    QRDisplayView(poi: poi)
                }
            }
            .alert("Errore contenuto", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Helpers

    private func tierBinding(for content: Content) -> Binding<ContentTier> {
        Binding(
            get: { content.tier },
            set: { newTier in
                guard content.tier != newTier else { return }
                content.tier = newTier
                content.needsSync = true
                content.updatedAt = Date()
                try? modelContext.save()
                Task {
                    await SyncManager.shared.pushAllChanges()
                }
            }
        )
    }

    private func loadExistingData() {
        guard let poi = existingPOI else { return }
        name = poi.name
        description = poi.poiDescription
        descriptionKids = poi.descriptionKids ?? ""
        descriptionEasyRead = poi.descriptionEasyRead ?? ""
        type = poi.type
        photoData = poi.photoData
        isStartPoint = poi.isStartPoint
        arModelURL = poi.arModelURL ?? ""
        arModelTier = poi.arModelTier
        arConfig = ARAnimationConfig.decode(from: poi.arAnimationConfig)
        shouldClearARModel = false
    }

    @MainActor
    private func savePOI() async {
        if !validationIssues.isEmpty {
            errorMessage = validationIssues.map(\.message).joined(separator: "\n")
            return
        }

        switch mode {
        case .create(let x, let y):
            let poi = POI(
                name: name,
                description: description,
                x: x,
                y: y,
                type: type,
                photoData: photoData,
                isStartPoint: isStartPoint,
                descriptionKids: descriptionKids.isEmpty ? nil : descriptionKids,
                descriptionEasyRead: descriptionEasyRead.isEmpty ? nil : descriptionEasyRead,
                arModelURL: arModelURL.isEmpty ? nil : arModelURL,
                arAnimationConfig: arConfig.jsonString,
                arModelTier: arModelTier
            )
            do {
                try await uploadPendingARModelIfNeeded(for: poi)
            } catch {
                errorMessage = "Upload modello AR non riuscito: \(error.localizedDescription)"
                return
            }
            poi.needsSync = true
            onSave(poi)
        case .edit(let poi):
            poi.name = name
            poi.poiDescription = description
            poi.descriptionKids = descriptionKids.isEmpty ? nil : descriptionKids
            poi.descriptionEasyRead = descriptionEasyRead.isEmpty ? nil : descriptionEasyRead
            poi.type = type
            poi.photoData = photoData
            poi.isStartPoint = isStartPoint
            poi.arModelURL = arModelURL.isEmpty ? nil : arModelURL
            poi.arAnimationConfig = arConfig.jsonString
            poi.arModelTier = arModelTier
            poi.shouldClearARModel = shouldClearARModel && pendingARModelData == nil
            do {
                try await uploadPendingARModelIfNeeded(for: poi)
            } catch {
                errorMessage = "Upload modello AR non riuscito: \(error.localizedDescription)"
                return
            }
            poi.needsSync = true
            poi.updatedAt = Date()
            onSave(poi)
        }
    }

    private func importARModel(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            if case let .failure(error) = result {
                errorMessage = "Import modello AR non riuscito: \(error.localizedDescription)"
            }
            return
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            guard url.pathExtension.lowercased() == "usdz" else {
                errorMessage = "Seleziona un file in formato .usdz."
                return
            }
            pendingARModelData = try Data(contentsOf: url)
            pendingARModelFileName = url.lastPathComponent
        } catch {
            errorMessage = "Lettura modello AR non riuscita: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func uploadPendingARModelIfNeeded(for poi: POI) async throws {
        guard let data = pendingARModelData else { return }
        let fileName = pendingARModelFileName ?? "\(UUID().uuidString).usdz"

        isUploading = true
        defer { isUploading = false }

        let safeFileName = sanitizedARFileName(fileName)
        poi.arModelTier = arModelTier
        let path = "pois/\(poi.id.uuidString)/\(arModelTier.rawValue)/ar/\(safeFileName)"
        let remoteURL = try await StorageManager.shared.upload(
            data: data,
            path: path,
            bucket: "poi-multimedia",
            contentType: "model/vnd.usdz+zip"
        )
        poi.arModelURL = remoteURL
        poi.arAnimationConfig = arConfig.jsonString
        poi.shouldClearARModel = false
        pendingARModelData = nil
        pendingARModelFileName = nil
        shouldClearARModel = false
        arModelURL = remoteURL
    }

    private func sanitizedARFileName(_ fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let sanitized = fileName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let result = String(sanitized)
        return result.lowercased().hasSuffix(".usdz") ? result : "\(result).usdz"
    }

    @MainActor
    private func processAndUploadMedia(_ items: [PhotosPickerItem], for poi: POI) async {
        isUploading = true
        defer { isUploading = false; selectedMedia = [] }
        
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let contentType: ContentType = item.supportedContentTypes.contains(.video) ? .video : .image
            
            let tier = importTier
            
            let ext = contentType == .video ? "mp4" : "jpg"
            let fileName = "\(UUID().uuidString).\(ext)"
            let path = "pois/\(poi.id.uuidString)/\(tier.rawValue)/\(fileName)"
            
            do {
                let url = try await StorageManager.shared.upload(
                    data: data,
                    path: path,
                    bucket: "poi-multimedia",
                    contentType: contentType == .video ? "video/mp4" : "image/jpeg"
                )
                
                let newContent = Content(
                    poiId: poi.id,
                    type: contentType,
                    tier: tier,
                    fileURL: url,
                    sortOrder: poiContents.count
                )
                
                modelContext.insert(newContent)
                try? modelContext.save()
                
                // Trigger background sync for the new content metadata
                Task {
                    await SyncManager.shared.pushAllChanges()
                }
            } catch {
                errorMessage = "Upload contenuto non riuscito: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func importFile(_ result: Result<[URL], Error>, for poi: POI) async {
        guard case let .success(urls) = result, let url = urls.first else {
            if case let .failure(error) = result {
                errorMessage = "Import file non riuscito: \(error.localizedDescription)"
            }
            return
        }

        isUploading = true
        defer { isUploading = false }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.isEmpty ? importContentType.defaultFileExtension : url.pathExtension
            let fileName = "\(UUID().uuidString).\(ext)"
            let path = "pois/\(poi.id.uuidString)/\(importTier.rawValue)/\(fileName)"
            let mimeType = mimeTypeForImportedFile(url: url, contentType: importContentType)

            let remoteURL = try await StorageManager.shared.upload(
                data: data,
                path: path,
                bucket: "poi-multimedia",
                contentType: mimeType
            )

            let content = Content(
                poiId: poi.id,
                type: importContentType,
                tier: importTier,
                fileURL: remoteURL,
                sortOrder: poiContents.count
            )

            let issues = AdminValidationService.contentIssues(content)
            guard !issues.contains(where: { $0.severity == .error }) else {
                errorMessage = issues.map(\.message).joined(separator: "\n")
                return
            }

            modelContext.insert(content)
            try modelContext.save()
            await SyncManager.shared.pushAllChanges()
        } catch {
            errorMessage = "Upload contenuto non riuscito: \(error.localizedDescription)"
        }
    }

    private func mimeTypeForImportedFile(url: URL, contentType: ContentType) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return contentType.defaultMimeType
    }
}
