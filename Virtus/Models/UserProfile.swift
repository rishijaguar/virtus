//
//  UserProfile.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

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
    
    // JSON String storing [UUID: Double] mapping Exercise ID to 1RM weight
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
    func oneRepMax(for exerciseID: UUID) -> Double? {
        guard let data = oneRepMaxHistoryJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([UUID: Double].self, from: data) else {
            return nil
        }
        return dict[exerciseID]
    }
    
    func setOneRepMax(_ weight: Double, for exerciseID: UUID) {
        var dict: [UUID: Double] = [:]
        if let data = oneRepMaxHistoryJSON.data(using: .utf8),
           let existing = try? JSONDecoder().decode([UUID: Double].self, from: data) {
            dict = existing
        }
        dict[exerciseID] = weight
        if let newData = try? JSONEncoder().encode(dict),
           let jsonString = String(data: newData, encoding: .utf8) {
            oneRepMaxHistoryJSON = jsonString
        }
    }
}