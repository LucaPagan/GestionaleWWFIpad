//
//  POI.swift
//  GestionaleWWFIpad
//
//  Mirrors Supabase table: public.pois
//  SRS Reference: Chapter 11 — Table: pois
//

import Foundation
import SwiftData
import CoreGraphics

// MARK: - POI Model

/// Represents a physical Point of Interest in the Oasi degli Astroni.
/// Mirrors the `pois` table on Supabase with 1:1 field mapping.
@Model
final class POI {
    // MARK: - Primary Key
    var id: UUID

    // MARK: - Core Fields (mirror Supabase)
    var name: String
    var poiDescription: String            // DB: poi_description
    var x: Double                          // Normalized 0.0–1.0 on local map
    var y: Double                          // Normalized 0.0–1.0 on local map
    var latitude: Double?                  // GPS (future use, nullable per SRS)
    var longitude: Double?                 // GPS (future use, nullable per SRS)
    var type: POIType                      // DB: ENUM poi_type
    var photoURL: String?                  // DB: photo_data (VARCHAR URL to Supabase Storage)
    var photoData: Data?                   // Local-only: cached image data for offline use
    var qrPayload: String                  // DB: qr_payload (UNIQUE)
    var isStartPoint: Bool                 // DB: is_start_point
    var isActive: Bool                     // DB: is_active — visibility for end users

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Metadata (local-only, not in Supabase)
    var needsSync: Bool                    // True when local changes haven't been pushed

    // MARK: - Initializer

    init(
        name: String,
        description: String,
        x: Double,
        y: Double,
        latitude: Double? = nil,
        longitude: Double? = nil,
        type: POIType = .landmark,
        photoURL: String? = nil,
        photoData: Data? = nil,
        isStartPoint: Bool = false,
        isActive: Bool = true,
        fixedID: UUID? = nil
    ) {
        let newID = fixedID ?? UUID()
        self.id = newID
        self.name = name
        self.poiDescription = description
        self.x = x
        self.y = y
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.photoURL = photoURL
        self.photoData = photoData
        self.qrPayload = "ASTRONI_POI_\(newID.uuidString)"
        self.isStartPoint = isStartPoint
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    // MARK: - Supabase Mapping

    /// Creates a dictionary for Supabase upsert via RPC
    func toSupabaseParams() -> [String: Any?] {
        return [
            "p_id": id.uuidString,
            "p_name": name,
            "p_description": poiDescription,
            "p_x": x,
            "p_y": y,
            "p_latitude": latitude,
            "p_longitude": longitude,
            "p_type": type.supabaseValue,
            "p_photo_url": photoURL,
            "p_qr_payload": qrPayload,
            "p_is_start_point": isStartPoint,
            "p_is_active": isActive
        ]
    }

    /// Updates local model from Supabase row data
    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["poi_description"] as? String { poiDescription = d }
        if let xVal = data["x"] as? Double { x = xVal }
        if let yVal = data["y"] as? Double { y = yVal }
        latitude = data["latitude"] as? Double
        longitude = data["longitude"] as? Double
        if let t = data["type"] as? String, let poiType = POIType.fromSupabase(t) {
            type = poiType
        }
        photoURL = data["photo_data"] as? String
        if let qr = data["qr_payload"] as? String { qrPayload = qr }
        if let sp = data["is_start_point"] as? Bool { isStartPoint = sp }
        if let active = data["is_active"] as? Bool { isActive = active }
        needsSync = false
    }
}

// MARK: - POIType Enum

/// Maps to Supabase ENUM `poi_type`: landmark | info | warning | danger | start_point
/// Display labels are in Italian for the UI layer.
enum POIType: String, Codable, CaseIterable {
    case landmark   = "landmark"
    case info       = "info"
    case warning    = "warning"
    case danger     = "danger"
    case startPoint = "start_point"

    // MARK: - Display Properties (Italian UI)

    var displayName: String {
        switch self {
        case .landmark:   return "Punto di Interesse"
        case .info:       return "Informazione"
        case .warning:    return "Attenzione"
        case .danger:     return "Pericolo"
        case .startPoint: return "Punto di Partenza"
        }
    }

    var icon: String {
        switch self {
        case .landmark:   return "mappin.circle.fill"
        case .info:       return "info.circle.fill"
        case .warning:    return "exclamationmark.triangle.fill"
        case .danger:     return "xmark.octagon.fill"
        case .startPoint: return "flag.fill"
        }
    }

    var color: String {
        switch self {
        case .landmark:   return "#2E7D32"
        case .info:       return "#1565C0"
        case .warning:    return "#F57F17"
        case .danger:     return "#C62828"
        case .startPoint: return "#6A1B9A"
        }
    }

    // MARK: - Supabase Mapping

    /// Value stored in Supabase ENUM
    var supabaseValue: String { rawValue }

    /// Creates from Supabase ENUM string
    static func fromSupabase(_ value: String) -> POIType? {
        POIType(rawValue: value)
    }
}
