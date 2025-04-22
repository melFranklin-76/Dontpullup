import Foundation

enum IncidentType: String, CaseIterable, Codable {
    case verbal
    case physical
    case emergency
    
    var emoji: String {
        switch self {
        case .verbal: return "📢"
        case .physical: return "👊"
        case .emergency: return "☎️"
        }
    }
    
    var title: String {
        switch self {
        case .verbal: return "Verbal Incident"
        case .physical: return "Physical Incident"
        case .emergency: return "Emergency"
        }
    }
    
    var firestoreType: String {
        switch self {
        case .verbal: return "Verbal"
        case .physical: return "Physical"
        case .emergency: return "911"
        }
    }
    
    var description: String {
        switch self {
        case .verbal: return "Report verbal harassment or threats"
        case .physical: return "Report physical altercations"
        case .emergency: return "Report life-threatening situations"
        }
    }
    
    init(from decoder: Decoder) throws {
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(firestoreType)
    }
}
