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
    var goals: String
    var injuries: String
    var preferences: String
    var coachNotes: String
    
    init(name: String = "Athlete", onboardingCompleted: Bool = false) {
        self.id = UUID()
        self.name = name
        self.onboardingCompleted = onboardingCompleted
        self.goals = ""
        self.injuries = ""
        self.preferences = ""
        self.coachNotes = ""
    }
}
