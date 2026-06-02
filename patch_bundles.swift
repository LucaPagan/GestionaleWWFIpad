import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

let oldBundleGen = """
    private func regenerateAndVerifyBundles(for trail: Trail) async throws {
        for tier in ContentTier.allCases {
            _ = try await networkClient.invokeFunction("generate-bundle", body: [
                "path_id": trail.id.uuidString,
                "tier": tier.rawValue
            ])
        }

        let readiness = try await fetchBundleReadiness(pathId: trail.id)
"""

let newBundleGen = """
    private func regenerateAndVerifyBundles(for trail: Trail) async throws {
        print("DEBUG: Regenerating bundles concurrently for \\(trail.id)")
        await withThrowingTaskGroup(of: Void.self) { group in
            for tier in ContentTier.allCases {
                group.addTask {
                    print("DEBUG: Triggering generate-bundle for tier: \\(tier.rawValue)")
                    _ = try? await self.networkClient.invokeFunction("generate-bundle", body: [
                        "path_id": trail.id.uuidString,
                        "tier": tier.rawValue
                    ])
                    print("DEBUG: Finished generate-bundle for tier: \\(tier.rawValue)")
                }
            }
        }
        print("DEBUG: All tiers generated, fetching readiness")

        let readiness = try await fetchBundleReadiness(pathId: trail.id)
"""

if content.contains(oldBundleGen) {
    content = content.replacingOccurrences(of: oldBundleGen, with: newBundleGen)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Patched bundle generation to be concurrent")
} else {
    print("Could not find the bundle generation logic to patch")
}
