//
//  TrailBuilderListView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import SwiftData

struct TrailBuilderListView: View {
    @Environment(\.modelContext) private var context
    @Query private var trails: [Trail]
    @State private var showCreateSheet = false
    @State private var selectedTrail: Trail? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(trails) { trail in
                    TrailManagerRow(trail: trail)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTrail = trail }
                }
                .onDelete(perform: deleteTrails)
            }
            .navigationTitle("Percorsi")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                TrailBuilderView(trail: nil)
            }
            .sheet(item: $selectedTrail) { trail in
                TrailBuilderView(trail: trail)
            }
        }
    }

    private func deleteTrails(at offsets: IndexSet) {
        for i in offsets {
            context.delete(trails[i])
        }
        try? context.save()
    }
}

struct TrailManagerRow: View {
    let trail: Trail
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trail.name).fontWeight(.semibold)
                    if trail.isActive {
                        Text("Attivo")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                Text("\(trail.steps.count) tappe · \(trail.estimatedMinutes) min · \(trail.difficulty.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}