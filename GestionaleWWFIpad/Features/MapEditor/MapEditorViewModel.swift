//
//  MapEditorViewModel.swift
//  GestionaleWWFIpad
//

import SwiftUI
import SwiftData
import Combine
import OSLog

@MainActor
final class MapEditorViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Dependencies iniettate
    private let syncManager: SyncManager
    private let modelContext: ModelContext
    
    init(syncManager: SyncManager, modelContext: ModelContext) {
        self.syncManager = syncManager
        self.modelContext = modelContext
    }
    
    func saveNewPOI(name: String, desc: String, x: Double, y: Double, type: POIType) async {
        isLoading = true
        defer { isLoading = false }
        
        let newPOI = POI(name: name, description: desc, x: x, y: y, type: type)
        modelContext.insert(newPOI)
        
        do {
            try modelContext.save()
            // Forziamo la sync immediata
            await syncManager.pushAllChanges()
        } catch {
            errorMessage = "Errore durante il salvataggio: \(error.localizedDescription)"
        }
    }
}
