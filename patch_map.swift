import Foundation

let path = "/Users/lucapagano/Desktop/WWFUserAndManaging/GestionaleWWFIpad/GestionaleWWFIpad/Features/TrailBuilder/TrailInteractiveMapView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// 1. Add tracing variables to the struct
content = content.replacingOccurrences(
    of: "var isTracingMode: Bool = false",
    with: "var isTracingMode: Bool = false\n    var tracingStartPOIId: UUID? = nil\n    var tracingEndPOIId: UUID? = nil"
)

// 2. Modify `updateMarkersAndLines` to use the tracing variables to highlight the specific POIs being traced.
let oldSelectionLogic = "let isSelected = stepIndex != nil || poi.id == parent.selectedPOIId"
let newSelectionLogic = """
                let isTracingActivePOI = parent.isTracingMode && (poi.id == parent.tracingStartPOIId || poi.id == parent.tracingEndPOIId)
                let isSelected = parent.isTracingMode ? isTracingActivePOI : (stepIndex != nil || poi.id == parent.selectedPOIId)
"""
content = content.replacingOccurrences(of: oldSelectionLogic, with: newSelectionLogic)

// 3. Update HUD text
let oldHUD = "label.text = \"🎨 DISEGNA IL SENTIERO SULLA MAPPA\""
let newHUD = "label.text = \"🎨 TRACCIA IL PERCORSO TRA I PUNTI EVIDENZIATI IN GIALLO\""
content = content.replacingOccurrences(of: oldHUD, with: newHUD)

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Updated TrailInteractiveMapView.swift")
