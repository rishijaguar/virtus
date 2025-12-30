//
//  ProgramViews.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct ProgramListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Program.createdDate, order: .reverse) private var programs: [Program]
    @State private var showingCreateSheet = false
    
    var body: some View {
        List {
            if programs.isEmpty {
                ContentUnavailableView("No Programs", systemImage: "doc.text", description: Text("Create a program manually or ask the Coach to build one."))
            } else {
                ForEach(programs) { program in
                    NavigationLink(destination: ProgramDetailView(program: program)) {
                        VStack(alignment: .leading) {
                            Text(program.name)
                                .font(.headline)
                            Text("\(program.durationWeeks) Weeks • \(program.programDescription)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteProgram)
            }
        }
        .navigationTitle("Programs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateSheet = true }) {
                    Label("New Program", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProgramView()
        }
    }
    
    private func deleteProgram(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(programs[index])
        }
    }
}

struct ProgramDetailView: View {
    @Bindable var program: Program
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section(header: Text("Overview")) {
                Text(program.programDescription)
                LabeledContent("Duration", value: "\(program.durationWeeks) Weeks")
                LabeledContent("Frequency", value: "\(program.sessionsPerWeek) Sessions/Week")
            }
            
            ForEach(1...program.durationWeeks, id: \.self) { week in
                ProgramWeekSection(week: week, days: program.days)
            }
        }
        .navigationTitle(program.name)
        .toolbar {
            Button("Edit") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            ProgramEditSheet(program: program)
        }
    }
}

struct ProgramWeekSection: View {
    let week: Int
    let days: [ProgramDay]
    
    var daysInWeek: [ProgramDay] {
        days.filter { $0.weekNumber == week }.sorted { $0.dayNumber < $1.dayNumber }
    }
    
    var body: some View {
        Section(header: Text("Week \(week)")) {
            if daysInWeek.isEmpty {
                Text("No workout days scheduled.")
                    .italic()
                    .foregroundColor(.secondary)
            } else {
                ForEach(daysInWeek) { day in
                    NavigationLink(destination: ProgramDayDetailView(day: day)) {
                        HStack {
                            Text("Day \(day.dayNumber)")
                                .bold()
                                .frame(width: 60, alignment: .leading)
                            Text(day.title)
                        }
                    }
                }
            }
        }
    }
}

struct ProgramDayDetailView: View {
    @Bindable var day: ProgramDay
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingExercisePicker = false
    @State private var workoutToPresent: Workout?
    
    var body: some View {
        List {
            if let notes = day.instructions, !notes.isEmpty {
                Section(header: Text("Instructions")) {
                    Text(notes)
                }
            }
            
            Section(header: Text("Exercises")) {
                if day.plannedExercises.isEmpty {
                    Text("No exercises planned.")
                        .italic()
                        .foregroundColor(.secondary)
                } else {
                    let exercises = day.plannedExercises.sorted { $0.orderIndex < $1.orderIndex }
                    ForEach(exercises) { planned in
                        PlannedExerciseRow(planned: planned)
                    }
                    .onDelete(perform: deletePlannedExercise)
                }
                
                Button("Add Exercise") {
                    showingExercisePicker = true
                }
            }
        }
        .navigationTitle(day.title)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: startWorkoutFromDay) {
                    Text("Start This Workout")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(day.plannedExercises.isEmpty)
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { selectedExercise in
                addExerciseToDay(selectedExercise)
            }
        }
        .fullScreenCover(item: $workoutToPresent) { workout in
            WorkoutSessionView(workout: workout)
        }
    }
    
    private func addExerciseToDay(_ exercise: Exercise) {
        let count = day.plannedExercises.count
        let newPlanned = PlannedExercise(orderIndex: count)
        newPlanned.exercise = exercise
        newPlanned.programDay = day
        
        // Default to 3 sets of 10
        for i in 0..<3 {
            let set = PlannedSet(orderIndex: i, reps: "10")
            set.plannedExercise = newPlanned
            newPlanned.sets.append(set)
        }
        
        day.plannedExercises.append(newPlanned)
    }
    
    private func deletePlannedExercise(at offsets: IndexSet) {
        let sorted = day.plannedExercises.sorted { $0.orderIndex < $1.orderIndex }
        for index in offsets {
            let toDelete = sorted[index]
            modelContext.delete(toDelete)
        }
    }
    
    private func startWorkoutFromDay() {
        let newWorkout = Workout(startTime: Date(), status: .inProgress)
        newWorkout.programDayID = day.id
        newWorkout.notes = day.title
        
        let plannedSorted = day.plannedExercises.sorted { $0.orderIndex < $1.orderIndex }
        
        for (index, planned) in plannedSorted.enumerated() {
            let workoutExercise = WorkoutExercise(orderIndex: index)
            workoutExercise.exercise = planned.exercise
            workoutExercise.workout = newWorkout
            
            // Create sets from PlannedSets
            let plannedSetsSorted = planned.sets.sorted { $0.orderIndex < $1.orderIndex }
            
            for (setIndex, plannedSet) in plannedSetsSorted.enumerated() {
                let set = WorkoutSet(orderIndex: setIndex)
                set.workoutExercise = workoutExercise
                
                // Set the goals
                set.targetReps = plannedSet.reps
                set.targetRPE = plannedSet.rpe
                
                // Pre-fill the actual reps field if it's a simple number (for convenience)
                if let repsInt = Int(plannedSet.reps) {
                    set.reps = repsInt
                }
                
                workoutExercise.sets.append(set)
            }
            
            newWorkout.exercises.append(workoutExercise)
        }
        
        modelContext.insert(newWorkout)
        workoutToPresent = newWorkout
    }
}

