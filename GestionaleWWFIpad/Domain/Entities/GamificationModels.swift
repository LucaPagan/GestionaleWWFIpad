//
//  GamificationModels.swift
//  GestionaleWWFIpad
//

import Foundation
import SwiftData

@Model
final class GamificationBadge {
    @Attribute(.unique) var id: UUID
    var title: String
    var badgeDescription: String
    var imageURL: String?
    @Attribute(.externalStorage) var photoData: Data?
    var categoryRawValue: String
    var rarityRawValue: String
    var isHidden: Bool
    var unlockHint: String
    var sortOrder: Int
    var xpReward: Int
    var relatedPOIId: UUID?
    var relatedPathId: UUID?
    var relatedEventId: UUID?
    var relatedSpeciesId: UUID?
    var criteriaConditionRawValue: String
    var criteriaValue: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        badgeDescription: String = "",
        imageURL: String? = nil,
        photoData: Data? = nil,
        categoryRawValue: String = "exploration",
        rarityRawValue: String = "common",
        isHidden: Bool = false,
        unlockHint: String = "",
        sortOrder: Int = 0,
        xpReward: Int = 0,
        relatedPOIId: UUID? = nil,
        relatedPathId: UUID? = nil,
        relatedEventId: UUID? = nil,
        relatedSpeciesId: UUID? = nil,
        criteriaConditionRawValue: String = "none",
        criteriaValue: Int = 1,
        isActive: Bool = true,
        needsSync: Bool = true
    ) {
        self.id = id
        self.title = title
        self.badgeDescription = badgeDescription
        self.imageURL = imageURL
        self.photoData = photoData
        self.categoryRawValue = categoryRawValue
        self.rarityRawValue = rarityRawValue
        self.isHidden = isHidden
        self.unlockHint = unlockHint
        self.sortOrder = sortOrder
        self.xpReward = xpReward
        self.relatedPOIId = relatedPOIId
        self.relatedPathId = relatedPathId
        self.relatedEventId = relatedEventId
        self.relatedSpeciesId = relatedSpeciesId
        self.criteriaConditionRawValue = criteriaConditionRawValue
        self.criteriaValue = criteriaValue
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }
}

@Model
final class GamificationSpecies {
    @Attribute(.unique) var id: UUID
    var name: String
    var scientificName: String
    var speciesDescription: String
    var descriptionKids: String
    var descriptionEasyRead: String
    var categoryRawValue: String
    var rarityRawValue: String
    var habitat: String
    var imageURL: String?
    @Attribute(.externalStorage) var photoData: Data?
    var iconName: String
    var relatedPOIId: UUID?
    var relatedPathId: UUID?
    var unlockConditionRawValue: String
    var unlockValue: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        scientificName: String = "",
        speciesDescription: String = "",
        descriptionKids: String = "",
        descriptionEasyRead: String = "",
        categoryRawValue: String = "fauna",
        rarityRawValue: String = "common",
        habitat: String = "",
        imageURL: String? = nil,
        photoData: Data? = nil,
        iconName: String = "leaf.fill",
        relatedPOIId: UUID? = nil,
        relatedPathId: UUID? = nil,
        unlockConditionRawValue: String = "none",
        unlockValue: Int = 1,
        isActive: Bool = true,
        needsSync: Bool = true
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.speciesDescription = speciesDescription
        self.descriptionKids = descriptionKids
        self.descriptionEasyRead = descriptionEasyRead
        self.categoryRawValue = categoryRawValue
        self.rarityRawValue = rarityRawValue
        self.habitat = habitat
        self.imageURL = imageURL
        self.photoData = photoData
        self.iconName = iconName
        self.relatedPOIId = relatedPOIId
        self.relatedPathId = relatedPathId
        self.unlockConditionRawValue = unlockConditionRawValue
        self.unlockValue = unlockValue
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }
}

