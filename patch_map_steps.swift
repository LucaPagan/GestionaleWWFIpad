import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Features/MapEditor/MapEditorView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

let oldCode = """
        target.steps.forEach { context.delete($0) }
        target.steps = tbSteps.enumerated().map { i, draft in
            let s = TrailStep(
                stepOrder: i,
                directionHint: draft.instructions,
                distanceMeters: draft.distanceMeters,
                estimatedMinutes: draft.estimatedMinutes,
                pathGeometry: draft.pathGeometry,
                poi: draft.poi
            )
            context.insert(s)
            return s
        }
"""
let newCode = """
        // Safely update existing steps to prevent SwiftData relationship thrashing/deadlocks
        // that can cause infinite loading in background contexts.
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
"""

if content.contains(oldCode) {
    content = content.replacingOccurrences(of: oldCode, with: newCode)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Updated step logic")
} else {
    print("Could not find old code")
}
