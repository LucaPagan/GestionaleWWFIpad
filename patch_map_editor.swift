import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Features/MapEditor/MapEditorView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// 1. Add new state variables
content = content.replacingOccurrences(
    of: "@State private var tbTracingStepId: UUID? = nil\n    @State private var tbIsTracing: Bool = false",
    with: "@State private var tbTracingStepId: UUID? = nil\n    @State private var tbTracingStartPOIId: UUID? = nil\n    @State private var tbTracingEndPOIId: UUID? = nil\n    @State private var tbIsTracing: Bool = false"
)

// 2. Pass them to TrailInteractiveMapView
content = content.replacingOccurrences(
    of: "isTracingMode: tbIsTracing,",
    with: "isTracingMode: tbIsTracing,\n                            tracingStartPOIId: tbTracingStartPOIId,\n                            tracingEndPOIId: tbTracingEndPOIId,"
)

// 3. Clear them in onPathCaptured
content = content.replacingOccurrences(
    of: "tbTracingStepId = nil\n                                }",
    with: "tbTracingStepId = nil\n                                    tbTracingStartPOIId = nil\n                                    tbTracingEndPOIId = nil\n                                }"
)

// 4. Update the onReceive block
let oldOnReceive = """
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerPathTracing"))) { note in
            if let id = note.object as? UUID {
                tbTracingStepId = id
                withAnimation {
                    tbIsTracing = true
                }
            }
        }
"""
let newOnReceive = """
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerPathTracing"))) { note in
            if let id = note.object as? UUID, let index = tbSteps.firstIndex(where: { $0.id == id }) {
                tbTracingStepId = id
                tbTracingEndPOIId = tbSteps[index].poi?.id
                tbTracingStartPOIId = index == 0 ? tbSelectedStartPOI?.id : tbSteps[index - 1].poi?.id
                withAnimation {
                    tbIsTracing = true
                }
            }
        }
"""
content = content.replacingOccurrences(of: oldOnReceive, with: newOnReceive)

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Updated MapEditorView.swift")