@Model
final class GamificationLevel {
    @Attribute(.unique) var id: UUID
    var levelNumber: Int
    var title: String
    var levelDescription: String
    var requiredXP: Int
    var iconName: String
    var imageURL: String?
    @Attribute(.externalStorage) var photoData: Data?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        levelNumber: Int = 1,
        title: String = "",
        levelDescription: String = "",
        requiredXP: Int = 0,
        iconName: String = "seal.fill",
        imageURL: String? = nil,
        photoData: Data? = nil,
        isActive: Bool = true,
        needsSync: Bool = true
    ) {
        self.id = id
        self.levelNumber = levelNumber
        self.title = title
        self.levelDescription = levelDescription
        self.requiredXP = requiredXP
        self.iconName = iconName
        self.imageURL = imageURL
        self.photoData = photoData
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }
}

@Model
final class GamificationRule {
    @Attribute(.unique) var id: UUID
    var title: String
    var ruleDescription: String
    var triggerTypeRawValue: String
    var conditionTypeRawValue: String
    var conditionCount: Int
    var conditionPathId: UUID?
    var conditionPOIId: UUID?
    var conditionEventId: UUID?
    var conditionSpeciesId: UUID?
    var requiredCompletionPercent: Int
    var minimumDurationMinutes: Int
    var requireOrderedScans: Bool
    var audioPercent: Int
    var xpReward: Int
    var rewardBadgeId: UUID?
    var rewardSpeciesId: UUID?
    var profileTitle: String
    var collectionItemKey: String
    var levelCheckOnly: Bool
    var hasDateRange: Bool
    var startsAt: Date
    var endsAt: Date
    var hasCooldown: Bool
    var cooldownSeconds: Int
    var isHidden: Bool
    var isRepeatable: Bool
    var audienceRawValue: String
    var priority: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        ruleDescription: String = "",
        triggerTypeRawValue: String = "poi_scanned",
        conditionTypeRawValue: String = "none",
        conditionCount: Int = 1,
        conditionPathId: UUID? = nil,
        conditionPOIId: UUID? = nil,
        conditionEventId: UUID? = nil,
        conditionSpeciesId: UUID? = nil,
        requiredCompletionPercent: Int = 100,
        minimumDurationMinutes: Int = 0,
        requireOrderedScans: Bool = false,
        audioPercent: Int = 100,
        xpReward: Int = 0,
        rewardBadgeId: UUID? = nil,
        rewardSpeciesId: UUID? = nil,
        profileTitle: String = "",
        collectionItemKey: String = "",
        levelCheckOnly: Bool = false,
        hasDateRange: Bool = false,
        startsAt: Date = Date(),
        endsAt: Date = Date().addingTimeInterval(86400 * 30),
        hasCooldown: Bool = false,
        cooldownSeconds: Int = 86400,
        isHidden: Bool = false,
        isRepeatable: Bool = false,
        audienceRawValue: String = "all",
        priority: Int = 0,
        isActive: Bool = true,
        needsSync: Bool = true
    ) {
        self.id = id
        self.title = title
        self.ruleDescription = ruleDescription
        self.triggerTypeRawValue = triggerTypeRawValue
        self.conditionTypeRawValue = conditionTypeRawValue
        self.conditionCount = conditionCount
        self.conditionPathId = conditionPathId
        self.conditionPOIId = conditionPOIId
        self.conditionEventId = conditionEventId
        self.conditionSpeciesId = conditionSpeciesId
        self.requiredCompletionPercent = requiredCompletionPercent
        self.minimumDurationMinutes = minimumDurationMinutes
        self.requireOrderedScans = requireOrderedScans
        self.audioPercent = audioPercent
        self.xpReward = xpReward
        self.rewardBadgeId = rewardBadgeId
        self.rewardSpeciesId = rewardSpeciesId
        self.profileTitle = profileTitle
        self.collectionItemKey = collectionItemKey
        self.levelCheckOnly = levelCheckOnly
        self.hasDateRange = hasDateRange
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.hasCooldown = hasCooldown
        self.cooldownSeconds = cooldownSeconds
        self.isHidden = isHidden
        self.isRepeatable = isRepeatable
        self.audienceRawValue = audienceRawValue
        self.priority = priority
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }
}

