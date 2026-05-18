//
//  MediaClassificationService.swift
//  GestionaleWWFIpad
//
//  Automatically classifies media content into tiers based on type and size.
//

import Foundation

final class MediaClassificationService {
    static let shared = MediaClassificationService()
    
    private init() {}
    
    /// Classifies content based on its type and file size.
    func classify(type: ContentType, sizeInBytes: Int) -> ContentTier {
        switch type {
        case .text:
            return .light
        case .image:
            // Threshold for Light images: < 1MB
            if sizeInBytes < 1_000_000 {
                return .light
            } else {
                return .standard
            }
        case .video:
            // All videos are at least standard
            return .standard
        case .model3d, .audio:
            // 3D models and high-fidelity audio are always Full
            return .full
        }
    }
}
