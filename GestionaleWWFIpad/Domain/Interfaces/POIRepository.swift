//
//  POIRepository.swift
//  GestionaleWWFIpad
//

import Foundation

@MainActor
protocol POIRepository {
    func fetchAll() throws -> [POI]
    func save(_ poi: POI) throws
    func delete(_ poi: POI) throws
}
