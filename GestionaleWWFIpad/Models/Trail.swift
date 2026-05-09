import Foundation
import SwiftData

@Model
final class Trail {
    var id: UUID
    var name: String
    var trailDescription: String
    var difficulty: TrailDifficulty
    var estimatedMinutes: Int
    var steps: [TrailStep]
    var isActive: Bool

    // Punto di partenza definito dal gestore
    var startPointName: String
    var startPointDescription: String
    var startX: Double  // normalizzato 0.0-1.0
    var startY: Double  // normalizzato 0.0-1.0

    init(
        name: String,
        description: String,
        difficulty: TrailDifficulty = .easy,
        estimatedMinutes: Int = 60,
        startPointName: String = "Punto di partenza",
        startPointDescription: String = "Inizia qui il tuo percorso.",
        startX: Double = 0.1,
        startY: Double = 0.9
    ) {
        self.id = UUID()
        self.name = name
        self.trailDescription = description
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.steps = []
        self.isActive = false
        self.startPointName = startPointName
        self.startPointDescription = startPointDescription
        self.startX = startX
        self.startY = startY
    }

    func currentStep(completedPOIIds: Set<UUID>) -> TrailStep? {
        steps
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { step in
                guard let poi = step.poi else { return false }
                return !completedPOIIds.contains(poi.id)
            }
    }

    var sortedSteps: [TrailStep] {
        steps.sorted { $0.orderIndex < $1.orderIndex }
    }
}

enum TrailDifficulty: String, Codable, CaseIterable {
    case easy   = "Facile"
    case medium = "Medio"
    case hard   = "Difficile"

    var color: String {
        switch self {
        case .easy:   return "#2E7D32"
        case .medium: return "#F57F17"
        case .hard:   return "#C62828"
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "figure.walk"
        case .medium: return "figure.hiking"
        case .hard:   return "mountain.2.fill"
        }
    }
}
