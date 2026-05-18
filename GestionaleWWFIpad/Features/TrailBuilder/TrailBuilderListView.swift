import SwiftUI
import SwiftData

struct TrailBuilderListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncManager: SyncManager
    @Query private var trails: [Trail]
    
    var onEdit: (Trail) -> Void

    var body: some View {
        NavigationStack {
            List {
                if trails.isEmpty {
                    Text("Nessun percorso creato.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(trails) { trail in
                        TrailManagerRow(trail: trail)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEdit(trail)
                            }
                    }
                    .onDelete(perform: deleteTrails)
                }
            }
            .navigationTitle("Percorsi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }

    private func deleteTrails(at offsets: IndexSet) {
        let trailsToDelete = offsets.map { trails[$0] }
        Task {
            for trail in trailsToDelete {
                await syncManager.delete(trail, in: context)
            }
        }
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
                Text("\(trail.steps.count) tappe · \(trail.estimatedMinutes ?? 0) min · \(trail.difficulty?.displayName ?? "N/D")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "pencil")
                .foregroundColor(.blue)
        }
    }
}