@Model
final class GamificationCampaign {
    @Attribute(.unique) var id: UUID
    var title: String
    var campaignDescription: String
    var imageURL: String?
    @Attribute(.externalStorage) var photoData: Data?
    var startsAt: Date
    var endsAt: Date
    var ruleIdsRaw: String // JSON array of UUID strings
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        campaignDescription: String = "",
        imageURL: String? = nil,
        photoData: Data? = nil,
        startsAt: Date = Date(),
        endsAt: Date = Date().addingTimeInterval(86400 * 30),
        ruleIdsRaw: String = "[]",
        isActive: Bool = true,
        needsSync: Bool = true
    ) {
        self.id = id
        self.title = title
        self.campaignDescription = campaignDescription
        self.imageURL = imageURL
        self.photoData = photoData
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.ruleIdsRaw = ruleIdsRaw
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
    }
}

// MARK: - Gamification Payload Helpers

private func gamificationIntValue(_ value: Any?) -> Int? {
    if let int = value as? Int { return int }
    if let double = value as? Double { return Int(double) }
    if let string = value as? String { return Int(string) }
    return nil
}

private func gamificationUUID(_ value: Any?) -> UUID? {
    guard let string = value as? String else { return nil }
    return UUID(uuidString: string)
}

private func gamificationConditionState(
    from object: [String: Any],
    fallbackPOIId: UUID?,
    fallbackPathId: UUID?,
    fallbackEventId: UUID?,
    fallbackSpeciesId: UUID?
) -> (
    type: String,
    count: Int,
    poiId: UUID?,
    pathId: UUID?,
    eventId: UUID?,
    speciesId: UUID?,
    completionPercent: Int?,
    minimumDurationMinutes: Int?,
    requireOrderedScans: Bool?,
    audioPercent: Int?
) {
    let poiId = gamificationUUID(object["poi_id"]) ?? fallbackPOIId
    let pathId = gamificationUUID(object["path_id"]) ?? fallbackPathId
    let eventId = gamificationUUID(object["event_id"]) ?? fallbackEventId
    let speciesId = gamificationUUID(object["species_id"]) ?? fallbackSpeciesId

    if let completion = gamificationIntValue(object["required_completion_percent"]) {
        return (
            "completionPercent",
            1,
            poiId,
            pathId,
            eventId,
            speciesId,
            completion,
            gamificationIntValue(object["minimum_duration_minutes"]),
            object["require_ordered_scans"] as? Bool,
            nil
        )
    }
    if let audio = gamificationIntValue(object["listened_percent_gte"]) {
        return ("audioPercent", 1, poiId, pathId, eventId, speciesId, nil, nil, nil, audio)
    }
    if speciesId != nil {
        return ("species", 1, poiId, pathId, eventId, speciesId, nil, nil, nil, nil)
    }
    if let count = gamificationIntValue(object["poi_count_total_gte"]) {
        return ("poiCountTotalGTE", max(1, count), poiId, pathId, eventId, speciesId, nil, nil, nil, nil)
    }
    if pathId != nil {
        return ("path", 1, poiId, pathId, eventId, speciesId, nil, nil, nil, nil)
    }
    if poiId != nil {
        return ("poi", 1, poiId, pathId, eventId, speciesId, nil, nil, nil, nil)
    }
    if eventId != nil {
        return ("event", 1, poiId, pathId, eventId, speciesId, nil, nil, nil, nil)
    }
    return ("none", 1, poiId, pathId, eventId, speciesId, nil, nil, nil, nil)
}

