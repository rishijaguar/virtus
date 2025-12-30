//
//  WorkoutBuilder.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import Foundation
import SwiftData

struct WorkoutBuilder {
    
    /// Brzycki Formula for 1RM estimation: weight * (36 / (37 - reps))
    static func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }
    
    /// Reverse Brzycki to find weight for a target rep count at 10 RPE: 1RM / (36 / (37 - reps))
    static func weightForReps(oneRepMax: Double, reps: Int) -> Double {
        guard reps > 0 else { return oneRepMax }
        return oneRepMax / (36.0 / (37.0 - Double(reps)))
    }
    
    /// Instantiate a Workout from a Template, resolving all targets
    @MainActor
    static func instantiate(session: SessionTemplate, profile: UserProfile, context: ModelContext) -> Workout {
        let workout = Workout(startTime: Date(), status: .inProgress, sessionTemplateID: session.id)
        workout.notes = session.title
        context.insert(workout)
        
        let templatesSorted = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
        
        for (idx, templateEx) in templatesSorted.enumerated() {
            let workoutEx = WorkoutExercise(orderIndex: idx)
            workoutEx.exercise = templateEx.exercise
            workoutEx.workout = workout
            context.insert(workoutEx)
            
            let setsSorted = templateEx.sets.sorted { $0.orderIndex < $1.orderIndex }
            for (setIdx, tSet) in setsSorted.enumerated() {
                // Use profile's preferred unit for the new set
                let wSet = WorkoutSet(orderIndex: setIdx, unit: profile.preferredUnit)
                wSet.workoutExercise = workoutEx
                
                // 1. Resolve Display Intensity
                wSet.displayIntensity = resolveIntensityLabel(tSet)
                
                // 2. Resolve Computed Target
                wSet.computedTarget = resolveTarget(tSet, exercise: templateEx.exercise, profile: profile, context: context)
                
                context.insert(wSet)
            }
        }
        
        return workout
    }
    
    private static func resolveIntensityLabel(_ tSet: TemplateSet) -> String {
        switch tSet.intensityType {
        case .rpe:
            return "RPE \(tSet.intensityValue?.formatted() ?? "-")"
        case .percent1RM:
            let val = Int((tSet.intensityValue ?? 0) * 100)
            return "\(val)%"
        case .lastWeekPlus:
            return "LW +\(tSet.intensityValue?.formatted() ?? "0")"
        case .lastSessionPlus:
            return "LS +\(tSet.intensityValue?.formatted() ?? "0")"
        case .none:
            return "-"
        }
    }
    
    @MainActor
    private static func resolveTarget(_ tSet: TemplateSet, exercise: Exercise?, profile: UserProfile, context: ModelContext) -> String {
        guard let exercise = exercise else { return tSet.targetValue }
        
        // 1. Determine 1RM
        let oneRepMax = profile.oneRepMax(for: exercise.id) ?? 100.0 // Fallback to 100 as per spec
        
        let targetValue = tSet.targetValue
        let unit = profile.preferredUnitRaw
        
        switch tSet.intensityType {
        case .percent1RM:
            if let pct = tSet.intensityValue {
                let weight = oneRepMax * (pct / 100.0)
                return "\(Int(weight))\(unit) x \(targetValue)"
            }
        case .rpe:
            // Simplified Brzycki RPE math:
            // RPE 10 = nRM. 
            // RPE 9 = roughly (n+1)RM or a certain % offset.
            // For now, let's treat targetValue as 'n' and calculate weight for nRM at RPE 10.
            if let reps = Int(targetValue) {
                let weightAtRPE10 = weightForReps(oneRepMax: oneRepMax, reps: reps)
                // If RPE is lower than 10, we'd ideally reduce weight. 
                // A common RPE table approximation: each RPE point is ~2-3% of weight.
                let rpeOffset = (10.0 - (tSet.intensityValue ?? 10.0)) * 0.02
                let finalWeight = weightAtRPE10 * (1.0 - rpeOffset)
                return "\(Int(finalWeight))\(unit) @ \(tSet.intensityValue?.formatted() ?? "10")"
            }
            return "Est: \(targetValue) @ \(tSet.intensityValue?.formatted() ?? "-")"
            
        case .lastWeekPlus:
            if let historicalWeight = findHistoricalWeight(exerciseID: exercise.id, type: .lastWeek, context: context) {
                let finalWeight = historicalWeight + (tSet.intensityValue ?? 0)
                return "\(Int(finalWeight))\(unit) x \(targetValue)"
            }
            return "LW +\(tSet.intensityValue?.formatted() ?? "0") x \(targetValue)"
            
        case .lastSessionPlus:
            if let historicalWeight = findHistoricalWeight(exerciseID: exercise.id, type: .lastSession, context: context) {
                let finalWeight = historicalWeight + (tSet.intensityValue ?? 0)
                return "\(Int(finalWeight))\(unit) x \(targetValue)"
            }
            return "LS +\(tSet.intensityValue?.formatted() ?? "0") x \(targetValue)"
            
        case .none:
            return targetValue
        }
        
        return targetValue
    }
    
    enum HistoryType {
        case lastWeek
        case lastSession
    }
    
    @MainActor
    private static func findHistoricalWeight(exerciseID: UUID, type: HistoryType, context: ModelContext) -> Double? {
        // Query for past WorkoutSets of this exercise
        let descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> { $0.workoutExercise?.exercise?.id == exerciseID && $0.isCompleted },
            sortBy: [SortDescriptor(\.workoutExercise?.workout?.startTime, order: .reverse)]
        )
        
        guard let history = try? context.fetch(descriptor) else { return nil }
        
        switch type {
        case .lastSession:
            // Just the most recent one
            return history.first?.weight
        case .lastWeek:
            // In a real app, we'd filter for workouts ~7 days ago.
            // For MVP: we'll look for the first one that is at least 5 days old but not more than 10.
            let now = Date()
            return history.first(where: { set in
                if let date = set.workoutExercise?.workout?.startTime {
                    let diff = now.timeIntervalSince(date)
                    return diff > (5 * 24 * 3600) && diff < (10 * 24 * 3600)
                }
                return false
            })?.weight ?? history.first?.weight // Fallback to last session if week match fails
        }
    }
}
