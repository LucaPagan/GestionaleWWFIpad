//
//  Event.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Event {
    var id: UUID
    var name: String
    var eventDescription: String
    var categoryRawValue: String
    var date: Date
    var timeStart: Date
    var timeEnd: Date
    var maxParticipants: Int?
    var isActive: Bool
    var contactInfo: String?
    var requirements: String?
    var targetAudienceRawValue: String
    var price: Double
    var imageURL: String?
    var organizerName: String?
    var photoData: Data?

    var trail: Trail?
    var eventPOI: POI?

    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    @Transient var category: EventCategory {
        get { EventCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    @Transient var targetAudience: EventAudience {
        get { EventAudience(rawValue: targetAudienceRawValue) ?? .all }
        set { targetAudienceRawValue = newValue.rawValue }
    }

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
        self.categoryRawValue = category.rawValue
        self.date = date
        self.timeStart = startTime
        self.timeEnd = endTime
        self.maxParticipants = maxParticipants
        self.isActive = false
        self.organizerName = organizerName
        self.contactInfo = contactInfo
        self.requirements = requirements
        self.targetAudienceRawValue = targetAudience.rawValue
        self.price = price
        self.imageURL = imageURL
        self.photoData = photoData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

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

    var formattedPrice: String {
        price == 0 ? "Gratuito" : String(format: "€%.2f", price)
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["description"] as? String { eventDescription = d }
        if let cat = data["category"] as? String { categoryRawValue = cat }
        if let active = data["is_active"] as? Bool { isActive = active }
        maxParticipants = data["max_participants"] as? Int
        contactInfo = data["contact_info"] as? String
        requirements = data["requirements"] as? String
        if let ta = data["target_audience"] as? String { targetAudienceRawValue = ta }
        if let p = data["price"] as? Double { price = p }
        imageURL = data["image_url"] as? String
        organizerName = data["organizer_name"] as? String
        needsSync = false
    }
}

extension Event {
    func toSupabaseParams() -> [String: Any?] {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        return [
            "p_id": id.uuidString,
            "p_name": name,
            "p_description": eventDescription,
            "p_category": categoryRawValue,
            "p_date": dateFmt.string(from: date),
            "p_time_start": timeFmt.string(from: timeStart),
            "p_time_end": timeFmt.string(from: timeEnd),
            "p_max_participants": maxParticipants,
            "p_contact_info": contactInfo,
            "p_requirements": requirements,
            "p_target_audience": targetAudienceRawValue,
            "p_price": price,
            "p_image_url": imageURL,
            "p_is_active": isActive,
            "p_path_id": trail?.id.uuidString,
            "p_event_poi_id": eventPOI?.id.uuidString,
            "p_organizer_name": organizerName
        ]
    }
}

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

    var color: Color {
        switch self {
        case .educational:  return WWFStyle.Colors.educational
        case .guidedTour:   return WWFStyle.Colors.green
        case .workshop:     return WWFStyle.Colors.workshop
        case .family:       return WWFStyle.Colors.family
        case .photography:  return WWFStyle.Colors.photography
        case .scientific:   return WWFStyle.Colors.scientific
        case .other:        return WWFStyle.Colors.other
        }
    }

    var supabaseValue: String { rawValue }

    static func fromSupabase(_ value: String) -> EventCategory? {
        EventCategory(rawValue: value)
    }
}

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
