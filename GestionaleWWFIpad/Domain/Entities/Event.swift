//
//  Event.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Event {
    @Attribute(.unique) var id: UUID
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
        if let remoteDate = Self.dateOnly(from: data["date"]) { date = remoteDate }
        if let remoteStart = Self.timeOnly(from: data["time_start"]) { timeStart = remoteStart }
        if let remoteEnd = Self.timeOnly(from: data["time_end"]) { timeEnd = remoteEnd }
        if let active = data["is_active"] as? Bool { isActive = active }
        maxParticipants = Self.intValue(data["max_participants"])
        contactInfo = Self.stringValue(data["contact_info"])
        requirements = Self.stringValue(data["requirements"])
        if let ta = data["target_audience"] as? String { targetAudienceRawValue = ta }
        if let p = Self.doubleValue(data["price"]) { price = p }
        imageURL = Self.stringValue(data["image_url"])
        organizerName = Self.stringValue(data["organizer_name"])
        needsSync = false
    }

    nonisolated private static func stringValue(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return value as? String
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    nonisolated private static func doubleValue(_ value: Any?) -> Double? {
        guard let value, !(value is NSNull) else { return nil }
        if let double = value as? Double { return double }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    nonisolated private static func dateOnly(from value: Any?) -> Date? {
        guard let string = stringValue(value) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    nonisolated private static func timeOnly(from value: Any?) -> Date? {
        guard let string = stringValue(value) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Calendar.current.timeZone
        for format in ["HH:mm:ss", "HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
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
        case .other:        return "calendar"
        case .scientific:   return "science"
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

    nonisolated static func fromSupabase(_ value: String) -> EventCategory? {
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

    nonisolated static func fromSupabase(_ value: String) -> EventAudience? {
        EventAudience(rawValue: value)
    }
}
