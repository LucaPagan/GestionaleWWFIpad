import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
let content = try! String(contentsOfFile: path, encoding: .utf8)

let lines = content.components(separatedBy: .newlines)
for (i, line) in lines.enumerated() {
    if line.contains("for trail in dirtyTrails {") || line.contains("for trailId in bundleCandidates {") {
        print("\(i): \(line)")
    }
}
