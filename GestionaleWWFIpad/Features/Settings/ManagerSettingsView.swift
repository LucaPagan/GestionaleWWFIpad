//
//  ManagerSettingsView.swift
//  GestionaleWWFIpad
//
//  Created by Luca Pagano on 06/05/26.
//  Updated: Sync status, Supabase Auth integration
//

import SwiftUI

struct ManagerSettingsView: View {
    @EnvironmentObject var managerSession: ManagerSession
    @EnvironmentObject var syncManager: SyncManager
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color("WWFGreen"))
                        VStack(alignment: .leading) {
                            Text("Gestore WWF")
                                .fontWeight(.semibold)
                            Text(managerSession.adminEmail ?? "Offline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: Sync Status
                Section("Sincronizzazione") {
                    HStack {
                        syncStatusIcon
                        VStack(alignment: .leading, spacing: 2) {
                            syncStatusText
                            if let lastSync = syncManager.lastSyncDate {
                                Text("Ultimo sync: \(lastSync, format: .dateTime)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if syncManager.pendingChanges > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Text("\(syncManager.pendingChanges) modifiche in attesa")
                                .font(.caption)
                        }
                    }

                    // Manual sync buttons removed as sync is now handled automatically in the background by SyncManager
                }

                Section("App") {
                    LabeledContent("Versione", value: "1.0.0")
                    LabeledContent("Oasi", value: "Astroni, Napoli")
                    LabeledContent("Backend", value: "Supabase (eu-central-1)")
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Esci dall'area gestori", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .confirmationDialog(
                "Uscire dall'area gestori?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Esci", role: .destructive) {
                    managerSession.logout()
                }
                Button("Annulla", role: .cancel) {}
            }
        }
    }

    // MARK: - Sync Status Helpers

    @ViewBuilder
    private var syncStatusIcon: some View {
        switch syncManager.syncState {
        case .idle:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .syncing:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var syncStatusText: some View {
        switch syncManager.syncState {
        case .idle:
            Text("Sincronizzato")
                .font(.subheadline)
        case .syncing(let entity):
            Text("Sincronizzazione \(entity)...")
                .font(.subheadline)
                .foregroundColor(.orange)
        case .success(let count):
            Text("\(count) elementi sincronizzati")
                .font(.subheadline)
                .foregroundColor(.green)
        case .error(let message):
            Text("Errore: \(message)")
                .font(.subheadline)
                .foregroundColor(.red)
        }
    }
}