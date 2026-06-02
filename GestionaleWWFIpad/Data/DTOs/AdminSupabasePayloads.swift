//
//  AdminSupabasePayloads.swift
//  GestionaleWWFIpad
//

import Foundation

enum AdminSupabasePayloads {
    static func poi(_ poi: POI) -> [String: Any?] {
        [
            "p_id": poi.id.uuidString,
            "p_name": poi.name,
            "p_description": poi.poiDescription,
            "p_x": poi.x,
            "p_y": poi.y,
            "p_latitude": poi.latitude,
            "p_longitude": poi.longitude,
            "p_type": poi.typeRawValue,
            "p_photo_url": poi.photoURL,
            "p_qr_payload": poi.qrPayload,
            "p_is_start_point": poi.isStartPoint,
            "p_is_active": poi.isActive,
            "p_icon_name": poi.iconName,
            "p_numeric_code": poi.numericCode,
            "p_description_kids": poi.descriptionKids,
            "p_description_easy_read": poi.descriptionEasyRead,
            "p_ar_model_url": poi.arModelURL,
            "p_ar_animation_config": ARAnimationConfig.decode(from: poi.arAnimationConfig).jsonObject,
            "p_ar_model_tier": poi.arModelTier.rawValue,
            "p_clear_photo_url": poi.shouldClearPhotoURL,
            "p_clear_ar_model": poi.shouldClearARModel
        ]
    }

    static func trail(_ trail: Trail) -> [String: Any?] {
        [
            "p_id": trail.id.uuidString,
            "p_name": trail.name,
            "p_description": trail.trailDescription,
            "p_is_active": trail.isActive,
            "p_difficulty": trail.difficultyRawValue,
            "p_estimated_minutes": trail.estimatedMinutes,
            "p_cover_image_url": trail.coverImageURL,
            "p_start_poi_id": trail.startPOIId?.uuidString,
            "p_target_age": trail.targetAge,
            "p_description_kids": trail.descriptionKids,
            "p_description_easy_read": trail.descriptionEasyRead
        ]
    }

    static func trailSteps(_ trail: Trail) -> [[String: Any?]] {
        trail.sortedSteps.map { step in
            [
                "id": step.id.uuidString,
                "poi_id": step.poi?.id.uuidString,
                "step_order": step.stepOrder,
                "direction_hint": step.directionHint,
                "distance_meters": step.distanceMeters,
                "estimated_minutes": step.estimatedMinutes,
                "path_geometry": step.pathGeometry
            ]
        }
    }

    static func event(_ event: Event) -> [String: Any?] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = Calendar.current.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.timeZone = Calendar.current.timeZone
        timeFormatter.dateFormat = "HH:mm:ss"

        return [
            "p_id": event.id.uuidString,
            "p_name": event.name,
            "p_description": event.eventDescription,
            "p_category": event.categoryRawValue,
            "p_date": dateFormatter.string(from: event.date),
            "p_time_start": timeFormatter.string(from: event.timeStart),
            "p_time_end": timeFormatter.string(from: event.timeEnd),
            "p_max_participants": event.maxParticipants,
            "p_contact_info": event.contactInfo,
            "p_requirements": event.requirements,
            "p_target_audience": event.targetAudienceRawValue,
            "p_price": event.price,
            "p_image_url": event.imageURL,
            "p_is_active": event.isActive,
            "p_path_id": event.trail?.id.uuidString,
            "p_event_poi_id": event.eventPOI?.id.uuidString,
            "p_organizer_name": event.organizerName
        ]
    }

    static func content(_ content: Content) -> [String: Any?] {
        let jsonObject = content.data.flatMap { data in
            try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }

        return [
            "p_id": content.id.uuidString,
            "p_poi_id": content.poiId.uuidString,
            "p_type": content.typeRawValue,
            "p_tier": content.tierRawValue,
            "p_data": jsonObject,
            "p_file_url": content.fileURL,
            "p_sort_order": content.sortOrder
        ]
    }
}

extension POI {
    func toSupabaseParams() -> [String: Any?] {
        AdminSupabasePayloads.poi(self)
    }
}

extension Trail {
    func toSupabaseParams() -> [String: Any?] {
        AdminSupabasePayloads.trail(self)
    }

    func stepsToJSON() -> [[String: Any?]] {
        AdminSupabasePayloads.trailSteps(self)
    }
}

extension Event {
    func toSupabaseParams() -> [String: Any?] {
        AdminSupabasePayloads.event(self)
    }
}

extension Content {
    func toSupabaseParams() -> [String: Any?] {
        AdminSupabasePayloads.content(self)
    }
}
