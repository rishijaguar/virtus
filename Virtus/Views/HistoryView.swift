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
                    }
                    .onDelete(perform: deleteWorkout)
                }
            }
            .navigationTitle("History")
        }
    }
    
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
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        GridRow {
                            Text("Set").bold()
                            Text("Weight").bold()
                            Text("Reps").bold()
                            Text("RPE").bold()
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        ForEach(workoutExercise.sets.sorted(by: { $0.orderIndex < $1.orderIndex })) { set in
                            GridRow {
                                Text("\(set.orderIndex + 1)")
                                Text(set.weight?.formatted() ?? "-")
                                Text(set.reps?.formatted() ?? "-")
                                Text(set.rpe?.formatted() ?? "-")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Workout Details")
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
