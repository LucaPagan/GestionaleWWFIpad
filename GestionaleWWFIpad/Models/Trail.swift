//
//  Trail.swift
//  GestionaleWWFIpad
//
//  Mirrors Supabase table: public.paths
//  SRS Reference: Chapter 11 — Table: paths
//

import Foundation
import SwiftData

// MARK: - Trail Model

/// Represents a trail/path in the Oasi degli Astroni.
/// Mirrors the `paths` table on Supabase with 1:1 field mapping.
///
/// Note: The Swift model uses "Trail" naming for iOS conventions,
/// while Supabase uses "paths" to stay DB-neutral.
@Model
final class Trail {
    // MARK: - Primary Key
    var id: UUID

    // MARK: - Core Fields (mirror Supabase)
    var name: String
    var trailDescription: String           // DB: description
    var isActive: Bool                      // DB: is_active — visibility for end users
    var difficulty: TrailDifficulty?        // DB: ENUM path_difficulty (nullable per SRS)
    var estimatedMinutes: Int?             // DB: estimated_minutes (nullable per SRS, CHECK > 0)
    var coverImageURL: String?             // DB: cover_image_url

    // MARK: - Relationships
    var steps: [TrailStep]                 // DB: path_steps (FK path_id)
    var startPOIId: UUID?                  // DB: start_poi_id (FK → pois)

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Metadata (local-only)
    var needsSync: Bool

    // MARK: - Initializer

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
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.coverImageURL = coverImageURL
        self.steps = []
        self.startPOIId = startPOIId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    // MARK: - Computed Properties

    /// Returns steps sorted by their order index
    var sortedSteps: [TrailStep] {
        steps.sorted { $0.stepOrder < $1.stepOrder }
    }

    /// Finds the current step the user needs to visit based on completed POI IDs
    func currentStep(completedPOIIds: Set<UUID>) -> TrailStep? {
        sortedSteps.first { step in
            guard let poi = step.poi else { return false }
            return !completedPOIIds.contains(poi.id)
        }
    }

    // MARK: - Supabase Mapping

    /// Creates a dictionary for Supabase RPC `upsert_path`
    func toSupabaseParams() -> [String: Any?] {
        return [
            "p_id": id.uuidString,
            "p_name": name,
            "p_description": trailDescription,
            "p_is_active": isActive,
            "p_difficulty": difficulty?.supabaseValue,
            "p_estimated_minutes": estimatedMinutes,
            "p_cover_image_url": coverImageURL,
            "p_start_poi_id": startPOIId?.uuidString
        ]
    }

    /// Creates JSONB array of steps for `sync_path_steps` RPC
    func stepsToJSON() -> [[String: Any?]] {
        sortedSteps.map { step in
            [
                "id": step.id.uuidString,
                "poi_id": step.poi?.id.uuidString,
                "step_order": step.stepOrder,
                "direction_hint": step.directionHint,
                "distance_meters": step.distanceMeters,
                "estimated_minutes": step.estimatedMinutes
            ]
        }
    }

    /// Updates local model from Supabase row data
    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["description"] as? String { trailDescription = d }
        if let active = data["is_active"] as? Bool { isActive = active }
        if let diff = data["difficulty"] as? String {
            difficulty = TrailDifficulty.fromSupabase(diff)
        }
        estimatedMinutes = data["estimated_minutes"] as? Int
        coverImageURL = data["cover_image_url"] as? String
        if let spid = data["start_poi_id"] as? String {
            startPOIId = UUID(uuidString: spid)
        }
        needsSync = false
    }
}

// MARK: - TrailDifficulty Enum

/// Maps to Supabase ENUM `path_difficulty`: easy | medium | hard
enum TrailDifficulty: String, Codable, CaseIterable {
    case easy   = "easy"
    case medium = "medium"
    case hard   = "hard"

    // MARK: - Display Properties (Italian UI)

    var displayName: String {
        switch self {
        case .easy:   return "Facile"
        case .medium: return "Medio"
        case .hard:   return "Difficile"
        }
    }

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

    // MARK: - Supabase Mapping

    var supabaseValue: String { rawValue }

    static func fromSupabase(_ value: String) -> TrailDifficulty? {
        TrailDifficulty(rawValue: value)
    }
}
