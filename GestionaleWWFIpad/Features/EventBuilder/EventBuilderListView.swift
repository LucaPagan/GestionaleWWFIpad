//
//  EventBuilderListView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//

import SwiftUI
import SwiftData

struct EventBuilderListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Event.date, order: .forward) private var events: [Event]
    @EnvironmentObject private var syncManager: SyncManager
    @State private var showCreateSheet = false
    @State private var selectedEvent: Event? = nil

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "Nessun evento",
                        systemImage: "calendar.badge.plus",
                        description: Text("Crea il tuo primo evento per i visitatori dell'Oasi.")
                    )
                } else {
                    List {
                        // Eventi futuri
                        let upcoming = events.filter { $0.isUpcoming }
                        if !upcoming.isEmpty {
                            Section("Prossimi eventi") {
                                ForEach(upcoming) { event in
                                    EventManagerRow(event: event)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedEvent = event }
                                }
                                .onDelete { offsets in
                                    deleteEvents(from: upcoming, at: offsets)
                                }
                            }
                        }

                        // Eventi passati
                        let past = events.filter { !$0.isUpcoming }
                        if !past.isEmpty {
                            Section("Eventi passati") {
                                ForEach(past) { event in
                                    EventManagerRow(event: event)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedEvent = event }
                                        .opacity(0.6)
                                }
                                .onDelete { offsets in
                                    deleteEvents(from: past, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Eventi")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !events.isEmpty { EditButton() }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                EventBuilderView(event: nil)
            }
            .sheet(item: $selectedEvent) { event in
                EventBuilderView(event: event)
            }
        }
    }

    private func deleteEvents(from source: [Event], at offsets: IndexSet) {
        let eventsToDelete = offsets.map { source[$0] }
        Task {
            for event in eventsToDelete {
                await syncManager.delete(event, in: context)
            }
        }
    }
}

// MARK: - Event Row per il Manager

struct EventManagerRow: View {
    let event: Event

    var categoryColor: Color {
        event.category.color
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icona categoria
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: event.category.icon)
                    .font(.body)
                    .foregroundColor(categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if event.isActive {
                        Text("Attivo")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }

                    if event.isToday {
                        Text("Oggi")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Label(event.formattedDate, systemImage: "calendar")
                    Text("·")
                    Label(event.formattedTimeRange, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
