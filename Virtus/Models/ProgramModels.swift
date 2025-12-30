//
//  ProgramModels.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

@Model
final class Program {
    @Attribute(.unique) var id: UUID
    var name: String
    var programDescription: String
    var createdDate: Date
    var isActive: Bool
    var durationWeeks: Int
    var sessionsPerWeek: Int
    
    @Relationship(deleteRule: .cascade, inverse: \SessionTemplate.program) 
    var sessions: [SessionTemplate] = []
    
    init(name: String, programDescription: String, durationWeeks: Int, sessionsPerWeek: Int, isActive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.programDescription = programDescription
        self.createdDate = Date()
        self.durationWeeks = durationWeeks
        self.sessionsPerWeek = sessionsPerWeek
        self.isActive = isActive
    }
}

@Model
final class SessionTemplate {
    @Attribute(.unique) var id: UUID
    var weekNumber: Int
    var dayNumber: Int // 1-7 (or sequential)
    var title: String // e.g., "Leg Hypertrophy"
    var instructions: String?
    
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.sessionTemplate) 
    var exercises: [TemplateExercise] = []
    
    var program: Program?
    
    init(weekNumber: Int, dayNumber: Int, title: String, instructions: String? = nil) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.dayNumber = dayNumber
        self.title = title
        self.instructions = instructions
    }
}

@Model
final class TemplateExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    
    var exercise: Exercise?
    
    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.templateExercise)
    var sets: [TemplateSet] = []
    
    var restSeconds: Int?
    var notes: String?
    
    var sessionTemplate: SessionTemplate?
    
    init(orderIndex: Int, restSeconds: Int? = nil, notes: String? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.restSeconds = restSeconds
        self.notes = notes
    }
}

@Model
final class TemplateSet {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    
    // --- Target Definition (Reps) ---
    var targetTypeRaw: String
    // Stores the target value string:
    // - Reps: "5"
    // - Range: "8-12"
    // - Time: "30" (interpreted as seconds or minutes based on context, we'll assume seconds for DB)
    // - AMRAP: "AMRAP"
    var targetValue: String 
    
    // --- Intensity Definition (Load) ---
    var intensityTypeRaw: String
    // Stores the intensity value:
    // - RPE: "8.0"
    // - %1RM: "0.85" (85%)
    // - LW+: "5.0" (Last Week + 5)
    // - LS+: "2.5" (Last Session + 2.5)
    // - None: ""
    var intensityValue: Double? 
    
    var templateExercise: TemplateExercise?
    
    init(orderIndex: Int, targetType: TargetType = .reps, targetValue: String = "10", intensityType: IntensityType = .rpe, intensityValue: Double? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.targetTypeRaw = targetType.rawValue
        self.targetValue = targetValue
        self.intensityTypeRaw = intensityType.rawValue
        self.intensityValue = intensityValue
    }
    
    var targetType: TargetType {
        get { TargetType(rawValue: targetTypeRaw) ?? .reps }
        set { targetTypeRaw = newValue.rawValue }
    }
    
    var intensityType: IntensityType {
        get { IntensityType(rawValue: intensityTypeRaw) ?? .rpe }
        set { intensityTypeRaw = newValue.rawValue }
    }
}

// Enums for the Data Model Specification
enum TargetType: String, Codable, CaseIterable {
    case reps   // Fixed number
    case range  // "8-12"
    case amrap  // "AMRAP"
    case time   // Time in seconds
}

enum IntensityType: String, Codable, CaseIterable {
    case rpe              // RPE 1-10
    case percent1RM       // % of 1RM
    case lastWeekPlus     // LW + X
    case lastSessionPlus  // LS + X
    case none             // No intensity specified
}
