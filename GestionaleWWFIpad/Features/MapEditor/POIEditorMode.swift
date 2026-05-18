//
//  POIEditorMode.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import PhotosUI
import SwiftData

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
        !description.trimmingCharacters(in: .whitespaces).isEmpty
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
                            PhotosPicker(selection: $selectedMedia, matching: .any(of: [.images, .videos])) {
                                Label("Aggiungi Foto/Video", systemImage: "plus.circle")
                                    .foregroundColor(Color("WWFGreen"))
                            }
                        }
                    }
                    .onChange(of: selectedMedia) { _, items in
                        Task {
                            await processAndUploadMedia(items, for: poi)
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
        }
    }

    // MARK: - Helpers

    private func loadExistingData() {
        guard let poi = existingPOI else { return }
        name = poi.name
        description = poi.poiDescription
        type = poi.type
        photoData = poi.photoData
        isStartPoint = poi.isStartPoint
    }

    private func savePOI() {
        switch mode {
        case .create(let x, let y):
            let poi = POI(name: name, description: description, x: x, y: y, type: type, photoData: photoData, isStartPoint: isStartPoint)
            poi.needsSync = true
            onSave(poi)
        case .edit(let poi):
            poi.name = name
            poi.poiDescription = description
            poi.type = type
            poi.photoData = photoData
            poi.isStartPoint = isStartPoint
            poi.needsSync = true
            poi.updatedAt = Date()
            onSave(poi)
        }
    }

    private func processAndUploadMedia(_ items: [PhotosPickerItem], for poi: POI) async {
        isUploading = true
        defer { isUploading = false; selectedMedia = [] }
        
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let contentType: ContentType = item.supportedContentTypes.contains(.video) ? .video : .image
            
            let tier = MediaClassificationService.shared.classify(type: contentType, sizeInBytes: data.count)
            
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
                print("Failed to upload/save content: \(error)")
            }
        }
    }
}