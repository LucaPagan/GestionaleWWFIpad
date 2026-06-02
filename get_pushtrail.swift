import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Services/SyncManager.swift"
let content = try! String(contentsOfFile: path, encoding: .utf8)

let lines = content.components(separatedBy: .newlines)
var inPushTrail = false
for (i, line) in lines.enumerated() {
    if line.contains("private func pushTrail(_ trail: Trail)") {
        inPushTrail = true
    }
    if inPushTrail {
        print(line)
        if line == "    }" {
            break
        }
    }
}
