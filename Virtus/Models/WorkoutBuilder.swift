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
            // Value is stored as 80.0 for 80%, so just display it
            let val = Int(tSet.intensityValue ?? 0)
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
        
        let unit = profile.preferredUnitRaw
        
        // 1. Determine 1RM
        // Priority: Manual Entry -> Historical Best Estimate -> Default (Bar)
        var oneRepMax = 0.0
        
        if let entry = profile.oneRepMax(for: exercise.id) {
            // Manual Entry
            oneRepMax = convert(weight: entry.value, from: entry.unit, to: unit)
        } else if let estimated = estimateBestOneRepMax(exerciseID: exercise.id, context: context) {
            // Auto-Estimate from History
            oneRepMax = convert(weight: estimated.value, from: estimated.unit, to: unit)
        } else {
            // Cold Start: Default to empty bar (45 lbs / 20 kg)
            // Or assume 100 for MVP simplicity if no history exists
            let barLbs = 45.0
            oneRepMax = convert(weight: barLbs, from: "lbs", to: unit)
        }
        
        let targetValue = tSet.targetValue
        
        switch tSet.intensityType {
        case .percent1RM:
            if let pct = tSet.intensityValue {
                let weight = oneRepMax * (pct / 100.0)
                return "\(Int(weight))\(unit) x \(targetValue)"
            }
        case .rpe:
            if let reps = Int(targetValue) {
                let weightAtRPE10 = weightForReps(oneRepMax: oneRepMax, reps: reps)
                let rpeOffset = (10.0 - (tSet.intensityValue ?? 10.0)) * 0.02
                let finalWeight = weightAtRPE10 * (1.0 - rpeOffset)
                return "\(Int(finalWeight))\(unit) @ \(tSet.intensityValue?.formatted() ?? "10")"
            }
            return "Est: \(targetValue) @ \(tSet.intensityValue?.formatted() ?? "-")"
            
        case .lastWeekPlus:
            if let history = findHistoricalWeight(exerciseID: exercise.id, type: .lastWeek, context: context) {
                let convertedWeight = convert(weight: history.weight, from: history.unit, to: unit)
                let finalWeight = convertedWeight + (tSet.intensityValue ?? 0)
                return "\(Int(finalWeight))\(unit) x \(targetValue)"
            }
            return "LW +\(tSet.intensityValue?.formatted() ?? "0") x \(targetValue)"
            
        case .lastSessionPlus:
            if let history = findHistoricalWeight(exerciseID: exercise.id, type: .lastSession, context: context) {
                let convertedWeight = convert(weight: history.weight, from: history.unit, to: unit)
                let finalWeight = convertedWeight + (tSet.intensityValue ?? 0)
                return "\(Int(finalWeight))\(unit) x \(targetValue)"
            }
            return "LS +\(tSet.intensityValue?.formatted() ?? "0") x \(targetValue)"
            
        case .none:
            return targetValue
        }
        
        return targetValue
    }
    
    private static func convert(weight: Double, from source: String, to target: String) -> Double {
        if source == target { return weight }
        if source == "lbs" && target == "kg" { return weight * 0.453592 }
        if source == "kg" && target == "lbs" { return weight * 2.20462 }
        return weight
    }
    
    enum HistoryType {
        case lastWeek
        case lastSession
    }
    
    @MainActor
    private static func findHistoricalWeight(exerciseID: UUID, type: HistoryType, context: ModelContext) -> (weight: Double, unit: String)? {
        let descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> { $0.workoutExercise?.exercise?.id == exerciseID && $0.isCompleted },
            sortBy: [SortDescriptor(\.workoutExercise?.workout?.startTime, order: .reverse)]
        )
        
        guard let history = try? context.fetch(descriptor) else { return nil }
        
        // Helper to extract tuple
        func extract(_ set: WorkoutSet) -> (Double, String)? {
            guard let w = set.weight else { return nil }
            return (w, set.unitRaw)
        }
        
        switch type {
        case .lastSession:
            if let match = history.first, let val = extract(match) { return val }
            return nil
        case .lastWeek:
            let now = Date()
            let match = history.first(where: { set in
                if let date = set.workoutExercise?.workout?.startTime {
                    let diff = now.timeIntervalSince(date)
                    return diff > (5 * 24 * 3600) && diff < (10 * 24 * 3600)
                }
                return false
            }) ?? history.first
            
            if let m = match, let val = extract(m) { return val }
            return nil
        }
    }
    
    @MainActor
    private static func estimateBestOneRepMax(exerciseID: UUID, context: ModelContext) -> (value: Double, unit: String)? {
        let descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> { $0.workoutExercise?.exercise?.id == exerciseID && $0.isCompleted },
            sortBy: [SortDescriptor(\.workoutExercise?.workout?.startTime, order: .reverse)]
        )
        
        guard let history = try? context.fetch(descriptor) else { return nil }
        
        // Find the set with the highest estimated 1RM
        var maxEst: Double = 0.0
        
        for set in history {
            guard let weight = set.weight, let reps = set.reps, reps > 0 else { continue }
            
            // Normalize to lbs for comparison to find true max
            let weightInLbs = (set.unitRaw == "kg") ? weight * 2.20462 : weight
            let est1RM_Lbs = estimateOneRepMax(weight: weightInLbs, reps: reps)
            
            if est1RM_Lbs > maxEst {
                maxEst = est1RM_Lbs
            }
        }
        
        return maxEst > 0 ? (maxEst, "lbs") : nil
    }
}