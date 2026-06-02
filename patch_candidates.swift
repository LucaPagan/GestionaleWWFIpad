import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

let oldLoop = """
        for trail in dirtyTrails {
            print("DEBUG: Syncing trail \\(trail.id)")
            try await syncTrailWithPublishGate(trail)
            changedCount += 1
            if trail.isActive { bundleCandidates.insert(trail.id) }
        }

        print("DEBUG: Starting bundle candidates \\(bundleCandidates.count)")
        for trailId in bundleCandidates {
"""

let newLoop = """
        var syncedTrails = Set<UUID>()
        for trail in dirtyTrails {
            print("DEBUG: Syncing trail \\(trail.id)")
            try await syncTrailWithPublishGate(trail)
            syncedTrails.insert(trail.id)
            changedCount += 1
            if trail.isActive { bundleCandidates.insert(trail.id) }
        }

        bundleCandidates.subtract(syncedTrails)
        print("DEBUG: Starting bundle candidates \\(bundleCandidates.count)")
        for trailId in bundleCandidates {
"""

if content.contains(oldLoop) {
    content = content.replacingOccurrences(of: oldLoop, with: newLoop)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Patched bundle candidates duplicate regeneration")
} else {
    print("Could not find the loop to patch")
}
