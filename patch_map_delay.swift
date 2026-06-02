import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Features/MapEditor/MapEditorView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

let oldCode = """
        if mapMode.trail == nil { context.insert(target) }
        try? context.save()

        Task {
            await syncManager.pushAllChanges()
"""
let newCode = """
        if mapMode.trail == nil { context.insert(target) }
        try? context.save()

        Task {
            // Give SwiftData's persistent store a moment to write the WAL before the background context fetches it.
            try? await Task.sleep(for: .seconds(1))
            await syncManager.pushAllChanges()
"""

if content.contains(oldCode) {
    content = content.replacingOccurrences(of: oldCode, with: newCode)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Added delay to MapEditorView")
} else {
    print("Could not find old code")
}
