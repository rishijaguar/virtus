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
    
    @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program) 
    var days: [ProgramDay] = []
    
    init(name: String, programDescription: String, durationWeeks: Int, isActive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.programDescription = programDescription
        self.createdDate = Date()
        self.durationWeeks = durationWeeks
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
    
    var targetSets: Int
    var targetReps: String? // "8-12", "AMRAP"
    var targetRPE: Double?
    var restSeconds: Int?
    var notes: String?
    
    var programDay: ProgramDay?
    
    init(orderIndex: Int, targetSets: Int, targetReps: String? = nil, targetRPE: Double? = nil, restSeconds: Int? = nil, notes: String? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.notes = notes
    }
}