private func gamificationConditionPayload(
    type: String,
    count: Int,
    poiId: UUID?,
    pathId: UUID?,
    eventId: UUID?,
    speciesId: UUID? = nil,
    requiredCompletionPercent: Int = 100,
    minimumDurationMinutes: Int = 0,
    requireOrderedScans: Bool = false,
    audioPercent: Int = 80
) -> [String: Any] {
    switch type {
    case "poiCountTotalGTE":
        return ["poi_count_total_gte": max(1, count)]
    case "path":
        return pathId.map { ["path_id": $0.uuidString] } ?? [:]
    case "poi":
        return poiId.map { ["poi_id": $0.uuidString] } ?? [:]
    case "event":
        return eventId.map { ["event_id": $0.uuidString] } ?? [:]
    case "species":
        return speciesId.map { ["species_id": $0.uuidString] } ?? [:]
    case "completionPercent":
        var object: [String: Any] = ["required_completion_percent": requiredCompletionPercent]
        if let pathId { object["path_id"] = pathId.uuidString }
        if minimumDurationMinutes > 0 { object["minimum_duration_minutes"] = minimumDurationMinutes }
        object["require_ordered_scans"] = requireOrderedScans
        return object
    case "audioPercent":
        var object: [String: Any] = ["listened_percent_gte": audioPercent]
        if let poiId { object["poi_id"] = poiId.uuidString }
        return object
    default:
        return [:]
    }
}

private func gamificationRewardPayload(
    xpReward: Int,
    rewardBadgeId: UUID?,
    rewardSpeciesId: UUID?,
    profileTitle: String,
    collectionItemKey: String,
    levelCheckOnly: Bool
) -> [String: Any] {
    var object: [String: Any] = [:]
    if xpReward > 0 { object["xp"] = xpReward }
    if let rewardBadgeId { object["badge_id"] = rewardBadgeId.uuidString }
    if let rewardSpeciesId { object["species_id"] = rewardSpeciesId.uuidString }
    if !profileTitle.isEmpty { object["profile_title"] = profileTitle }
    if !collectionItemKey.isEmpty { object["collection_item"] = collectionItemKey }
    if levelCheckOnly { object["level_check"] = true }
    return object
}

// MARK: - Supabase Extensions

extension GamificationBadge {
    func updateFromRemote(_ data: [String: Any]) {
        if let title = data["title"] as? String { self.title = title }
        if let description = data["description"] as? String { self.badgeDescription = description }
        if let imageURL = data["image_url"] as? String { self.imageURL = imageURL }
        if let category = data["category"] as? String { self.categoryRawValue = category }
        if let rarity = data["rarity"] as? String { self.rarityRawValue = rarity }
        if let isHidden = data["is_hidden"] as? Bool { self.isHidden = isHidden }
        if let unlockHint = data["unlock_hint"] as? String { self.unlockHint = unlockHint }
        if let sortOrder = data["sort_order"] as? Int { self.sortOrder = sortOrder }
        if let xpReward = data["xp_reward"] as? Int { self.xpReward = xpReward }
        if let poiStr = data["related_poi_id"] as? String { self.relatedPOIId = UUID(uuidString: poiStr) }
        if let pathStr = data["related_path_id"] as? String { self.relatedPathId = UUID(uuidString: pathStr) }
        if let eventStr = data["related_event_id"] as? String { self.relatedEventId = UUID(uuidString: eventStr) }
        if let speciesStr = data["related_species_id"] as? String { self.relatedSpeciesId = UUID(uuidString: speciesStr) }
        if let isActive = data["is_active"] as? Bool { self.isActive = isActive }
        if let criteria = data["criteria"] as? [String: Any] {
            let parsed = gamificationConditionState(
                from: criteria,
                fallbackPOIId: relatedPOIId,
                fallbackPathId: relatedPathId,
                fallbackEventId: relatedEventId,
                fallbackSpeciesId: relatedSpeciesId
            )
            criteriaConditionRawValue = parsed.type
            criteriaValue = parsed.count
            relatedPOIId = parsed.poiId
            relatedPathId = parsed.pathId
            relatedEventId = parsed.eventId
            relatedSpeciesId = parsed.speciesId
        }
        self.needsSync = false
    }

