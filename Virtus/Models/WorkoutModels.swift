//
//  WorkoutModels.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var statusRaw: String
    var notes: String?
    
    // Link back to the template if instantiated from one
    var sessionTemplateID: UUID?
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout) 
    var exercises: [WorkoutExercise] = []
    
    init(startTime: Date = Date(), status: WorkoutStatus = .inProgress, notes: String? = nil, sessionTemplateID: UUID? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.statusRaw = status.rawValue
        self.notes = notes
        self.sessionTemplateID = sessionTemplateID
    }
    
    var status: WorkoutStatus {
        get { WorkoutStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }
}

enum WorkoutStatus: String, Codable {
    case inProgress
    case completed
    case discarded
}

@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var exercise: Exercise?
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise) 
    var sets: [WorkoutSet] = []
    
    var workout: Workout?
    
    init(orderIndex: Int) {
        self.id = UUID()
        self.orderIndex = orderIndex
    }
}

@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var isWarmup: Bool
    var isCompleted: Bool
    
    // --- Instantiated Targets (The "Brain's" Output) ---
    var displayIntensity: String? // e.g., "85%", "LW +5", "RPE 8"
    var computedTarget: String?   // e.g., "225 x 5", "185 x 8-12"
    
    // --- Actual User Input (The Log) ---
    var weight: Double?
    var unitRaw: String // "lbs" or "kg"
    var reps: Int?
    var rpe: Double?
    var timeSeconds: Double?
    var distanceMeters: Double?
    
    var workoutExercise: WorkoutExercise?
    
    init(orderIndex: Int, isWarmup: Bool = false, isCompleted: Bool = false, 
         displayIntensity: String? = nil, computedTarget: String? = nil,
         weight: Double? = nil, unit: WeightUnit = .lbs, reps: Int? = nil, rpe: Double? = nil, timeSeconds: Double? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.isWarmup = isWarmup
        self.isCompleted = isCompleted
        self.displayIntensity = displayIntensity
        self.computedTarget = computedTarget
        self.weight = weight
        self.unitRaw = unit.rawValue
        self.reps = reps
        self.rpe = rpe
        self.timeSeconds = timeSeconds
    }
    
    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .lbs }
        set { unitRaw = newValue.rawValue }
    }
}

enum WeightUnit: String, Codable, CaseIterable {
    case lbs
    case kg
}
