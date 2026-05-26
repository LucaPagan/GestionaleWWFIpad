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
    @State private var importTier: ContentTier = .full
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    
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
                if let poi = existingPOI {
                    Section("Contenuti Multimediali (Tiered)") {
                        ForEach(poiContents) { content in
                            HStack {
                                Image(systemName: content.contentType.icon)
                                    .foregroundColor(Color("WWFGreen"))
                                VStack(alignment: .leading) {
                                    Text(content.contentType.displayName)
                                        .font(.subheadline)
                                    Text("Tier: \(content.tier.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if content.needsSync {
                                    Image(systemName: "icloud.and.arrow.up")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        if isUploading {
                            ProgressView("Caricamento e classificazione...")
                        } else {
                            Picker("Tier nuovo contenuto", selection: $importTier) {
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
                    Button("Salva") { savePOI() }
                        .disabled(!isFormValid)
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

    private func loadExistingData() {
        guard let poi = existingPOI else { return }
        name = poi.name
        description = poi.poiDescription
        descriptionKids = poi.descriptionKids ?? ""
        descriptionEasyRead = poi.descriptionEasyRead ?? ""
        type = poi.type
        photoData = poi.photoData
        isStartPoint = poi.isStartPoint
    }

    private func savePOI() {
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
                descriptionEasyRead: descriptionEasyRead.isEmpty ? nil : descriptionEasyRead
            )
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
            poi.needsSync = true
            poi.updatedAt = Date()
            onSave(poi)
        }
    }

    @MainActor
    private func processAndUploadMedia(_ items: [PhotosPickerItem], for poi: POI) async {
        isUploading = true
        defer { isUploading = false; selectedMedia = [] }
        
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let contentType: ContentType = item.supportedContentTypes.contains(.video) ? .video : .image
            
            let classifiedTier = MediaClassificationService.shared.classify(type: contentType, sizeInBytes: data.count)
            let tier = importTier.rawValue == ContentTier.full.rawValue ? classifiedTier : importTier
            
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
