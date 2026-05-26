//
//  POI.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class POI {
    var id: UUID
    var name: String
    var poiDescription: String
    var iconName: String
    var numericCode: String
    var descriptionKids: String?
    var descriptionEasyRead: String?
    var x: Double
    var y: Double
    var latitude: Double?
    var longitude: Double?
    var typeRawValue: String
    var photoURL: String?
    var photoData: Data?
    var qrPayload: String
    var isStartPoint: Bool
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    @Transient var type: POIType {
        get { POIType(rawValue: typeRawValue) ?? .landmark }
        set { typeRawValue = newValue.rawValue }
    }

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
        iconName: String? = nil,
        numericCode: String? = nil,
        descriptionKids: String? = nil,
        descriptionEasyRead: String? = nil,
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
        self.typeRawValue = type.rawValue
        self.photoURL = photoURL
        self.photoData = photoData
        self.qrPayload = "ASTRONI_POI_\(newID.uuidString)"
        self.isStartPoint = isStartPoint
        self.isActive = isActive
        self.iconName = iconName ?? type.icon
        self.numericCode = numericCode ?? String(format: "%06d", Int.random(in: 100000...999999))
        self.descriptionKids = descriptionKids
        self.descriptionEasyRead = descriptionEasyRead
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["poi_description"] as? String { poiDescription = d }
        if let xVal = data["x"] as? Double { x = xVal }
        if let yVal = data["y"] as? Double { y = yVal }
        latitude = data["latitude"] as? Double
        longitude = data["longitude"] as? Double
        if let t = data["type"] as? String { typeRawValue = t }
        photoURL = data["photo_url"] as? String
        if let qr = data["qr_payload"] as? String { qrPayload = qr }
        if let sp = data["is_start_point"] as? Bool { isStartPoint = sp }
        if let active = data["is_active"] as? Bool { isActive = active }
        if let icon = data["icon_name"] as? String { iconName = icon }
        if let code = data["numeric_code"] as? String { numericCode = code }
        descriptionKids = data["description_kids"] as? String
        descriptionEasyRead = data["description_easy_read"] as? String
        needsSync = false
    }
}

extension POI {
    func toSupabaseParams() -> [String: Any?] {
        return [
            "p_id": id.uuidString,
            "p_name": name,
            "p_description": poiDescription,
            "p_x": x,
            "p_y": y,
            "p_latitude": latitude,
            "p_longitude": longitude,
            "p_type": typeRawValue,
            "p_photo_url": photoURL,
            "p_qr_payload": qrPayload,
            "p_is_start_point": isStartPoint,
            "p_is_active": isActive,
            "p_icon_name": iconName,
            "p_numeric_code": numericCode,
            "p_description_kids": descriptionKids,
            "p_description_easy_read": descriptionEasyRead
        ]
    }
}

enum POIType: String, Codable, CaseIterable {
    case landmark   = "landmark"
    case info       = "info"
    case warning    = "warning"
    case danger     = "danger"
    case startPoint = "start_point"

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

    var color: Color {
        switch self {
        case .landmark:   return WWFStyle.Colors.green
        case .info:       return WWFStyle.Colors.info
        case .warning:    return WWFStyle.Colors.warning
        case .danger:     return WWFStyle.Colors.danger
        case .startPoint: return WWFStyle.Colors.purple
        }
    }

    var supabaseValue: String { rawValue }

    nonisolated static func fromSupabase(_ value: String) -> POIType? {
        POIType(rawValue: value)
    }
}
