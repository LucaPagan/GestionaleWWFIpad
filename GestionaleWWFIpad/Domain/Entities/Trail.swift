//
//  Trail.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Trail {
    var id: UUID
    var name: String
    var trailDescription: String
    var isActive: Bool
    var difficultyRawValue: String?
    var estimatedMinutes: Int?
    var coverImageURL: String?

    var steps: [TrailStep]
    var startPOIId: UUID?

    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    @Transient var difficulty: TrailDifficulty? {
        get { difficultyRawValue.flatMap { TrailDifficulty(rawValue: $0) } }
        set { difficultyRawValue = newValue?.rawValue }
    }

    init(
        name: String,
        description: String,
        isActive: Bool = false,
        difficulty: TrailDifficulty? = .easy,
        estimatedMinutes: Int? = 60,
        coverImageURL: String? = nil,
        startPOIId: UUID? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.name = name
        self.trailDescription = description
        self.isActive = isActive
        self.difficultyRawValue = difficulty?.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.coverImageURL = coverImageURL
        self.steps = []
        self.startPOIId = startPOIId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    var sortedSteps: [TrailStep] {
        steps.sorted { $0.stepOrder < $1.stepOrder }
    }

    func currentStep(completedPOIIds: Set<UUID>) -> TrailStep? {
        sortedSteps.first { step in
            guard let poi = step.poi else { return false }
            return !completedPOIIds.contains(poi.id)
        }
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["description"] as? String { trailDescription = d }
        if let active = data["is_active"] as? Bool { isActive = active }
        if let diff = data["difficulty"] as? String { difficultyRawValue = diff }
        estimatedMinutes = data["estimated_minutes"] as? Int
        coverImageURL = data["cover_image_url"] as? String
        if let spid = data["start_poi_id"] as? String {
            startPOIId = UUID(uuidString: spid)
        }
        needsSync = false
    }
}

extension Trail {
    func toSupabaseParams() -> [String: Any?] {
        return [
            "p_id": id.uuidString,
            "p_name": name,
            "p_description": trailDescription,
            "p_is_active": isActive,
            "p_difficulty": difficultyRawValue,
            "p_estimated_minutes": estimatedMinutes,
            "p_cover_image_url": coverImageURL,
            "p_start_poi_id": startPOIId?.uuidString
        ]
    }

    func stepsToJSON() -> [[String: Any?]] {
        sortedSteps.map { step in
            [
                "id": step.id.uuidString,
                "poi_id": step.poi?.id.uuidString,
                "step_order": step.stepOrder,
                "direction_hint": step.directionHint,
                "distance_meters": step.distanceMeters,
                "estimated_minutes": step.estimatedMinutes,
                "path_geometry": step.pathGeometry
            ]
        }
    }
}

enum TrailDifficulty: String, Codable, CaseIterable {
    case easy   = "easy"
    case medium = "medium"
    case hard   = "hard"

    var displayName: String {
        switch self {
        case .easy:   return "Facile"
        case .medium: return "Medio"
        case .hard:   return "Difficile"
        }
    }

    var color: Color {
        switch self {
        case .easy:   return WWFStyle.Colors.green
        case .medium: return WWFStyle.Colors.warning
        case .hard:   return WWFStyle.Colors.danger
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "figure.walk"
        case .medium: return "figure.hiking"
        case .hard:   return "mountain.2.fill"
        }
    }

    var supabaseValue: String { rawValue }

    static func fromSupabase(_ value: String) -> TrailDifficulty? {
        TrailDifficulty(rawValue: value)
    }
}
