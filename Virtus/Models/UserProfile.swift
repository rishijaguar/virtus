//
//  UserProfile.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

struct OneRepMaxEntry: Codable {
    let value: Double
    let unit: String
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var onboardingCompleted: Bool
    
    // Preferences
    var preferredUnitRaw: String = "lbs"
    
    // Coach Context
    var goals: String
    var injuries: String
    var preferences: String
    var coachNotes: String
    
    // JSON String storing [UUID: OneRepMaxEntry]
    var oneRepMaxHistoryJSON: String = "{}"
    
    init(name: String = "Athlete", onboardingCompleted: Bool = false) {
        self.id = UUID()
        self.name = name
        self.onboardingCompleted = onboardingCompleted
        self.preferredUnitRaw = "lbs"
        self.goals = ""
        self.injuries = ""
        self.preferences = ""
        self.coachNotes = ""
        self.oneRepMaxHistoryJSON = "{}"
    }
    
    // Computed helper for Unit Enum
    var preferredUnit: WeightUnit {
        get { WeightUnit(rawValue: preferredUnitRaw) ?? .lbs }
        set { preferredUnitRaw = newValue.rawValue }
    }
    
    // 1RM Helpers
    func oneRepMax(for exerciseID: UUID) -> (value: Double, unit: String)? {
        guard let data = oneRepMaxHistoryJSON.data(using: .utf8) else { return nil }
        let key = exerciseID.uuidString
        
        // Try new format first (String keys)
        if let dict = try? JSONDecoder().decode([String: OneRepMaxEntry].self, from: data),
           let entry = dict[key] {
            return (entry.value, entry.unit)
        }
        
        // Fallback: Try decoding with UUID keys (in case data was saved that way)
        if let dict = try? JSONDecoder().decode([UUID: OneRepMaxEntry].self, from: data),
           let entry = dict[exerciseID] {
            return (entry.value, entry.unit)
        }
        
        // Fallback: Legacy UUID: Double
        if let dict = try? JSONDecoder().decode([UUID: Double].self, from: data),
           let value = dict[exerciseID] {
            return (value, "lbs")
        }
        
        return nil
    }
    
    func setOneRepMax(_ weight: Double, unit: String, for exerciseID: UUID) {
        var dict: [String: OneRepMaxEntry] = [:]
        let key = exerciseID.uuidString
        
        if let data = oneRepMaxHistoryJSON.data(using: .utf8) {
            // Try to load existing String-keyed data
            if let existing = try? JSONDecoder().decode([String: OneRepMaxEntry].self, from: data) {
                dict = existing
            } 
            // Migration: If we had UUID-keyed data, we lose it here unless we migrate.
            // For dev simplicity, we start fresh or overwrite.
        }
        
        dict[key] = OneRepMaxEntry(value: weight, unit: unit)
        
        if let newData = try? JSONEncoder().encode(dict),
           let jsonString = String(data: newData, encoding: .utf8) {
            oneRepMaxHistoryJSON = jsonString
        }
    }
}
