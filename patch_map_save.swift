import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Features/MapEditor/MapEditorView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(of: "tbIsSyncing = true", with: "print(\"DEBUG: saveTrail started\"); tbIsSyncing = true")
content = content.replacingOccurrences(of: "try? context.save()", with: "print(\"DEBUG: context.save() called\"); try? context.save(); print(\"DEBUG: context.save() finished\")")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Added debug prints to MapEditorView")
