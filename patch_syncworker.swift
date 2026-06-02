import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

let oldGateLogic = """
        if desiredActive {
            trail.isActive = false
            try await pushTrail(trail)
            print("DEBUG: Generating bundles for \\(trail.id)"); try await regenerateAndVerifyBundles(for: trail); print("DEBUG: Finished generating bundles for \\(trail.id)")
            trail.isActive = true
            try await pushTrail(trail)
            print("DEBUG: Generating bundles for \\(trail.id)"); try await regenerateAndVerifyBundles(for: trail); print("DEBUG: Finished generating bundles for \\(trail.id)")
        } else {
            try await pushTrail(trail)
        }
"""

let newGateLogic = """
        if desiredActive {
            trail.isActive = false
            try await pushTrail(trail)
            trail.isActive = true
            try await pushTrail(trail)
        } else {
            try await pushTrail(trail)
        }
"""

if content.contains(oldGateLogic) {
    content = content.replacingOccurrences(of: oldGateLogic, with: newGateLogic)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Patched duplicate bundle generation")
} else {
    // Maybe they had original code without prints
    let fallbackLogic = """
        if desiredActive {
            trail.isActive = false
            try await pushTrail(trail)
            try await regenerateAndVerifyBundles(for: trail)
            trail.isActive = true
            try await pushTrail(trail)
            try await regenerateAndVerifyBundles(for: trail)
        } else {
            try await pushTrail(trail)
        }
"""
    if content.contains(fallbackLogic) {
        content = content.replacingOccurrences(of: fallbackLogic, with: newGateLogic)
        try! content.write(toFile: path, atomically: true, encoding: .utf8)
        print("Patched duplicate bundle generation (fallback)")
    } else {
        print("Could not find the publish gate logic to patch")
    }
}

