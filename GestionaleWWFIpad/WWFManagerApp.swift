import SwiftUI
import SwiftData

@main
struct WWFManagerApp: App { // <-- Questo nome dipenderà da come hai chiamato il nuovo progetto Xcode
    let container: ModelContainer

    init() {
        do {
            // Configurazione con migrazione automatica abilitata per gli stessi modelli
            let schema = Schema([Trail.self, POI.self, TrailStep.self, Event.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Se la migrazione fallisce, cancella lo store e riparte pulito
            Self.deleteStore()
            do {
                let schema = Schema([Trail.self, POI.self, TrailStep.self, Event.self])
                let config = ModelConfiguration(schema: schema)
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData container failed anche dopo reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ManagerRootView() // <-- Parte subito col pannello manager
                .modelContainer(container)
        }
    }

    // Cancella il file .store dal disco in caso di errori di migrazione
    private static func deleteStore() {
        let urls = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let base = urls.first else { return }

        let storeFiles = [
            "default.store",
            "default.store-shm",
            "default.store-wal"
        ]
        for file in storeFiles {
            let url = base.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
