//
//  POIRepository.swift
//  GestionaleWWFIpad
//

import Foundation

protocol POIRepository: Sendable {
    func fetchAll() async throws -> [POI]
    func save(_ poi: POI) async throws
    func delete(_ poi: POI) async throws
}
