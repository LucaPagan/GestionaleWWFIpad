//
//  DataService.swift
//  GestionaleWWFIpad
//
//  Seeds sample data on first launch for development/demo.
//  In production, this is replaced by SyncManager pulling from Supabase.
//

import Foundation
import SwiftData

// MARK: - DataService

/// Provides seed data for offline development and first-launch demo.
/// Production flow: SyncManager.pullLatestData() replaces this entirely.
@MainActor
class DataService {
    static func seedIfNeeded(context: ModelContext) {
        // Check if data already exists
        let descriptor = FetchDescriptor<Trail>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        // --- POI samples with deterministic UUIDs ---
        // ⚠️ Fixed UUIDs ensure QR payloads remain valid across store resets
        let fixedID1 = UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!
        let fixedID2 = UUID(uuidString: "A1000001-0000-0000-0000-000000000002")!
        let fixedID3 = UUID(uuidString: "A1000001-0000-0000-0000-000000000003")!
        let fixedID4 = UUID(uuidString: "A1000001-0000-0000-0000-000000000004")!
        let fixedID5 = UUID(uuidString: "A1000001-0000-0000-0000-000000000005")!

        let poi1 = POI(
            name: "Ingresso Principale",
            description: "Punto di partenza ufficiale. Qui inizia la tua avventura nell'Oasi degli Astroni.",
            x: 0.15, y: 0.85,
            type: .startPoint,
            isStartPoint: true,
            fixedID: fixedID1
        )
        let poi2 = POI(
            name: "Cratere Centrale",
            description: "Il cuore vulcanico degli Astroni. Osserva la vegetazione rigogliosa che colonizza l'antico cratere.",
            x: 0.50, y: 0.50,
            type: .landmark,
            fixedID: fixedID2
        )
        let poi3 = POI(
            name: "Belvedere Nord",
            description: "Da qui puoi ammirare l'intera oasi e, nelle giornate limpide, il Golfo di Pozzuoli.",
            x: 0.55, y: 0.20,
            type: .landmark,
            fixedID: fixedID3
        )
        let poi4 = POI(
            name: "Laghetto degli Astroni",
            description: "Piccolo specchio d'acqua naturale, habitat fondamentale per anfibi e uccelli acquatici.",
            x: 0.35, y: 0.60,
            type: .landmark,
            fixedID: fixedID4
        )
        let poi5 = POI(
            name: "Area Picnic",
            description: "Zona attrezzata per una pausa. Rispetta l'ambiente: non lasciare rifiuti.",
            x: 0.75, y: 0.75,
            type: .info,
            fixedID: fixedID5
        )

        // Mark seed POIs as needing sync so they are pushed to the backend
        [poi1, poi2, poi3, poi4, poi5].forEach {
            $0.needsSync = true
            context.insert($0)
        }

        // --- Trail 1: Anello Base ---
        let trail1 = Trail(
            name: "Anello Base",
            description: "Il percorso ideale per la prima visita. Attraversa i punti principali dell'oasi in circa un'ora.",
            isActive: true,
            difficulty: .easy,
            estimatedMinutes: 60,
            startPOIId: fixedID1
        )

        let step1 = TrailStep(stepOrder: 0, directionHint: "Parti dall'ingresso e segui il sentiero principale verso sinistra. Dopo circa 200m troverai il primo cartello.", distanceMeters: 200, estimatedMinutes: 5, poi: poi1)
        let step2 = TrailStep(stepOrder: 1, directionHint: "Continua dritto per 300m costeggiando il laghetto sulla tua destra.", distanceMeters: 300, estimatedMinutes: 8, poi: poi4)
        let step3 = TrailStep(stepOrder: 2, directionHint: "Sali il sentiero in pendenza per 150m fino al centro del cratere.", distanceMeters: 150, estimatedMinutes: 5, poi: poi2)
        let step4 = TrailStep(stepOrder: 3, directionHint: "Segui le frecce verso nord per raggiungere il punto panoramico. Circa 400m in salita.", distanceMeters: 400, estimatedMinutes: 12, poi: poi3)
        let step5 = TrailStep(stepOrder: 4, directionHint: "Scendi seguendo il sentiero est per 500m fino all'area picnic.", distanceMeters: 500, estimatedMinutes: 10, poi: poi5)

        trail1.steps = [step1, step2, step3, step4, step5]
        trail1.needsSync = true
        context.insert(trail1)

        // --- Trail 2: Sentiero Naturalistico ---
        let trail2 = Trail(
            name: "Sentiero Naturalistico",
            description: "Percorso approfondito per gli appassionati di natura. Guide audio disponibili offline.",
            isActive: true,
            difficulty: .medium,
            estimatedMinutes: 90,
            startPOIId: fixedID4
        )

        let step2a = TrailStep(stepOrder: 0, directionHint: "Dalla partenza, imbocca il sentiero di destra verso il laghetto.", distanceMeters: 250, estimatedMinutes: 7, poi: poi4)
        let step2b = TrailStep(stepOrder: 1, directionHint: "Costeggia il laghetto completamente (circa 600m) poi sali verso il cratere.", distanceMeters: 600, estimatedMinutes: 15, poi: poi2)
        let step2c = TrailStep(stepOrder: 2, directionHint: "Dal cratere prosegui verso nord fino al belvedere.", distanceMeters: 350, estimatedMinutes: 10, poi: poi3)

        trail2.steps = [step2a, step2b, step2c]
        trail2.needsSync = true
        context.insert(trail2)

        // --- Sample Events ---
        let eventDescriptor = FetchDescriptor<Event>()
        let existingEvents = (try? context.fetch(eventDescriptor)) ?? []
        if existingEvents.isEmpty {
            let cal = Calendar.current

            let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let event1 = Event(
                name: "Birdwatching all'Alba",
                description: "Esplora l'avifauna dell'Oasi accompagnato da un ornitologo esperto. Binocoli forniti dall'organizzazione.",
                category: .educational,
                date: tomorrow,
                startTime: cal.date(bySettingHour: 6, minute: 30, second: 0, of: tomorrow) ?? tomorrow,
                endTime: cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow,
                maxParticipants: 20,
                organizerName: "WWF Campania",
                contactInfo: "eventi@wwfcampania.it",
                requirements: "Scarpe comode, abbigliamento mimetico, crema solare. Binocoli disponibili.",
                targetAudience: .all,
                price: 0
            )
            event1.isActive = true
            event1.trail = trail1
            event1.eventPOI = poi3
            event1.needsSync = true
            context.insert(event1)

            let inThreeDays = cal.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            let event2 = Event(
                name: "Piccoli Naturalisti",
                description: "Laboratorio interattivo per bambini: scopriamo le piante, gli insetti e gli animali dell'Oasi con giochi e attività pratiche.",
                category: .family,
                date: inThreeDays,
                startTime: cal.date(bySettingHour: 10, minute: 0, second: 0, of: inThreeDays) ?? inThreeDays,
                endTime: cal.date(bySettingHour: 12, minute: 30, second: 0, of: inThreeDays) ?? inThreeDays,
                maxParticipants: 15,
                organizerName: "WWF Campania – Settore Educazione",
                contactInfo: "edu@wwfcampania.it",
                requirements: "Abbigliamento comodo, cappellino, merenda.",
                targetAudience: .children,
                price: 5.00
            )
            event2.isActive = true
            event2.trail = trail2
            event2.eventPOI = poi4
            event2.needsSync = true
            context.insert(event2)
        }

        try? context.save()
    }
}