//
//  DataService.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import Foundation
import SwiftData

// Seed dati di esempio al primo avvio
@MainActor
class DataService {
    static func seedIfNeeded(context: ModelContext) {
        // Controlla se esistono già percorsi
        let descriptor = FetchDescriptor<Trail>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        // --- POI di esempio ---
        // ⚠️ Gli UUID sono FISSI e deterministici: così il qrPayload rimane sempre
        // identico tra un reset dello store e l'altro, mantenendo validi i QR stampati.
        let fixedID1 = UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!
        let fixedID2 = UUID(uuidString: "A1000001-0000-0000-0000-000000000002")!
        let fixedID3 = UUID(uuidString: "A1000001-0000-0000-0000-000000000003")!
        let fixedID4 = UUID(uuidString: "A1000001-0000-0000-0000-000000000004")!
        let fixedID5 = UUID(uuidString: "A1000001-0000-0000-0000-000000000005")!

        let poi1 = POI(
            name: "Ingresso Principale",
            description: "Punto di partenza ufficiale. Qui inizia la tua avventura nell'Oasi degli Astroni.",
            x: 0.15, y: 0.85,
            type: .service,
            fixedID: fixedID1
        )
        let poi2 = POI(
            name: "Cratere Centrale",
            description: "Il cuore vulcanico degli Astroni. Osserva la vegetazione rigogliosa che colonizza l'antico cratere.",
            x: 0.50, y: 0.50,
            type: .nature,
            fixedID: fixedID2
        )
        let poi3 = POI(
            name: "Belvedere Nord",
            description: "Da qui puoi ammirare l'intera oasi e, nelle giornate limpide, il Golfo di Pozzuoli.",
            x: 0.55, y: 0.20,
            type: .viewpoint,
            fixedID: fixedID3
        )
        let poi4 = POI(
            name: "Laghetto degli Astroni",
            description: "Piccolo specchio d'acqua naturale, habitat fondamentale per anfibi e uccelli acquatici.",
            x: 0.35, y: 0.60,
            type: .nature,
            fixedID: fixedID4
        )
        let poi5 = POI(
            name: "Area Picnic",
            description: "Zona attrezzata per una pausa. Rispetta l'ambiente: non lasciare rifiuti.",
            x: 0.75, y: 0.75,
            type: .service,
            fixedID: fixedID5
        )

        context.insert(poi1)
        context.insert(poi2)
        context.insert(poi3)
        context.insert(poi4)
        context.insert(poi5)

        // --- Percorso 1: Anello Base ---
        let trail1 = Trail(
            name: "Anello Base",
            description: "Il percorso ideale per la prima visita. Attraversa i punti principali dell'oasi in circa un'ora.",
            difficulty: .easy,
            estimatedMinutes: 60
        )

        let step1 = TrailStep(orderIndex: 0, instructions: "Parti dall'ingresso e segui il sentiero principale verso sinistra. Dopo circa 200m troverai il primo cartello.", poi: poi1)
        let step2 = TrailStep(orderIndex: 1, instructions: "Continua dritto per 300m costeggiando il laghetto sulla tua destra.", poi: poi4)
        let step3 = TrailStep(orderIndex: 2, instructions: "Sali il sentiero in pendenza per 150m fino al centro del cratere.", poi: poi2)
        let step4 = TrailStep(orderIndex: 3, instructions: "Segui le frecce verso nord per raggiungere il punto panoramico. Circa 400m in salita.", poi: poi3)
        let step5 = TrailStep(orderIndex: 4, instructions: "Scendi seguendo il sentiero est per 500m fino all'area picnic.", poi: poi5)

        trail1.steps = [step1, step2, step3, step4, step5]
        trail1.isActive = true
        context.insert(trail1)

        // --- Percorso 2: Sentiero Naturalistico ---
        let trail2 = Trail(
            name: "Sentiero Naturalistico",
            description: "Percorso approfondito per gli appassionati di natura. Guide audio disponibili offline.",
            difficulty: .medium,
            estimatedMinutes: 90
        )
        let step2a = TrailStep(orderIndex: 0, instructions: "Dalla partenza, imbocca il sentiero di destra verso il laghetto.", poi: poi4)
        let step2b = TrailStep(orderIndex: 1, instructions: "Costeggia il laghetto completamente (circa 600m) poi sali verso il cratere.", poi: poi2)
        let step2c = TrailStep(orderIndex: 2, instructions: "Dal cratere prosegui verso nord fino al belvedere.", poi: poi3)

        trail2.steps = [step2a, step2b, step2c]
        trail2.isActive = true
        context.insert(trail2)

        // --- Eventi di esempio ---
        let eventDescriptor = FetchDescriptor<Event>()
        let existingEvents = (try? context.fetch(eventDescriptor)) ?? []
        if existingEvents.isEmpty {
            let cal = Calendar.current

            // Evento 1: Birdwatching all'alba — domani
            let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let event1 = Event(
                name: "Birdwatching all'Alba",
                description: "Esplora l'avifauna dell'Oasi accompagnato da un ornitologo esperto. Binocoli forniti dall'organizzazione.",
                category: .birdwatching,
                date: tomorrow,
                startTime: cal.date(bySettingHour: 6, minute: 30, second: 0, of: tomorrow) ?? tomorrow,
                endTime: cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow,
                maxParticipants: 20,
                organizerName: "WWF Campania",
                contactInfo: "eventi@wwfcampania.it",
                requirements: "Scarpe comode, abbigliamento mimetico, crema solare. Binocoli disponibili.",
                targetAudience: "Tutti",
                price: "Gratuito"
            )
            event1.isActive = true
            event1.trail = trail1
            event1.eventPOI = poi3
            context.insert(event1)

            // Evento 2: Laboratorio natura per bambini — fra 3 giorni
            let inThreeDays = cal.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            let event2 = Event(
                name: "Piccoli Naturalisti",
                description: "Laboratorio interattivo per bambini: scopriamo le piante, gli insetti e gli animali dell'Oasi con giochi e attività pratiche.",
                category: .kids,
                date: inThreeDays,
                startTime: cal.date(bySettingHour: 10, minute: 0, second: 0, of: inThreeDays) ?? inThreeDays,
                endTime: cal.date(bySettingHour: 12, minute: 30, second: 0, of: inThreeDays) ?? inThreeDays,
                maxParticipants: 15,
                organizerName: "WWF Campania – Settore Educazione",
                contactInfo: "edu@wwfcampania.it",
                requirements: "Abbigliamento comodo, cappellino, merenda.",
                targetAudience: "Bambini 6-12",
                price: "€5.00"
            )
            event2.isActive = true
            event2.trail = trail2
            event2.eventPOI = poi4
            context.insert(event2)
        }

        try? context.save()
    }
}