    func toSupabaseParams() -> [String: Any?] {
        let criteriaObj = gamificationConditionPayload(
            type: criteriaConditionRawValue,
            count: criteriaValue,
            poiId: relatedPOIId,
            pathId: relatedPathId,
            eventId: relatedEventId,
            speciesId: relatedSpeciesId
        )
        return [
            "id": id.uuidString,
            "title": title,
            "description": badgeDescription,
            "image_url": imageURL,
            "category": categoryRawValue,
            "rarity": rarityRawValue,
            "is_hidden": isHidden,
            "unlock_hint": unlockHint.isEmpty ? nil : unlockHint,
            "sort_order": sortOrder,
            "xp_reward": xpReward,
            "related_path_id": relatedPathId?.uuidString,
            "related_event_id": relatedEventId?.uuidString,
            "related_species_id": relatedSpeciesId?.uuidString,
            "criteria": criteriaObj,
            "is_active": isActive
        ]
    }
}

extension GamificationSpecies {
    func updateFromRemote(_ data: [String: Any]) {
        if let name = data["name"] as? String { self.name = name }
        if let scName = data["scientific_name"] as? String { self.scientificName = scName }
        if let desc = data["description"] as? String { self.speciesDescription = desc }
        if let descKids = data["description_kids"] as? String { self.descriptionKids = descKids }
        if let descEasy = data["description_easy_read"] as? String { self.descriptionEasyRead = descEasy }
        if let cat = data["category"] as? String { self.categoryRawValue = cat }
        if let rar = data["rarity"] as? String { self.rarityRawValue = rar }
        if let hab = data["habitat"] as? String { self.habitat = hab }
        if let img = data["image_url"] as? String { self.imageURL = img }
        if let ic = data["icon_name"] as? String { self.iconName = ic }
        if let poiStr = data["related_poi_id"] as? String { self.relatedPOIId = UUID(uuidString: poiStr) }
        if let pathStr = data["related_path_id"] as? String { self.relatedPathId = UUID(uuidString: pathStr) }
        if let isActive = data["is_active"] as? Bool { self.isActive = isActive }
        if let criteria = data["unlock_criteria_json"] as? [String: Any] {
            let parsed = gamificationConditionState(
                from: criteria,
                fallbackPOIId: relatedPOIId,
                fallbackPathId: relatedPathId,
                fallbackEventId: nil,
                fallbackSpeciesId: nil
            )
            unlockConditionRawValue = parsed.type
            unlockValue = parsed.count
            relatedPOIId = parsed.poiId
            relatedPathId = parsed.pathId
        }
        self.needsSync = false
    }

    func toSupabaseParams() -> [String: Any?] {
        let criteriaObj = gamificationConditionPayload(
            type: unlockConditionRawValue,
            count: unlockValue,
            poiId: relatedPOIId,
            pathId: relatedPathId,
            eventId: nil
        )
        return [
            "id": id.uuidString,
            "name": name,
            "scientific_name": scientificName.isEmpty ? nil : scientificName,
            "description": speciesDescription,
            "description_kids": descriptionKids.isEmpty ? nil : descriptionKids,
            "description_easy_read": descriptionEasyRead.isEmpty ? nil : descriptionEasyRead,
            "category": categoryRawValue,
            "rarity": rarityRawValue,
            "habitat": habitat.isEmpty ? nil : habitat,
            "image_url": imageURL,
            "icon_name": iconName,
            "related_poi_id": relatedPOIId?.uuidString,
            "related_path_id": relatedPathId?.uuidString,
            "unlock_criteria_json": criteriaObj,
            "is_active": isActive
        ]
    }
}

