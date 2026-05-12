//
//  TrailStep.swift
//  GestionaleWWFIpad
//
//  Mirrors Supabase table: public.path_steps
//  SRS Reference: Chapter 11 — Table: path_steps
//

import Foundation
import SwiftData

// MARK: - TrailStep Model

/// A single step in a trail: links a POI in sequence with navigation hints.
/// Mirrors the `path_steps` table on Supabase.
@Model
final class TrailStep {
    // MARK: - Primary Key
    var id: UUID

    // MARK: - Core Fields (mirror Supabase)
    var stepOrder: Int                     // DB: step_order (CHECK >= 0)
    var directionHint: String?             // DB: direction_hint — navigation instructions
    var distanceMeters: Int?               // DB: distance_meters (CHECK > 0)
    var estimatedMinutes: Int?             // DB: estimated_minutes (CHECK > 0)

    // MARK: - Relationships
    var poi: POI?                          // DB: poi_id (FK → pois)

    // MARK: - Timestamps
    var createdAt: Date

    // MARK: - Initializer

    init(
        stepOrder: Int,
        directionHint: String? = nil,
        distanceMeters: Int? = nil,
        estimatedMinutes: Int? = nil,
        poi: POI? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.stepOrder = stepOrder
        self.directionHint = directionHint
        self.distanceMeters = distanceMeters
        self.estimatedMinutes = estimatedMinutes
        self.poi = poi
        self.createdAt = Date()
    }

    // MARK: - Backward Compatibility

    /// Alias for directionHint — used by existing views that reference `instructions`
    var instructions: String {
        get { directionHint ?? "" }
        set { directionHint = newValue }
    }

    /// Alias for stepOrder — used by existing views that reference `orderIndex`
    var orderIndex: Int {
        get { stepOrder }
        set { stepOrder = newValue }
    }
}
