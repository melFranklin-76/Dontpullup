import Foundation

/// Enum representing different types of incidents.
enum IncidentType: String, CaseIterable, Codable {
    /// Verbal incident type.
    case verbal
    /// Physical incident type.
    case physical
    /// Emergency incident type.
    case emergency
    
    /// Emoji representation of the incident type.
    var emoji: String {
        switch self {
        case .verbal: return "📢"
        case .physical: return "👊"
        case .emergency: return "☎️"
        }
    }
    
    /// Title of the incident type.
    var title: String {
        switch self {
        case .verbal: return "Verbal Incident"
        case .physical: return "Physical Incident"
        case .emergency: return "Emergency"
        }
    }
    
    /// Firestore representation of the incident type.
    var firestoreType: String {
        switch self {
        case .verbal: return "Verbal"
        case .physical: return "Physical"
        case .emergency: return "911"
        }
    }
    
    /// Description of the incident type.
    var description: String {
        switch self {
        case .verbal: return "Report verbal harassment or threats"
        case .physical: return "Report physical altercations"
        case .emergency: return "Report life-threatening situations"
        }
    }
    
    /// Initializes an `IncidentType` from a decoder.
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: An error if decoding fails.
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
    
    /// Encodes the `IncidentType` to an encoder.
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(firestoreType)
    }
}