// Subview for editing the planned sets of a specific exercise
struct PlannedExerciseRow: View {
    @Bindable var planned: PlannedExercise
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(planned.exercise?.name ?? "Unknown Exercise")
                .font(.headline)
            
            // Header
            HStack {
                Text("Set").font(.caption).frame(width: 30)
                Text("Reps").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                Text("RPE").font(.caption).frame(width: 40)
            }
            .foregroundColor(.secondary)
            
            ForEach(planned.sets.sorted { $0.orderIndex < $1.orderIndex }) { set in
                PlannedSetRow(set: set)
            }
            .onDelete(perform: deleteSet)
            
            Button("Add Set") {
                addSet()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    private func addSet() {
        let count = planned.sets.count
        let newSet = PlannedSet(orderIndex: count, reps: "10")
        newSet.plannedExercise = planned
        planned.sets.append(newSet)
    }
    
    private func deleteSet(at offsets: IndexSet) {
        let sorted = planned.sets.sorted { $0.orderIndex < $1.orderIndex }
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct PlannedSetRow: View {
    @Bindable var set: PlannedSet
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Index
            Text("\(set.orderIndex + 1)")
                .frame(width: 24)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // --- TARGET COLUMN ---
            HStack(spacing: 4) {
                Menu {
                    Picker("Type", selection: $set.targetType) {
                        Text("Reps").tag(PlannedSetTargetType.reps)
                        Text("Range").tag(PlannedSetTargetType.range)
                        Text("Time").tag(PlannedSetTargetType.time)
                        Text("AMRAP").tag(PlannedSetTargetType.amrap)
                    }
                    .onChange(of: set.targetType) { _, newValue in
                        // Reset default values when type changes
                        if newValue == .amrap { set.reps = "AMRAP" }
                        else if newValue == .time { set.reps = "30s" }
                        else if newValue == .reps { set.reps = "10" }
                        else if newValue == .range { set.reps = "8-12" }
                    }
                } label: {
                    Image(systemName: targetIcon)
                        .font(.caption)
                        .frame(width: 20)
                }
                .buttonStyle(.borderless)
                
                if set.targetType == .amrap {
                    Text("AMRAP")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                } else {
                    TextField("Val", text: $set.reps)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                }
            }
            .frame(maxWidth: .infinity)
            
            // --- INTENSITY COLUMN ---
            HStack(spacing: 4) {
                Menu {
                    Picker("Intensity", selection: $set.intensityType) {
                        Text("RPE").tag(PlannedSetIntensityType.rpe)
                        Text("% 1RM").tag(PlannedSetIntensityType.percent1RM)
                        Text("None").tag(PlannedSetIntensityType.none)
                    }
                } label: {
                    Text(intensityLabel)
                        .font(.caption2)
                        .bold()
                        .frame(width: 28)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                if set.intensityType == .rpe {
                    TextField("-", value: $set.rpe, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .frame(width: 45)
                } else if set.intensityType == .percent1RM {
                    TextField("-", value: $set.weightPercent, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .frame(width: 45)
                } else {
                    Text("-")
                        .frame(width: 45)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    var targetIcon: String {
        switch set.targetType {
        case .reps: return "number"
        case .range: return "arrow.left.and.right"
        case .time: return "stopwatch"
        case .amrap: return "infinity"
        }
    }
    
    var intensityLabel: String {
        switch set.intensityType {
        case .rpe: return "@"
        case .percent1RM: return "%"
        case .none: return "-"
        }
    }
}

struct ProgramEditSheet: View {
    @Bindable var program: Program
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Local state for editing
    @State private var name: String
    @State private var description: String
    @State private var weeks: Int
    @State private var sessions: Int
    
    init(program: Program) {
        self.program = program
        _name = State(initialValue: program.name)
        _description = State(initialValue: program.programDescription)
        _weeks = State(initialValue: program.durationWeeks)
        _sessions = State(initialValue: program.sessionsPerWeek)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Program Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Structure")) {
                    Stepper("Duration: \(weeks) Weeks", value: $weeks, in: 1...24)
                    Stepper("Frequency: \(sessions) / Week", value: $sessions, in: 1...7)
                }
                
                Section(footer: Text("Changing duration or frequency will add new days if increased. Existing days are preserved.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        program.name = name
        program.programDescription = description
        
        // Handle Structural Changes
        program.durationWeeks = weeks
        program.sessionsPerWeek = sessions
        
        // If we increased structure, ensure days exist
        // We iterate through the NEW structure
        for w in 1...weeks {
            for s in 1...sessions {
                // Check if this day already exists
                let exists = program.days.contains { $0.weekNumber == w && $0.dayNumber == s }
                if !exists {
                    // Create it
                    let newDay = ProgramDay(weekNumber: w, dayNumber: s, title: "Day \(s)")
                    newDay.program = program
                    program.days.append(newDay)
                }
            }
        }
        
        // Remove days that are now out of bounds
        // We need to iterate over a copy or use indices to safely remove while iterating
        let daysToRemove = program.days.filter { $0.weekNumber > weeks || $0.dayNumber > sessions }
        
        for day in daysToRemove {
            modelContext.delete(day)
            // Also remove from the array relationship if SwiftData doesn't auto-update it immediately in memory
            if let index = program.days.firstIndex(of: day) {
                program.days.remove(at: index)
            }
        }
        
        dismiss()
    }
}

// Simple Creator for V1 testing
struct CreateProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var weeks = 4
    @State private var sessions = 3
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Program Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Structure")) {
                    Stepper("Duration: \(weeks) Weeks", value: $weeks, in: 1...24)
                    Stepper("Frequency: \(sessions) / Week", value: $sessions, in: 1...7)
                }
            }
            .navigationTitle("New Program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProgram()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createProgram() {
        let newProgram = Program(name: name, programDescription: description, durationWeeks: weeks, sessionsPerWeek: sessions, isActive: true)
        
        for w in 1...weeks {
            for d in 1...sessions {
                let day = ProgramDay(weekNumber: w, dayNumber: d, title: "Day \(d)")
                day.program = newProgram
                newProgram.days.append(day)
            }
        }
        
        modelContext.insert(newProgram)
        dismiss()
    }
}