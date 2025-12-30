import Foundation

enum CoachAction: Codable {
    case updateProfile(UpdateProfilePayload)
    case proposeProgramChange(ProposeProgramChangePayload)
    
    struct UpdateProfilePayload: Codable {
        let goals: String?
        let injuries: String?
        let preferences: String?
    }
    
    struct ProposeProgramChangePayload: Codable {
        let message: String
        let suggestedChanges: String
    }
    
    enum CodingKeys: String, CodingKey {
        case updateProfile
        case proposeProgramChange
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let payload = try? container.decode(UpdateProfilePayload.self, forKey: .updateProfile) {
            self = .updateProfile(payload)
            return
        }
        
        if let payload = try? container.decode(ProposeProgramChangePayload.self, forKey: .proposeProgramChange) {
            self = .proposeProgramChange(payload)
            return
        }
        
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown action type"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .updateProfile(let payload):
            try container.encode(payload, forKey: .updateProfile)
        case .proposeProgramChange(let payload):
            try container.encode(payload, forKey: .proposeProgramChange)
        }
    }
}

struct LLMResponse: Codable {
    let message: String
    let actions: [CoachAction]?
}
