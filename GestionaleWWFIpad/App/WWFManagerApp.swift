import SwiftUI
import SwiftData

@main
struct WWFManagerApp: App {
    let container: ModelContainer
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var managerSession = ManagerSession()

    init() {
        do {
            let schema = Schema([Trail.self, POI.self, TrailStep.self, Event.self, Content.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // If migration fails, reset the store and start fresh
            Self.deleteStore()
            do {
                let schema = Schema([Trail.self, POI.self, TrailStep.self, Event.self, Content.self])
                let config = ModelConfiguration(schema: schema)
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData container failed anche dopo reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if managerSession.isLoggedIn {
                    ManagerRootView()
                } else {
                    ManagerLoginView()
                }
            }
            .modelContainer(container)
            .environmentObject(syncManager)
            .environmentObject(managerSession)
            .onAppear {
                // Configure SyncManager with the model context
                syncManager.configure(with: container.mainContext)

                // Seed local data if first launch
                DataService.seedIfNeeded(context: container.mainContext)

                // Try to restore previous session
                managerSession.restoreSession()
                
                // Automatically push any pending offline changes if logged in
                Task {
                    if managerSession.isLoggedIn {
                        await syncManager.pushAllChanges()
                    } else {
                        await syncManager.pullLatestData()
                    }
                }
            }
        }
    }

    // Deletes the SwiftData store files from disk in case of migration errors
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
