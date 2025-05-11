import Foundation
import SwiftUI

public enum IncidentType: String, CaseIterable, Codable {
    case verbal = "Verbal"
    case physical = "Physical"
    case emergency = "Emergency"
    
    public var emoji: String {
        switch self {
        case .verbal: return "🗣️"
        case .physical: return "👊"
        case .emergency: return "🚨"
        }
    }
    
    public var title: String {
        switch self {
        case .verbal: return "Verbal Incident"
        case .physical: return "Physical Incident"
        case .emergency: return "Emergency"
        }
    }
    
    public var firestoreType: String {
        switch self {
        case .verbal: return "Verbal"
        case .physical: return "Physical"
        case .emergency: return "911"
        }
    }
    
    public var description: String {
        switch self {
        case .verbal: return "Report verbal harassment or threats"
        case .physical: return "Report physical altercations"
        case .emergency: return "Report life-threatening situations"
        }
    }
    
    public var color: Color {
        switch self {
        case .verbal: return .yellow
        case .physical: return .orange
        case .emergency: return .red
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "Verbal", "verbal": self = .verbal
        case "Physical", "physical": self = .physical
        case "911", "emergency": self = .emergency
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid incident type: \(rawValue)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(firestoreType)
    }
    
    public static func fromFirestoreType(_ type: String) -> IncidentType {
        switch type {
        case "Verbal": return .verbal
        case "Physical": return .physical
        case "911": return .emergency
        default: return .verbal
        }
    }
} 
