//
//  AdminRemoteEntityFactory.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData

struct AdminRemoteEntityFactory {
    nonisolated(unsafe) let modelContext: ModelContext

    nonisolated func makePOI(from data: [String: Any]) -> POI? {
        guard let id = UUID.fromSupabase(data["id"]),
              let name = data["name"] as? String,
              let description = data["poi_description"] as? String,
              let x = data["x"] as? Double,
              let y = data["y"] as? Double else {
            return nil
        }

        let typeRawValue = data["type"] as? String ?? "landmark"
        let poi = POI(
            name: name,
            description: description,
            x: x,
            y: y,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            type: POIType.fromSupabase(typeRawValue) ?? .landmark,
            photoURL: data["photo_url"] as? String,
            isStartPoint: data["is_start_point"] as? Bool ?? false,
            isActive: data["is_active"] as? Bool ?? true,
            iconName: data["icon_name"] as? String,
            numericCode: data["numeric_code"] as? String,
            descriptionKids: data["description_kids"] as? String,
            descriptionEasyRead: data["description_easy_read"] as? String,
            arModelURL: data["ar_model_url"] as? String,
            arAnimationConfig: Self.jsonString(from: data["ar_animation_config"]),
            arModelTier: ContentTier(rawValue: data["ar_model_tier"] as? String ?? "") ?? .full,
            fixedID: id
        )
        poi.qrPayload = data["qr_payload"] as? String ?? "ASTRONI_POI_\(id.uuidString)"
        poi.needsSync = false
        return poi
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

    nonisolated func makeTrail(from data: [String: Any]) -> Trail? {
        guard let id = UUID.fromSupabase(data["id"]),
              let name = data["name"] as? String else {
            return nil
        }

        let difficulty = (data["difficulty"] as? String).flatMap(TrailDifficulty.fromSupabase)
        let startPOIId = UUID.fromSupabase(data["start_poi_id"])

        let trail = Trail(
            name: name,
            description: data["description"] as? String ?? "",
            isActive: data["is_active"] as? Bool ?? false,
            difficulty: difficulty,
            estimatedMinutes: data["estimated_minutes"] as? Int,
            coverImageURL: data["cover_image_url"] as? String,
            startPOIId: startPOIId,
            fixedID: id
        )
        trail.needsSync = false
        return trail
    }

    nonisolated func makeEvent(from data: [String: Any]) -> Event? {
        guard let id = UUID.fromSupabase(data["id"]),
              let name = data["name"] as? String else {
            return nil
        }

        let categoryRawValue = data["category"] as? String ?? "other"
        let audienceRawValue = data["target_audience"] as? String ?? "all"
        let event = Event(
            name: name,
            description: data["description"] as? String ?? "",
            category: EventCategory.fromSupabase(categoryRawValue) ?? .other,
            date: Self.dateOnly(from: data["date"]) ?? Date(),
            startTime: Self.timeOnly(from: data["time_start"]) ?? Date(),
            endTime: Self.timeOnly(from: data["time_end"]) ?? Date(),
            maxParticipants: Self.intValue(data["max_participants"]),
            organizerName: Self.stringValue(data["organizer_name"]),
            contactInfo: Self.stringValue(data["contact_info"]),
            requirements: Self.stringValue(data["requirements"]),
            targetAudience: EventAudience.fromSupabase(audienceRawValue) ?? .all,
            price: Self.doubleValue(data["price"]) ?? 0,
            imageURL: Self.stringValue(data["image_url"]),
            fixedID: id
        )
        event.isActive = data["is_active"] as? Bool ?? false
        event.needsSync = false
        event.trail = fetchTrail(id: UUID.fromSupabase(data["path_id"]))
        event.eventPOI = fetchPOI(id: UUID.fromSupabase(data["event_poi_id"]))
        return event
    }

    nonisolated func makeContent(from data: [String: Any]) -> Content? {
        guard let id = UUID.fromSupabase(data["id"]),
              let poiId = UUID.fromSupabase(data["poi_id"]) else {
            return nil
        }

        let content = Content(poiId: poiId, fixedID: id)
        content.updateFromRemote(data)
        content.needsSync = false
        return content
    }

    private nonisolated func fetchTrail(id: UUID?) -> Trail? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private nonisolated func fetchPOI(id: UUID?) -> POI? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private nonisolated static func dateOnly(from value: Any?) -> Date? {
        guard let value = stringValue(value) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private nonisolated static func timeOnly(from value: Any?) -> Date? {
        guard let value = stringValue(value) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Calendar.current.timeZone
        for format in ["HH:mm:ss", "HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private nonisolated static func stringValue(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return value as? String
    }

    private nonisolated static func intValue(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private nonisolated static func doubleValue(_ value: Any?) -> Double? {
        guard let value, !(value is NSNull) else { return nil }
        if let double = value as? Double { return double }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

private extension UUID {
    nonisolated static func fromSupabase(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }
}