extension GamificationLevel {
    func updateFromRemote(_ data: [String: Any]) {
        if let num = data["level_number"] as? Int { self.levelNumber = num }
        if let title = data["title"] as? String { self.title = title }
        if let desc = data["description"] as? String { self.levelDescription = desc }
        if let xp = data["required_xp"] as? Int { self.requiredXP = xp }
        if let ic = data["icon_name"] as? String { self.iconName = ic }
        if let img = data["image_url"] as? String { self.imageURL = img }
        if let act = data["is_active"] as? Bool { self.isActive = act }
        self.needsSync = false
    }

    func toSupabaseParams() -> [String: Any?] {
        return [
            "id": id.uuidString,
            "level_number": levelNumber,
            "title": title,
            "description": levelDescription.isEmpty ? nil : levelDescription,
            "required_xp": requiredXP,
            "icon_name": iconName,
            "image_url": imageURL,
            "is_active": isActive
        ]
    }
}

extension GamificationRule {
    func updateFromRemote(_ data: [String: Any]) {
        if let title = data["title"] as? String { self.title = title }
        if let desc = data["description"] as? String { self.ruleDescription = desc }
        if let trig = data["trigger_type"] as? String { self.triggerTypeRawValue = trig }
        if let act = data["is_active"] as? Bool { self.isActive = act }
        if let hid = data["is_hidden"] as? Bool { self.isHidden = hid }
        if let rep = data["is_repeatable"] as? Bool { self.isRepeatable = rep }
        if let aud = data["audience"] as? String { self.audienceRawValue = aud }
        if let pri = data["priority"] as? Int { self.priority = pri }
        if let xp = data["xp_reward"] as? Int { self.xpReward = xp }
        if let bdgStr = data["reward_badge_id"] as? String { self.rewardBadgeId = UUID(uuidString: bdgStr) }
        if let spcStr = data["reward_species_id"] as? String { self.rewardSpeciesId = UUID(uuidString: spcStr) }
        if let pt = data["profile_title"] as? String { self.profileTitle = pt }
        if let cik = data["collection_item_key"] as? String { self.collectionItemKey = cik }
        if let lco = data["level_check_only"] as? Bool { self.levelCheckOnly = lco }
        
        let df = ISO8601DateFormatter()
        if let saStr = data["starts_at"] as? String, let d = df.date(from: saStr) { self.startsAt = d; self.hasDateRange = true }
        if let eaStr = data["ends_at"] as? String, let d = df.date(from: eaStr) { self.endsAt = d; self.hasDateRange = true }
        if let cs = data["cooldown_seconds"] as? Int { self.cooldownSeconds = cs; self.hasCooldown = true }
        
        if let cond = data["conditions_json"] as? [String: Any] ?? data["conditions"] as? [String: Any] {
            let parsed = gamificationConditionState(
                from: cond,
                fallbackPOIId: conditionPOIId,
                fallbackPathId: conditionPathId,
                fallbackEventId: conditionEventId,
                fallbackSpeciesId: conditionSpeciesId
            )
            conditionTypeRawValue = parsed.type
            conditionCount = parsed.count
            conditionPOIId = parsed.poiId
            conditionPathId = parsed.pathId
            conditionEventId = parsed.eventId
            conditionSpeciesId = parsed.speciesId
            if let completionPercent = parsed.completionPercent {
                requiredCompletionPercent = completionPercent
            }
            if let minimumDurationMinutes = parsed.minimumDurationMinutes {
                self.minimumDurationMinutes = minimumDurationMinutes
            }
            if let requireOrderedScans = parsed.requireOrderedScans {
                self.requireOrderedScans = requireOrderedScans
            }
            if let audioPercent = parsed.audioPercent {
                self.audioPercent = audioPercent
            }
        }
        if let rew = data["reward_json"] as? [String: Any] ?? data["reward"] as? [String: Any] {
            if let xp = gamificationIntValue(rew["xp"]) { xpReward = xp }
            if let badgeId = gamificationUUID(rew["badge_id"]) { rewardBadgeId = badgeId }
            if let speciesId = gamificationUUID(rew["species_id"]) { rewardSpeciesId = speciesId }
            if let profileTitle = rew["profile_title"] as? String { self.profileTitle = profileTitle }
            if let collectionItemKey = rew["collection_item"] as? String { self.collectionItemKey = collectionItemKey }
            if let levelCheckOnly = rew["level_check"] as? Bool { self.levelCheckOnly = levelCheckOnly }
        }
        self.needsSync = false
    }

