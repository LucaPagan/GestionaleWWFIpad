//
//  Event.swift
//  GestionaleWWFIpad
//
//  Mirrors Supabase table: public.events
//  SRS Reference: Chapter 11 — Table: events
//

import Foundation
import SwiftData

// MARK: - Event Model

/// An event organized by the manager with an optional trail association.
/// Mirrors the `events` table on Supabase with 1:1 field mapping.
@Model
final class Event {
    // MARK: - Primary Key
    var id: UUID

    // MARK: - Core Fields (mirror Supabase)
    var name: String
    var eventDescription: String           // DB: description
    var category: EventCategory            // DB: ENUM event_category
    var date: Date                         // DB: date (DATE type)
    var timeStart: Date                    // DB: time_start (stored as Date, only time component used)
    var timeEnd: Date                      // DB: time_end
    var maxParticipants: Int?              // DB: max_participants (nullable, CHECK > 0)
    var isActive: Bool                     // DB: is_active — visibility for end users
    var contactInfo: String?               // DB: contact_info
    var requirements: String?              // DB: requirements
    var targetAudience: EventAudience      // DB: ENUM event_audience
    var price: Double                      // DB: price (DOUBLE, CHECK >= 0, 0 = gratuito)
    var imageURL: String?                  // DB: image_url (URL to Supabase Storage)
    var organizerName: String?             // DB: organizer_name
    var photoData: Data?                   // Local-only: cached image data

    // MARK: - Relationships
    var trail: Trail?                      // DB: path_id (FK → paths)
    var eventPOI: POI?                     // DB: event_poi_id (FK → pois)

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Metadata
    var needsSync: Bool

    // MARK: - Initializer

    init(
        name: String,
        description: String,
        category: EventCategory = .other,
        date: Date = Date(),
        startTime: Date = Date(),
        endTime: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
        maxParticipants: Int? = 30,
        organizerName: String? = nil,
        contactInfo: String? = nil,
        requirements: String? = nil,
        targetAudience: EventAudience = .all,
        price: Double = 0,
        imageURL: String? = nil,
        photoData: Data? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.name = name
        self.eventDescription = description
        self.category = category
        self.date = date
        self.timeStart = startTime
        self.timeEnd = endTime
        self.maxParticipants = maxParticipants
        self.isActive = false
        self.organizerName = organizerName
        self.contactInfo = contactInfo
        self.requirements = requirements
        self.targetAudience = targetAudience
        self.price = price
        self.imageURL = imageURL
        self.photoData = photoData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    // MARK: - Computed Properties

    var formattedStartTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: timeStart)
    }

    var formattedEndTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: timeEnd)
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "it_IT")
        fmt.dateStyle = .long
        return fmt.string(from: date)
    }

    var formattedTimeRange: String {
        "\(formattedStartTime) – \(formattedEndTime)"
    }

    var isUpcoming: Bool {
        date >= Calendar.current.startOfDay(for: Date())
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Price formatted for Italian display
    var formattedPrice: String {
        price == 0 ? "Gratuito" : String(format: "€%.2f", price)
    }

    // MARK: - Supabase Mapping

    /// Creates a dictionary for Supabase RPC `upsert_event`
    func toSupabaseParams() -> [String: Any?] {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        return [
            "p_id": id.uuidString,
            "p_name": name,
            "p_description": eventDescription,
            "p_category": category.supabaseValue,
            "p_date": dateFmt.string(from: date),
            "p_time_start": timeFmt.string(from: timeStart),
            "p_time_end": timeFmt.string(from: timeEnd),
            "p_max_participants": maxParticipants,
            "p_contact_info": contactInfo,
            "p_requirements": requirements,
            "p_target_audience": targetAudience.supabaseValue,
            "p_price": price,
            "p_image_url": imageURL,
            "p_is_active": isActive,
            "p_path_id": trail?.id.uuidString,
            "p_event_poi_id": eventPOI?.id.uuidString,
            "p_organizer_name": organizerName
        ]
    }

    /// Updates local model from Supabase row data
    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["description"] as? String { eventDescription = d }
        if let cat = data["category"] as? String {
            category = EventCategory.fromSupabase(cat) ?? .other
        }
        if let active = data["is_active"] as? Bool { isActive = active }
        maxParticipants = data["max_participants"] as? Int
        contactInfo = data["contact_info"] as? String
        requirements = data["requirements"] as? String
        if let ta = data["target_audience"] as? String {
            targetAudience = EventAudience.fromSupabase(ta) ?? .all
        }
        if let p = data["price"] as? Double { price = p }
        imageURL = data["image_url"] as? String
        organizerName = data["organizer_name"] as? String
        needsSync = false
    }
}

// MARK: - EventCategory Enum

/// Maps to Supabase ENUM `event_category`
enum EventCategory: String, Codable, CaseIterable {
    case educational  = "educational"
    case guidedTour   = "guided_tour"
    case workshop     = "workshop"
    case family       = "family"
    case photography  = "photography"
    case scientific   = "scientific"
    case other        = "other"

    var displayName: String {
        switch self {
        case .educational:  return "Educativo"
        case .guidedTour:   return "Visita Guidata"
        case .workshop:     return "Laboratorio"
        case .family:       return "Famiglia"
        case .photography:  return "Fotografia"
        case .scientific:   return "Scientifico"
        case .other:        return "Altro"
        }
    }

    var icon: String {
        switch self {
        case .educational:  return "book.fill"
        case .guidedTour:   return "figure.walk"
        case .workshop:     return "hammer.fill"
        case .family:       return "figure.and.child.holdinghands"
        case .photography:  return "camera.fill"
        case .scientific:   return "flask.fill"
        case .other:        return "calendar.badge.clock"
        }
    }

    var color: String {
        switch self {
        case .educational:  return "#1565C0"
        case .guidedTour:   return "#2E7D32"
        case .workshop:     return "#F57F17"
        case .family:       return "#AB47BC"
        case .photography:  return "#455A64"
        case .scientific:   return "#00897B"
        case .other:        return "#5C8A5C"
        }
    }

    var supabaseValue: String { rawValue }

    static func fromSupabase(_ value: String) -> EventCategory? {
        EventCategory(rawValue: value)
    }
}

// MARK: - EventAudience Enum

/// Maps to Supabase ENUM `event_audience`
enum EventAudience: String, Codable, CaseIterable {
    case all         = "all"
    case adults      = "adults"
    case children    = "children"
    case families    = "families"
    case schools     = "schools"
    case researchers = "researchers"

    var displayName: String {
        switch self {
        case .all:         return "Tutti"
        case .adults:      return "Adulti"
        case .children:    return "Bambini"
        case .families:    return "Famiglie"
        case .schools:     return "Scuole"
        case .researchers: return "Ricercatori"
        }
    }

    var supabaseValue: String { rawValue }

    static func fromSupabase(_ value: String) -> EventAudience? {
        EventAudience(rawValue: value)
    }
}
