import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(of: "syncState = .syncing(entity: \"Dati in background\")", with: "print(\"DEBUG: Starting pushAllChanges\"); syncState = .syncing(entity: \"Dati in background\")")
content = content.replacingOccurrences(of: "let pushedCount = try await worker.performPush()", with: "print(\"DEBUG: Calling performPush\"); let pushedCount = try await worker.performPush(); print(\"DEBUG: performPush finished, pushed: \\(pushedCount)\")")
content = content.replacingOccurrences(of: "let pulledCount = try await worker.performPull()", with: "print(\"DEBUG: Calling performPull\"); let pulledCount = try await worker.performPull(); print(\"DEBUG: performPull finished, pulled: \\(pulledCount)\")")

content = content.replacingOccurrences(of: "func performPush() async throws -> Int {", with: """
    func performPush() async throws -> Int {
        print("DEBUG: performPush started")
""")

content = content.replacingOccurrences(of: "try removeDuplicatePOIs()", with: "print(\"DEBUG: Removing duplicates\"); try removeDuplicatePOIs()")

content = content.replacingOccurrences(of: "let dirtyPOIs = try modelContext.fetch(", with: "print(\"DEBUG: Fetching POIs\"); let dirtyPOIs = try modelContext.fetch(")

content = content.replacingOccurrences(of: "let dirtyContents = try modelContext.fetch(", with: "print(\"DEBUG: Fetching Contents\"); let dirtyContents = try modelContext.fetch(")

content = content.replacingOccurrences(of: "let dirtyTrails = try modelContext.fetch(", with: "print(\"DEBUG: Fetching Trails\"); let dirtyTrails = try modelContext.fetch(")

content = content.replacingOccurrences(of: "for trail in dirtyTrails {", with: """
        for trail in dirtyTrails {
            print("DEBUG: Syncing trail \\(trail.id)")
""")

content = content.replacingOccurrences(of: "for trailId in bundleCandidates {", with: """
        print("DEBUG: Starting bundle candidates \\(bundleCandidates.count)")
        for trailId in bundleCandidates {
            print("DEBUG: Bundle for trail \\(trailId)")
""")

content = content.replacingOccurrences(of: "try await regenerateAndVerifyBundles(for: trail)", with: "print(\"DEBUG: Generating bundles for \\(trail.id)\"); try await regenerateAndVerifyBundles(for: trail); print(\"DEBUG: Finished generating bundles for \\(trail.id)\")")

content = content.replacingOccurrences(of: "private func syncTrailWithPublishGate(_ trail: Trail) async throws {", with: """
    private func syncTrailWithPublishGate(_ trail: Trail) async throws {
        print("DEBUG: syncTrailWithPublishGate start")
""")

content = content.replacingOccurrences(of: "private func pushTrail(_ trail: Trail) async throws {", with: """
    private func pushTrail(_ trail: Trail) async throws {
        print("DEBUG: pushTrail start")
""")

content = content.replacingOccurrences(of: "let dirtyEvents = try modelContext.fetch(", with: "print(\"DEBUG: Fetching Events\"); let dirtyEvents = try modelContext.fetch(")

content = content.replacingOccurrences(of: "changedCount += try await performGamificationPush()", with: "print(\"DEBUG: Starting gamification push\"); changedCount += try await performGamificationPush(); print(\"DEBUG: Finished gamification push\")")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Added debug prints to SyncManager")