    func toSupabaseParams() -> [String: Any?] {
        let df = ISO8601DateFormatter()
        let condObj = gamificationConditionPayload(
            type: conditionTypeRawValue,
            count: conditionCount,
            poiId: conditionPOIId,
            pathId: conditionPathId,
            eventId: conditionEventId,
            speciesId: conditionSpeciesId,
            requiredCompletionPercent: requiredCompletionPercent,
            minimumDurationMinutes: minimumDurationMinutes,
            requireOrderedScans: requireOrderedScans,
            audioPercent: audioPercent
        )
        let rewObj = gamificationRewardPayload(
            xpReward: xpReward,
            rewardBadgeId: rewardBadgeId,
            rewardSpeciesId: rewardSpeciesId,
            profileTitle: profileTitle,
            collectionItemKey: collectionItemKey,
            levelCheckOnly: levelCheckOnly
        )
        
        return [
            "id": id.uuidString,
            "title": title,
            "description": ruleDescription.isEmpty ? nil : ruleDescription,
            "trigger_type": triggerTypeRawValue,
            "conditions_json": condObj,
            "reward_json": rewObj,
            "is_active": isActive,
            "is_hidden": isHidden,
            "is_repeatable": isRepeatable,
            "audience": audienceRawValue,
            "priority": priority,
            "xp_reward": xpReward,
            "reward_badge_id": rewardBadgeId?.uuidString,
            "reward_species_id": rewardSpeciesId?.uuidString,
            "profile_title": profileTitle.isEmpty ? nil : profileTitle,
            "collection_item_key": collectionItemKey.isEmpty ? nil : collectionItemKey,
            "level_check_only": levelCheckOnly,
            "starts_at": hasDateRange ? df.string(from: startsAt) : nil,
            "ends_at": hasDateRange ? df.string(from: endsAt) : nil,
            "cooldown_seconds": hasCooldown ? cooldownSeconds : nil
        ]
    }
}

extension GamificationCampaign {
    func updateFromRemote(_ data: [String: Any]) {
        if let title = data["title"] as? String { self.title = title }
        if let desc = data["description"] as? String { self.campaignDescription = desc }
        if let img = data["image_url"] as? String { self.imageURL = img }
        if let act = data["is_active"] as? Bool { self.isActive = act }
        
        let df = ISO8601DateFormatter()
        if let saStr = data["starts_at"] as? String, let d = df.date(from: saStr) { self.startsAt = d }
        if let eaStr = data["ends_at"] as? String, let d = df.date(from: eaStr) { self.endsAt = d }
        
        if let rules = data["rules"] as? [String] ?? data["rule_ids"] as? [String],
           let jsonData = try? JSONSerialization.data(withJSONObject: rules),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.ruleIdsRaw = jsonString
        }
        self.needsSync = false
    }

    func toSupabaseParams() -> [String: Any?] {
        let df = ISO8601DateFormatter()
        let rulesArr = (try? JSONSerialization.jsonObject(with: Data(ruleIdsRaw.utf8))) as? [String] ?? []
        return [
            "id": id.uuidString,
            "title": title,
            "description": campaignDescription,
            "starts_at": df.string(from: startsAt),
            "ends_at": df.string(from: endsAt),
            "rules": rulesArr,
            "image_url": imageURL,
            "is_active": isActive
        ]
    }
}
