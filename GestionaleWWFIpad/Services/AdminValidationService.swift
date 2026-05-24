import Foundation
import SwiftData

struct AdminValidationIssue: Identifiable, Equatable {
    enum Severity {
        case error
        case warning
    }

    let id = UUID()
    let severity: Severity
    let message: String
}

struct BundleReadiness: Equatable {
    let tier: ContentTier
    let isReady: Bool
    let manifestSHA256: String?
    let generatedAt: Date?
    let updatedAt: Date?
    let sizeBytes: Int64
    let generationStatus: String?

    var isUsable: Bool {
        isReady &&
        generationStatus == "ready" &&
        manifestSHA256?.isEmpty == false &&
        sizeBytes > 0
    }
}

enum AdminValidationService {
    static func trailIssues(trail: Trail, contents: [Content]) -> [AdminValidationIssue] {
        trailIssues(
            name: trail.name,
            estimatedMinutes: trail.estimatedMinutes ?? 0,
            isActive: trail.isActive,
            startPOI: trail.startPOIId.flatMap { id in trail.steps.compactMap(\.poi).first { $0.id == id } },
            steps: trail.sortedSteps.map {
                TrailDraftStep(
                    poi: $0.poi,
                    instructions: $0.directionHint ?? "",
                    distanceMeters: $0.distanceMeters,
                    estimatedMinutes: $0.estimatedMinutes,
                    pathGeometry: $0.pathGeometry
                )
            },
            contents: contents
        )
    }

    static func trailIssues(
        name: String,
        estimatedMinutes: Int,
        isActive: Bool,
        startPOI: POI?,
        steps: [TrailDraftStep],
        contents: [Content]
    ) -> [AdminValidationIssue] {
        var issues: [AdminValidationIssue] = []
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            issues.append(.init(severity: .error, message: "Nome percorso mancante."))
        }

        if estimatedMinutes <= 0 {
            issues.append(.init(severity: .error, message: "Durata percorso non valida."))
        }

        if steps.isEmpty {
            issues.append(.init(severity: .error, message: "Aggiungi almeno un POI al percorso."))
        }

        if startPOI == nil {
            issues.append(.init(severity: .error, message: "Seleziona un punto di partenza."))
        } else if startPOI?.isActive != true {
            issues.append(.init(severity: .error, message: "Il punto di partenza deve essere attivo."))
        }

        var seenPOIs = Set<UUID>()
        for (index, step) in steps.enumerated() {
            guard let poi = step.poi else {
                issues.append(.init(severity: .error, message: "La tappa \(index + 1) non ha un POI associato."))
                continue
            }

            if !seenPOIs.insert(poi.id).inserted {
                issues.append(.init(severity: .error, message: "Il POI '\(poi.name)' è duplicato nel percorso."))
            }

            issues.append(contentsOf: poiIssues(poi, prefix: "POI '\(poi.name)'"))

            if step.distanceMeters != nil && (step.distanceMeters ?? 0) <= 0 {
                issues.append(.init(severity: .error, message: "La tappa \(index + 1) ha una distanza non valida."))
            }

            if step.estimatedMinutes != nil && (step.estimatedMinutes ?? 0) <= 0 {
                issues.append(.init(severity: .error, message: "La tappa \(index + 1) ha minuti stimati non validi."))
            }
        }

        let pathPOIIds = Set(steps.compactMap { $0.poi?.id })
        let scopedContents = contents.filter { pathPOIIds.contains($0.poiId) }
        for content in scopedContents {
            issues.append(contentsOf: contentIssues(content))
        }

        if isActive && issues.contains(where: { $0.severity == .error }) {
            issues.append(.init(severity: .warning, message: "Il percorso non verra pubblicato finche gli errori non sono risolti."))
        }

