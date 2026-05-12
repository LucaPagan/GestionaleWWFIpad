//
//  EventBuilderViewModel.swift
//  GestionaleWWFIpad
//

import SwiftUI
import SwiftData
import Combine

@MainActor
final class EventBuilderViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let syncManager: SyncManager
    private let modelContext: ModelContext
    
    init(syncManager: SyncManager, modelContext: ModelContext) {
        self.syncManager = syncManager
        self.modelContext = modelContext
    }
    
    func saveEvent(name: String, description: String, category: EventCategory, date: Date, startTime: Date, endTime: Date) async {
        isLoading = true
        defer { isLoading = false }
        
        let event = Event(name: name, description: description, category: category, date: date, startTime: startTime, endTime: endTime)
        modelContext.insert(event)
        
        do {
            try modelContext.save()
            await syncManager.pushAllChanges()
        } catch {
            errorMessage = "Errore durante il salvataggio dell'evento: \(error.localizedDescription)"
        }
    }
}
