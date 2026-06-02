import Foundation
import Security

enum GamificationAdminTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case badges = "Badge"
    case species = "Specie"
    case levels = "Livelli"
    case rules = "Regole"
    case campaigns = "Campagne"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.xaxis"
        case .badges: "rosette"
        case .species: "leaf.fill"
        case .levels: "seal.fill"
        case .rules: "slider.horizontal.3"
        case .campaigns: "calendar"
        }
    }
}

enum AdminEditor: Identifiable {
    case badge(GamificationBadge)
    case species(GamificationSpecies)
    case level(GamificationLevel)
    case rule(GamificationRule)
    case campaign(GamificationCampaign)

    var id: String {
        switch self {
        case .badge(let m): return "badge-\(m.id)"
        case .species(let m): return "species-\(m.id)"
        case .level(let m): return "level-\(m.id)"
        case .rule(let m): return "rule-\(m.id)"
        case .campaign(let m): return "campaign-\(m.id)"
        }
    }
}

enum BadgeCategory: String, CaseIterable, Identifiable {
    case exploration
    case nature
    case events
    case seasonal
    case kids
    case special
    case loyalty

    var id: String { rawValue }
    var title: String {
        switch self {
        case .exploration: "Esplorazione"
        case .nature: "Natura"
        case .events: "Eventi"
        case .seasonal: "Stagionali"
        case .kids: "Kids"
        case .special: "Speciali"
        case .loyalty: "Fedelta"
        }
    }
}

enum SpeciesCategory: String, CaseIterable, Identifiable {
    case fauna
    case flora
    case habitat
    case geology
    case conservation
    case history

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fauna: "Fauna"
        case .flora: "Flora"
        case .habitat: "Habitat"
        case .geology: "Geologia"
        case .conservation: "Conservazione"
        case .history: "Storia"
        }
    }
}

enum GamificationRarity: String, CaseIterable, Identifiable {
    case common
    case uncommon
    case rare
    case legendary

    var id: String { rawValue }
    var title: String {
        switch self {
        case .common: "Comune"
        case .uncommon: "Non comune"
        case .rare: "Rara"
        case .legendary: "Leggendaria"
        }
    }
}

enum RuleTriggerType: String, CaseIterable, Identifiable {
    case poiScanned = "poi_scanned"
    case trailStarted = "trail_started"
    case trailCompleted = "trail_completed"
    case allPOIsInTrailCompleted = "all_pois_in_trail_completed"
    case eventRegistered = "event_registered"
    case eventCompleted = "event_completed"
    case audioGuideListened = "audio_guide_listened"
    case speciesUnlocked = "species_unlocked"
    case badgeUnlocked = "badge_unlocked"
    case dailyVisit = "daily_visit"
    case seasonalCampaign = "seasonal_campaign"
    case manualAdminGrant = "manual_admin_grant"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .poiScanned: "POI scansionato"
        case .trailStarted: "Percorso iniziato"
        case .trailCompleted: "Percorso completato"
        case .allPOIsInTrailCompleted: "Tutti i POI del percorso"
        case .eventRegistered: "Evento prenotato"
        case .eventCompleted: "Evento completato"
        case .audioGuideListened: "Audio guida ascoltata"
        case .speciesUnlocked: "Specie scoperta"
        case .badgeUnlocked: "Badge sbloccato"
        case .dailyVisit: "Visita giornaliera"
        case .seasonalCampaign: "Campagna stagionale"
        case .manualAdminGrant: "Assegnazione manuale"
        }
    }
}

enum RuleConditionType: String, CaseIterable, Identifiable {
    case none
    case poiCountTotalGTE
    case path
    case poi
    case event
    case species
    case completionPercent
    case audioPercent

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Nessuna condizione"
        case .poiCountTotalGTE: "Numero POI visitati"
        case .path: "Percorso specifico"
        case .poi: "POI specifico"
        case .event: "Evento specifico"
        case .species: "Specie specifica"
        case .completionPercent: "Completamento percorso"
        case .audioPercent: "Percentuale audio"
        }
    }
}

enum GamificationAudience: String, CaseIterable, Identifiable {
    case all
    case kids
    case adults
    case registered
    case anonymous

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Tutti"
        case .kids: "Kids"
        case .adults: "Adulti"
        case .registered: "Registrati"
        case .anonymous: "Ospiti"
        }
    }
}

struct AdminReference: Identifiable, Hashable {
    let id: String
    let title: String
}

struct AnalyticsMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

struct AnalyticsRankRow: Identifiable {
    let id: String
    let title: String
    let count: Int
}

struct GamificationAnalytics {
    var metrics: [AnalyticsMetric] = []
    var badges: [AnalyticsRankRow] = []
    var species: [AnalyticsRankRow] = []
    var trails: [AnalyticsRankRow] = []
    var events: [AnalyticsRankRow] = []
    var suspiciousLogs: [[String: Any]] = []
}

enum GamificationError: LocalizedError {
    case network(String)
    case permissionRLS(String)
    case databaseViolation(String)
    case dataCorruption(String)
    case storage(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network(let detail):
            return "Errore di rete: controlla la tua connessione internet. Dettagli: \(detail)"
        case .permissionRLS(let detail):
            return "Errore di autorizzazione (RLS): non hai i permessi necessari per completare l'operazione. Dettagli: \(detail)"
        case .databaseViolation(let detail):
            return "Errore database: l'operazione viola le regole di validazione o i vincoli del database. Dettagli: \(detail)"
        case .dataCorruption(let detail):
            return "Errore dati: i dati o l'immagine caricati sono corrotti o non validi. Dettagli: \(detail)"
        case .storage(let detail):
            return "Errore di archiviazione: impossibile salvare l'immagine. Dettagli: \(detail)"
        case .unknown(let detail):
            return "Errore imprevisto: \(detail)"
        }
    }

    static func map(_ error: Error) -> GamificationError {
        if let sbError = error as? SupabaseError {
            switch sbError {
            case .networkError(let msg):
                return .network(msg)
            case .authError(let msg):
                return .permissionRLS(msg)
            case .apiError(let msg):
                let lowerMsg = msg.lowercased()
                if lowerMsg.contains("row-level security") || lowerMsg.contains("policy") || lowerMsg.contains("permission denied") || lowerMsg.contains("403") || lowerMsg.contains("401") {
                    return .permissionRLS(msg)
                } else if lowerMsg.contains("violates") || lowerMsg.contains("constraint") || lowerMsg.contains("null") || lowerMsg.contains("400") {
                    return .databaseViolation(msg)
                }
                return .unknown(msg)
            case .storageError(let msg):
                return .storage(msg)
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(error.localizedDescription)
        }

        return .unknown(error.localizedDescription)
    }
}

