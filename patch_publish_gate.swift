import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

let buggyGateLogic = """
        if desiredActive {
            trail.isActive = false
            try await pushTrail(trail)
            trail.isActive = true
            try await pushTrail(trail)
        } else {
            try await pushTrail(trail)
        }
"""

let correctGateLogic = """
        if desiredActive {
            // STEP 1: Salva come bozza (isActive = false) per superare i controlli del database
            // che impediscono di aggiornare un percorso pubblicato se i bundle sono obsoleti.
            trail.isActive = false
            try await pushTrail(trail)
            
            // STEP 2: Genera i bundle per i dati appena salvati in bozza.
            print("DEBUG: Generating initial bundles for \\(trail.id)")
            try await regenerateAndVerifyBundles(for: trail)
            
            // STEP 3: Ora che i bundle sono pronti, possiamo pubblicare ufficialmente il percorso.
            trail.isActive = true
            try await pushTrail(trail)
            
            // STEP 4: Rigenera i bundle un'ultima volta per includere il nuovo stato "isActive = true" nel JSON.
            print("DEBUG: Generating final bundles for \\(trail.id)")
            try await regenerateAndVerifyBundles(for: trail)
        } else {
            try await pushTrail(trail)
        }
"""

if content.contains(buggyGateLogic) {
    content = content.replacingOccurrences(of: buggyGateLogic, with: correctGateLogic)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Restored correct Publish Gate logic with comments")
} else {
    print("Could not find buggy publish gate logic")
}