        return issues
    }

    static func bundleIssues(for readiness: [BundleReadiness], localUpdatedAt: Date) -> [AdminValidationIssue] {
        var issues: [AdminValidationIssue] = []
        let requiredTiers = Set(ContentTier.allCases)
        let byTier = Dictionary(uniqueKeysWithValues: readiness.map { ($0.tier, $0) })

        for tier in requiredTiers {
            guard let package = byTier[tier] else {
                issues.append(.init(severity: .error, message: "Bundle \(tier.displayName) mancante."))
                continue
            }

            if !package.isUsable {
                issues.append(.init(severity: .error, message: "Bundle \(tier.displayName) non pronto o manifest non valido."))
            }

            if let generatedAt = package.generatedAt, generatedAt < localUpdatedAt.addingTimeInterval(-1) {
                issues.append(.init(severity: .error, message: "Bundle \(tier.displayName) obsoleto rispetto alle ultime modifiche."))
            }
        }

        return issues
    }

    static func poiIssues(_ poi: POI, prefix: String? = nil) -> [AdminValidationIssue] {
        var issues: [AdminValidationIssue] = []
        let label = prefix ?? "POI"

        if poi.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, message: "\(label): nome mancante."))
        }
        if poi.qrPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, message: "\(label): QR payload mancante."))
        }
        if poi.numericCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, message: "\(label): codice numerico mancante."))
        }
        if poi.x < 0 || poi.y < 0 || !poi.x.isFinite || !poi.y.isFinite {
            issues.append(.init(severity: .error, message: "\(label): coordinate mappa non valide."))
        }
        return issues
    }

    static func contentIssues(_ content: Content) -> [AdminValidationIssue] {
        var issues: [AdminValidationIssue] = []
        let type = content.contentType

        if !ContentTier.allCases.contains(content.tier) {
            issues.append(.init(severity: .error, message: "Contenuto \(content.id): tier mancante o non valido."))
        }

        if type.requiresFileURL && content.fileURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append(.init(severity: .error, message: "Contenuto \(type.displayName): file_url mancante."))
        }

        if content.sortOrder < 0 {
            issues.append(.init(severity: .error, message: "Contenuto \(type.displayName): ordinamento non valido."))
        }

        return issues
    }

    static func eventIssues(_ event: Event) -> [AdminValidationIssue] {
        eventIssues(
            name: event.name,
            isActive: event.isActive,
            startTime: event.timeStart,
            endTime: event.timeEnd,
            maxParticipants: event.maxParticipants,
            price: event.price,
            trail: event.trail,
            eventPOI: event.eventPOI
        )
    }

    static func eventIssues(
        name: String,
        isActive: Bool,
        startTime: Date,
        endTime: Date,
        maxParticipants: Int?,
        price: Double,
        trail: Trail?,
        eventPOI: POI?
    ) -> [AdminValidationIssue] {
        var issues: [AdminValidationIssue] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, message: "Nome evento mancante."))
        }

        if endTime <= startTime {
            issues.append(.init(severity: .error, message: "L'ora di fine deve essere successiva all'inizio."))
        }

        if let maxParticipants, maxParticipants <= 0 {
            issues.append(.init(severity: .error, message: "Max partecipanti deve essere maggiore di zero."))
        }

        if price < 0 {
            issues.append(.init(severity: .error, message: "Il prezzo non puo essere negativo."))
        }

        if isActive {
            if let trail, !trail.isActive {
                issues.append(.init(severity: .error, message: "Un evento attivo puo usare solo percorsi pubblicati."))
            }

            if let eventPOI, !eventPOI.isActive {
                issues.append(.init(severity: .error, message: "Il luogo evento deve essere un POI attivo."))
            }
        }

        return issues
    }
}

extension ContentType {
    var requiresFileURL: Bool {
        switch self {
        case .text:
            return false
        case .image, .video, .model3d, .audio:
            return true
        }
    }

    var defaultMimeType: String {
        switch self {
        case .text:
            return "application/json"
        case .image:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        case .model3d:
            return "model/vnd.usdz+zip"
        case .audio:
            return "audio/mpeg"
        }
    }

    var defaultFileExtension: String {
        switch self {
        case .text:
            return "json"
        case .image:
            return "jpg"
        case .video:
            return "mp4"
        case .model3d:
            return "usdz"
        case .audio:
            return "mp3"
        }
    }
}
