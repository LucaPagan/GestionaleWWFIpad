//
//  POI.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import Foundation
import SwiftData
import CoreGraphics

@Model
final class POI {
    var id: UUID
    var name: String
    var poiDescription: String
    var x: Double
    var y: Double
    var type: POIType
    var photoData: Data?
    var qrPayload: String
    var isStartPoint: Bool  

    init(
        name: String,
        description: String,
        x: Double,
        y: Double,
        type: POIType = .generic,
        photoData: Data? = nil,
        isStartPoint: Bool = false,
        fixedID: UUID? = nil
    ) {
        let newID = fixedID ?? UUID()
        self.id = newID
        self.name = name
        self.poiDescription = description
        self.x = x
        self.y = y
        self.type = type
        self.photoData = photoData
        self.qrPayload = "ASTRONI_POI_\(newID.uuidString)"
        self.isStartPoint = isStartPoint
    }
}

enum POIType: String, Codable, CaseIterable {
    case generic     = "Generico"
    case nature      = "Natura"
    case historical  = "Storico"
    case service     = "Servizio"
    case viewpoint   = "Belvedere"
    case danger      = "Attenzione"

    var icon: String {
        switch self {
        case .generic:    return "mappin.circle.fill"
        case .nature:     return "leaf.fill"
        case .historical: return "building.columns.fill"
        case .service:    return "wrench.and.screwdriver.fill"
        case .viewpoint:  return "binoculars.fill"
        case .danger:     return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .generic:    return "#5C8A5C"
        case .nature:     return "#2E7D32"
        case .historical: return "#795548"
        case .service:    return "#1565C0"
        case .viewpoint:  return "#6A1B9A"
        case .danger:     return "#C62828"
        }
    }
}
