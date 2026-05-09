//
//  ManagerSettingsView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

struct ManagerSettingsView: View {
    @EnvironmentObject var managerSession: ManagerSession
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
                            Text("gestore@wwf.it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("App") {
                    LabeledContent("Versione", value: "1.0.0 (prototipo)")
                    LabeledContent("Oasi", value: "Astroni, Napoli")
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
}