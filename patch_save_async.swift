import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Features/MapEditor/MapEditorView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// Dobbiamo sostituire la funzione `saveTrail()` con una versione full async
let searchStart = "private func saveTrail() {"
let searchEnd = "    // MARK: - POI Logic"

if let startRange = content.range(of: searchStart),
   let endRange = content.range(of: searchEnd) {
    
    let replacement = """
    private func saveTrail() {
        let issues = currentTrailIssues
        if issues.contains(where: { $0.severity == .error }) {
            adminErrorMessage = issues.map(\\.message).joined(separator: "\\n")
            return
        }

        print("DEBUG: saveTrail started")
        tbIsSyncing = true
        
        Task { @MainActor in
            // Lasciamo un istante al Main Thread per aggiornare la UI e mostrare il ProgressView
            try? await Task.sleep(for: .milliseconds(100))
            
            print("DEBUG: Starting SwiftData updates")
            let target = mapMode.trail ?? Trail(name: "", description: "")
            target.name = tbName
            target.trailDescription = tbDescription
            target.difficulty = tbDifficulty
            target.estimatedMinutes = tbEstimatedMinutes
            target.isActive = tbIsActive
            target.targetAge = tbTargetAge
            target.descriptionKids = tbDescriptionKids
            target.descriptionEasyRead = tbDescriptionEasyRead
            target.startPOIId = tbSelectedStartPOI?.id
            target.needsSync = true
            target.updatedAt = Date()

            // Safely update existing steps to prevent SwiftData relationship thrashing/deadlocks
            for (i, draft) in tbSteps.enumerated() {
                if i < target.steps.count {
                    let s = target.steps[i]
                    s.stepOrder = i
                    s.directionHint = draft.instructions
                    s.distanceMeters = draft.distanceMeters
                    s.estimatedMinutes = draft.estimatedMinutes
                    s.pathGeometry = draft.pathGeometry
                    s.poi = draft.poi
                } else {
                    let s = TrailStep(
                        stepOrder: i,
                        directionHint: draft.instructions,
                        distanceMeters: draft.distanceMeters,
                        estimatedMinutes: draft.estimatedMinutes,
                        pathGeometry: draft.pathGeometry,
                        poi: draft.poi
                    )
                    context.insert(s)
                    target.steps.append(s)
                }
            }
            
            if target.steps.count > tbSteps.count {
                let excess = Array(target.steps[tbSteps.count...])
                for s in excess {
                    context.delete(s)
                }
                target.steps.removeLast(target.steps.count - tbSteps.count)
            }

            if mapMode.trail == nil { context.insert(target) }
            
            print("DEBUG: context.save() called")
            do {
                try context.save()
                print("DEBUG: context.save() finished")
            } catch {
                print("DEBUG: context.save() FAILED with error: \\(error)")
            }

            // Give SwiftData's persistent store a moment to write the WAL before the background context fetches it.
            try? await Task.sleep(for: .milliseconds(500))
            
            print("DEBUG: About to call syncManager.pushAllChanges()")
            await syncManager.pushAllChanges()
            print("DEBUG: Returned from syncManager.pushAllChanges()")
            
            tbIsSyncing = false
            if case .error(let message) = syncManager.syncState {
                adminErrorMessage = message
            } else {
                closeTrailBuilder()
            }
        }
    }

"""
    
    let oldCodeRange = startRange.lowerBound..<endRange.lowerBound
    content.replaceSubrange(oldCodeRange, with: replacement)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Patched saveTrail to be async and well-logged")
} else {
    print("Failed to find ranges")
}
