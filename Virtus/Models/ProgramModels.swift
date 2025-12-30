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
    
    @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program) 
    var days: [ProgramDay] = []
    
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
final class ProgramDay {
    @Attribute(.unique) var id: UUID
    var weekNumber: Int
    var dayNumber: Int // 1-7 (or sequential)
    var title: String // e.g., "Leg Hypertrophy"
    var instructions: String?
    
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.programDay) 
    var plannedExercises: [PlannedExercise] = []
    
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
final class PlannedExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    
    var exercise: Exercise?
    
    // Relationship to detailed sets
    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.plannedExercise)
    var sets: [PlannedSet] = []
    
    var restSeconds: Int?
    var notes: String?
    
    var programDay: ProgramDay?
    
    init(orderIndex: Int, restSeconds: Int? = nil, notes: String? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.restSeconds = restSeconds
        self.notes = notes
    }
}

@Model
final class PlannedSet {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    
    // Target Data
    var targetTypeRaw: String
    var reps: String // Holds "10", "8-12", "AMRAP", "30s" depending on type
    
    // Intensity Data
    var intensityTypeRaw: String
    var rpe: Double?
    var weightPercent: Double? // e.g., 75.0 for 75%
    
    var plannedExercise: PlannedExercise?
    
    init(orderIndex: Int, reps: String = "10", rpe: Double? = nil, weightPercent: Double? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.reps = reps
        self.rpe = rpe
        self.weightPercent = weightPercent
        self.targetTypeRaw = PlannedSetTargetType.reps.rawValue
        self.intensityTypeRaw = PlannedSetIntensityType.rpe.rawValue
    }
    
    var targetType: PlannedSetTargetType {
        get { PlannedSetTargetType(rawValue: targetTypeRaw) ?? .reps }
        set { targetTypeRaw = newValue.rawValue }
    }
    
    var intensityType: PlannedSetIntensityType {
        get { PlannedSetIntensityType(rawValue: intensityTypeRaw) ?? .rpe }
        set { intensityTypeRaw = newValue.rawValue }
    }
}

enum PlannedSetTargetType: String, Codable, CaseIterable {
    case reps   // "5"
    case range  // "8-12"
    case amrap  // "AMRAP"
    case time   // "30s"
}

enum PlannedSetIntensityType: String, Codable, CaseIterable {
    case rpe        // "RPE 8"
    case percent1RM // "75%"
    case none       // "-"
}