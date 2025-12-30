//
//  HistoryView.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    // Fetch only completed workouts, sorted by date (newest first)
    @Query(filter: #Predicate<Workout> { $0.statusRaw == "completed" }, sort: \Workout.startTime, order: .reverse)
    private var workouts: [Workout]
    
    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath", description: Text("Complete your first workout to see it here."))
                } else {
                    ForEach(workouts) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            HistoryRow(workout: workout)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                duplicateWorkout(workout)
                            } label: {
                                Label("Repeat", systemImage: "repeat")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteWorkout)
                }
            }
            .navigationTitle("History")
            .fullScreenCover(item: $workoutToPresent) { workout in
                WorkoutSessionView(workout: workout)
            }
        }
    }
    
    @State private var workoutToPresent: Workout?
    
    private func duplicateWorkout(_ original: Workout) {
        let newWorkout = Workout(startTime: Date(), status: .inProgress)
        newWorkout.notes = "Repeat of \(original.startTime.formatted(date: .abbreviated, time: .omitted))"
        modelContext.insert(newWorkout)
        
        let originalExercises = original.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })
        for (idx, oldEx) in originalExercises.enumerated() {
            let newEx = WorkoutExercise(orderIndex: idx)
            newEx.exercise = oldEx.exercise
            newEx.workout = newWorkout
            modelContext.insert(newEx)
            
            let originalSets = oldEx.sets.sorted(by: { $0.orderIndex < $1.orderIndex })
            for (setIdx, oldSet) in originalSets.enumerated() {
                let newSet = WorkoutSet(orderIndex: setIdx)
                newSet.workoutExercise = newEx
                
                // --- DUPLICATION LOGIC ---
                // "Previous" Actuals become the new "computedTarget"
                if let w = oldSet.weight, let r = oldSet.reps {
                    let u = original.exercises.first?.sets.first?.unitRaw ?? "lbs"
                    newSet.computedTarget = "\(Int(w))\(u) x \(r)"
                    // If old set had RPE, include that too
                    if let rpe = oldSet.rpe {
                        newSet.computedTarget? += " @ \(rpe.formatted())"
                    }
                }
                
                // Pre-fill the inputs with the previous values for convenience? 
                // Spec says: "The details of how this works aren’t clear... solve this later."
                // I'll leave them empty but showing the "Previous" label.
                
                newSet.unit = oldSet.unit
                
                context.insert(newSet)
            }
        }
        
        workoutToPresent = newWorkout
    }
    
    private var context: ModelContext { modelContext }
    
    private func deleteWorkout(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

struct HistoryRow: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.startTime.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            
            Text(summaryText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
    
    // Generate a quick summary string like "Squat, Bench Press, Deadlift"
    var summaryText: String {
        let exerciseNames = workout.exercises
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .compactMap { $0.exercise?.name }
        
        if exerciseNames.isEmpty {
            return "Empty Workout"
        } else {
            return exerciseNames.joined(separator: ", ")
        }
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    @Query private var profiles: [UserProfile]
    
    private var preferredUnit: String {
        profiles.first?.preferredUnitRaw ?? "lbs"
    }
    
    var body: some View {
        List {
            Section(header: Text("Summary")) {
                LabeledContent("Date", value: workout.startTime.formatted(date: .long, time: .shortened))
                if let end = workout.endTime {
                    LabeledContent("Duration", value: durationString(start: workout.startTime, end: end))
                }
            }
            
            ForEach(workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { workoutExercise in
                Section(header: Text(workoutExercise.exercise?.name ?? "Unknown Exercise")) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow {
                            Text("Set").bold()
                            Text("Instr.").bold()
                            Text("Target").bold()
                            Text("Weight").bold()
                            Text("Reps").bold()
                            Text("RPE").bold()
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        ForEach(workoutExercise.sets.sorted(by: { $0.orderIndex < $1.orderIndex })) { set in
                            GridRow {
                                Text("\(set.orderIndex + 1)")
                                Text(set.displayIntensity ?? "-")
                                Text(set.computedTarget ?? "-")
                                    .foregroundColor(.blue)
                                Text(formattedWeight(set.weight, from: set.unitRaw))
                                Text(set.reps?.formatted() ?? "-")
                                Text(set.rpe?.formatted() ?? "-")
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Workout Details")
    }
    
    private func formattedWeight(_ weight: Double?, from unit: String) -> String {
        guard let w = weight else { return "-" }
        let converted = convert(weight: w, from: unit, to: preferredUnit)
        return "\(Int(converted)) \(preferredUnit)"
    }
    
    private func convert(weight: Double, from source: String, to target: String) -> Double {
        if source == target { return weight }
        if source == "lbs" && target == "kg" { return weight * 0.453592 }
        if source == "kg" && target == "lbs" { return weight * 2.20462 }
        return weight
    }
    
    private func durationString(start: Date, end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}
