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
    var programDayID: UUID?
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout) 
    var exercises: [WorkoutExercise] = []
    
    init(startTime: Date = Date(), status: WorkoutStatus = .inProgress, notes: String? = nil, programDayID: UUID? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.statusRaw = status.rawValue
        self.notes = notes
        self.programDayID = programDayID
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
    var weight: Double?
    var reps: Int?
    var timeSeconds: Double?
    var distanceMeters: Double?
    var rpe: Double?
    
    var workoutExercise: WorkoutExercise?
    
    init(orderIndex: Int, isWarmup: Bool = false, isCompleted: Bool = false, weight: Double? = nil, reps: Int? = nil, timeSeconds: Double? = nil, distanceMeters: Double? = nil, rpe: Double? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.isWarmup = isWarmup
        self.isCompleted = isCompleted
        self.weight = weight
        self.reps = reps
        self.timeSeconds = timeSeconds
        self.distanceMeters = distanceMeters
        self.rpe = rpe
    }
}
