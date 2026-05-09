//
//  Event.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//

import Foundation
import SwiftData

@Model
final class Event {
    var id: UUID
    var name: String
    var eventDescription: String
    var category: EventCategory
    var date: Date
    var startTime: Date
    var endTime: Date
    var maxParticipants: Int
    var isActive: Bool
    var organizerName: String
    var contactInfo: String
    var requirements: String       // Cosa portare / requisiti (es. "Scarpe da trekking, binocolo")
    var targetAudience: String     // Pubblico target (es. "Famiglie", "Adulti", "Bambini 6-12 anni")
    var price: String              // Costo (es. "Gratuito", "€5.00")
    var photoData: Data?

    // L'evento ha un percorso associato — riusa il sistema Trail esistente
    var trail: Trail?

    // POI dove si tiene l'evento (l'evento stesso è un punto di interesse)
    var eventPOI: POI?

    init(
        name: String,
        description: String,
        category: EventCategory = .generic,
        date: Date = Date(),
        startTime: Date = Date(),
        endTime: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
        maxParticipants: Int = 30,
        organizerName: String = "",
        contactInfo: String = "",
        requirements: String = "",
        targetAudience: String = "Tutti",
        price: String = "Gratuito",
        photoData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.eventDescription = description
        self.category = category
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.maxParticipants = maxParticipants
        self.isActive = false
        self.organizerName = organizerName
        self.contactInfo = contactInfo
        self.requirements = requirements
        self.targetAudience = targetAudience
        self.price = price
        self.photoData = photoData
    }

    // Formatta solo l'ora
    var formattedStartTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: startTime)
    }

    var formattedEndTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: endTime)
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

    // Controlla se l'evento è nel futuro
    var isUpcoming: Bool {
        date >= Calendar.current.startOfDay(for: Date())
    }

    // Controlla se l'evento è oggi
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case generic       = "Generico"
    case birdwatching  = "Birdwatching"
    case workshop      = "Laboratorio"
    case guidedTour    = "Visita Guidata"
    case kids          = "Bambini"
    case photography   = "Fotografia"
    case conservation  = "Conservazione"
    case nightEvent    = "Evento Notturno"

    var icon: String {
        switch self {
        case .generic:      return "calendar.badge.clock"
        case .birdwatching: return "bird.fill"
        case .workshop:     return "hammer.fill"
        case .guidedTour:   return "figure.walk"
        case .kids:         return "figure.and.child.holdinghands"
        case .photography:  return "camera.fill"
        case .conservation: return "leaf.arrow.circlepath"
        case .nightEvent:   return "moon.stars.fill"
        }
    }

    var color: String {
        switch self {
        case .generic:      return "#5C8A5C"
        case .birdwatching: return "#1565C0"
        case .workshop:     return "#F57F17"
        case .guidedTour:   return "#2E7D32"
        case .kids:         return "#AB47BC"
        case .photography:  return "#455A64"
        case .conservation: return "#00897B"
        case .nightEvent:   return "#283593"
        }
    }
}
