import Foundation

func tableName(for tab: GamificationAdminTab) -> String {
    switch tab {
    case .dashboard: ""
    case .badges: "badges"
    case .species: "species"
    case .levels: "gamification_levels"
    case .rules: "gamification_rules"
    case .campaigns: "gamification_campaigns"
    }
}

func rowTitle(_ row: [String: Any]) -> String {
    rowString(row, "title") ?? rowString(row, "name") ?? "Elemento"
}

func rowSubtitle(_ row: [String: Any], tab: GamificationAdminTab) -> String {
    switch tab {
    case .dashboard: return ""
    case .badges: return rowString(row, "description") ?? "Badge"
    case .species: return rowString(row, "scientific_name") ?? rowString(row, "description") ?? "Specie"
    case .levels: return rowString(row, "description") ?? "Livello"
    case .rules: return rowString(row, "description") ?? rowString(row, "trigger_type") ?? "Regola"
    case .campaigns: return rowString(row, "description") ?? "Campagna stagionale"
    }
}

func rowDetail(_ row: [String: Any], tab: GamificationAdminTab) -> String {
    switch tab {
    case .dashboard:
        return ""
    case .badges:
        return "\(rowString(row, "category") ?? "categoria") - \(rowString(row, "rarity") ?? "rarity") - \(row["xp_reward"] as? Int ?? 0) XP"
    case .species:
        return "\(rowString(row, "category") ?? "categoria") - \(rowString(row, "rarity") ?? "rarity")"
    case .levels:
        return "Livello \(row["level_number"] as? Int ?? 0) - \(row["required_xp"] as? Int ?? 0) XP"
    case .rules:
        return "\(rowString(row, "trigger_type") ?? "trigger") - audience \(rowString(row, "audience") ?? "all")"
    case .campaigns:
        return "\(dateFromSupabase(row["starts_at"])?.formatted(date: .abbreviated, time: .omitted) ?? "Inizio aperto") - \(dateFromSupabase(row["ends_at"])?.formatted(date: .abbreviated, time: .omitted) ?? "Fine aperta")"
    }
}

func reference(row: [String: Any], titleKey: String) -> AdminReference? {
    guard let id = rowString(row, "id") else { return nil }
    return AdminReference(id: id, title: rowString(row, titleKey) ?? "Senza titolo")
}

func conditionJSON(type: RuleConditionType, count: Int, poiId: String?, pathId: String?, eventId: String?) -> [String: Any] {
    switch type {
    case .none:
        return [:]
    case .poiCountTotalGTE:
        return ["poi_count_total_gte": count]
    case .path:
        return pathId.map { ["path_id": $0] } ?? [:]
    case .poi:
        return poiId.map { ["poi_id": $0] } ?? [:]
    case .event:
        return eventId.map { ["event_id": $0] } ?? [:]
    case .species:
        return [:]
    case .completionPercent:
        var object: [String: Any] = ["required_completion_percent": 100]
        if let pathId { object["path_id"] = pathId }
        return object
    case .audioPercent:
        var object: [String: Any] = ["listened_percent_gte": 80]
        if let poiId { object["poi_id"] = poiId }
        return object
    }
}

func conditionDraft(
    from object: [String: Any],
    fallbackPOIId: String?,
    fallbackPathId: String?,
    fallbackEventId: String?
) -> (type: RuleConditionType, count: Int, poiId: String?, pathId: String?, eventId: String?) {
    if let count = intValue(object["poi_count_total_gte"]) {
        return (.poiCountTotalGTE, max(1, count), fallbackPOIId, fallbackPathId, fallbackEventId)
    }
    if let pathId = copiedString(object["path_id"]) {
        return (.path, 1, fallbackPOIId, pathId, fallbackEventId)
    }
    if let poiId = copiedString(object["poi_id"]) {
        return (.poi, 1, poiId, fallbackPathId, fallbackEventId)
    }
    if let eventId = copiedString(object["event_id"]) {
        return (.event, 1, fallbackPOIId, fallbackPathId, eventId)
    }
    if intValue(object["required_completion_percent"]) != nil {
        return (.completionPercent, 1, fallbackPOIId, copiedString(object["path_id"]) ?? fallbackPathId, fallbackEventId)
    }
    if intValue(object["listened_percent_gte"]) != nil {
        return (.audioPercent, 1, copiedString(object["poi_id"]) ?? fallbackPOIId, fallbackPathId, fallbackEventId)
    }
    return (.none, 1, fallbackPOIId, fallbackPathId, fallbackEventId)
}

func rowString(_ row: [String: Any], _ key: String) -> String? {
    copiedString(row[key])
}

func copiedString(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    return "\(string)"
}

func intValue(_ value: Any?) -> Int? {
    if let int = value as? Int { return int }
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String { return Int(string) }
    return nil
}

func isoString(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

func dateFromSupabase(_ value: Any?) -> Date? {
    guard let string = value as? String else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
}

