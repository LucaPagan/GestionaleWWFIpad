//
//  POI.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class POI {
    @Attribute(.unique) var id: UUID
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
    var arModelURL: String?
    var arAnimationConfig: String?
    var arModelTierRawValue: String?

    @Transient var type: POIType {
        get { POIType(rawValue: typeRawValue) ?? .landmark }
        set { typeRawValue = newValue.rawValue }
    }

    @Transient var arModelTier: ContentTier {
        get { ContentTier(rawValue: arModelTierRawValue ?? "") ?? .full }
        set { arModelTierRawValue = newValue.rawValue }
    }

    @Transient var shouldClearPhotoURL: Bool = false
    @Transient var shouldClearARModel: Bool = false

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
        arModelURL: String? = nil,
        arAnimationConfig: String? = nil,
        arModelTier: ContentTier = .full,
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
        self.arModelURL = arModelURL
        self.arAnimationConfig = arAnimationConfig
        self.arModelTierRawValue = arModelTier.rawValue
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
        arModelURL = data["ar_model_url"] as? String
        arAnimationConfig = POI.jsonString(from: data["ar_animation_config"])
        if let arTier = data["ar_model_tier"] as? String { arModelTierRawValue = arTier }
        needsSync = false
    }

    nonisolated private static func jsonString(from value: Any?) -> String? {
        if let string = value as? String { return string }
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

struct ARAnimationConfig: Codable, Equatable {
    var rotationEnabled: Bool
    var floatingEnabled: Bool
    var pulseEnabled: Bool
    var speed: Double
    var floatAmplitude: Double
    var pulseScale: Double

    static let `default` = ARAnimationConfig(
        rotationEnabled: true,
        floatingEnabled: false,
        pulseEnabled: false,
        speed: 1.0,
        floatAmplitude: 0.08,
        pulseScale: 1.08
    )

    enum CodingKeys: String, CodingKey {
        case rotationEnabled
        case floatingEnabled
        case pulseEnabled
        case speed
        case floatAmplitude
        case pulseScale
    }

    init(
        rotationEnabled: Bool,
        floatingEnabled: Bool,
        pulseEnabled: Bool,
        speed: Double,
        floatAmplitude: Double,
        pulseScale: Double
    ) {
        self.rotationEnabled = rotationEnabled
        self.floatingEnabled = floatingEnabled
        self.pulseEnabled = pulseEnabled
        self.speed = speed
        self.floatAmplitude = floatAmplitude
        self.pulseScale = pulseScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rotationEnabled = container.flexibleBool(forKey: .rotationEnabled, default: Self.default.rotationEnabled)
        floatingEnabled = container.flexibleBool(forKey: .floatingEnabled, default: Self.default.floatingEnabled)
        pulseEnabled = container.flexibleBool(forKey: .pulseEnabled, default: Self.default.pulseEnabled)
        speed = container.flexibleDouble(forKey: .speed, default: Self.default.speed)
        floatAmplitude = container.flexibleDouble(forKey: .floatAmplitude, default: Self.default.floatAmplitude)
        pulseScale = container.flexibleDouble(forKey: .pulseScale, default: Self.default.pulseScale)
    }

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var jsonObject: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func decode(from string: String?) -> ARAnimationConfig {
        guard let string,
              let data = string.data(using: .utf8),
              let config = try? JSONDecoder().decode(ARAnimationConfig.self, from: data) else {
            return .default
        }
        return config
    }
}

private extension KeyedDecodingContainer {
    func flexibleBool(forKey key: Key, default defaultValue: Bool) -> Bool {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return value != 0 }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        if let value = try? decode(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return defaultValue
            }
        }
        return defaultValue
    }

    func flexibleDouble(forKey key: Key, default defaultValue: Double) -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(Bool.self, forKey: key) { return value ? defaultValue : 0 }
        if let value = try? decode(String.self, forKey: key),
           let parsed = Double(value.replacingOccurrences(of: ",", with: ".")) {
            return parsed
        }
        return defaultValue
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
